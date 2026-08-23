import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/document_package_service.dart';
import 'package:moyue_application/services/storage/storage_backend.dart';
import 'package:moyue_application/services/storage/storage_backend_base.dart';

class MoyueStorageService extends ChangeNotifier {
  MoyueStorageService._() : _backend = createStorageBackend();

  static final instance = MoyueStorageService._();
  final MoyueStorageBackend _backend;
  final DocumentPackageService _packages = DocumentPackageService();

  Future<List<ReadingDocument>> loadDocuments() async {
    final indexed = await _packages.loadDocuments();
    final legacy = await _backend.loadDocuments();
    return [...indexed, ...legacy]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<LibraryFolder>> loadFolders() => _packages.loadFolders();

  Future<void> createFolder(String name) async {
    await _packages.createFolder(name);
    notifyListeners();
  }

  Future<void> createSubfolder({
    required LibraryFolder rootFolder,
    required String parentPath,
    required String name,
  }) async {
    await _packages.createSubfolder(
      rootFolder: rootFolder,
      parentPath: parentPath,
      name: name,
    );
    notifyListeners();
  }

  Future<void> deleteFolder(LibraryFolder folder) async {
    await _packages.deleteFolderById(folder.id);
    notifyListeners();
  }

  Future<void> deleteSubfolder({
    required LibraryFolder rootFolder,
    required String logicalPath,
  }) async {
    await _packages.deleteSubfolder(
      rootFolder: rootFolder,
      logicalPath: logicalPath,
    );
    notifyListeners();
  }

  Future<void> renameFolder(LibraryFolder folder, String name) async {
    await _packages.renameFolder(folder.id, name);
    notifyListeners();
  }

  Future<ReadingDocument> importIntoFolder({
    required LibraryFolder folder,
    required String fileName,
    required Uint8List bytes,
    String logicalDirectory = '',
  }) async {
    final document = await _packages.importIntoFolder(
      folder: folder,
      fileName: fileName,
      bytes: bytes,
      logicalDirectory: logicalDirectory,
    );
    notifyListeners();
    return document;
  }

  Future<ReadingDocument> createMarkdownInFolder({
    required LibraryFolder folder,
    required String title,
    String logicalDirectory = '',
  }) {
    final trimmed = title.trim();
    final fileName = trimmed.toLowerCase().endsWith('.md')
        ? trimmed
        : '$trimmed.md';
    return importIntoFolder(
      folder: folder,
      fileName: fileName,
      bytes: Uint8List(0),
      logicalDirectory: logicalDirectory,
    );
  }

  Future<ReadingDocument> saveDocument({
    required String title,
    required String content,
    required DocumentKind kind,
    ReadingDocument? existingDocument,
  }) async {
    final result = kind == DocumentKind.markdown
        ? await _packages.saveMarkdown(
            title: title,
            content: content,
            existing: existingDocument,
          )
        : await _packages.importFile(
            '$title.html',
            Uint8List.fromList(utf8.encode(content)),
          );
    if (existingDocument != null && existingDocument.folderId == null) {
      await _backend.deleteDocument(existingDocument);
    }
    notifyListeners();
    return result;
  }

  Future<ReadingDocument> importDocumentPackage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final document = await _packages.importFile(fileName, bytes);
    notifyListeners();
    return document;
  }

  Future<List<ReadingDocument>> importDocumentPackageIntoFolder({
    required LibraryFolder folder,
    required String fileName,
    required Uint8List bytes,
    String logicalDirectory = '',
  }) async {
    final documents = await _packages.importPackageIntoFolder(
      folder: folder,
      fileName: fileName,
      bytes: bytes,
      logicalDirectory: logicalDirectory,
    );
    notifyListeners();
    return documents;
  }

  Future<MoyueExport> exportMoyue(ReadingDocument document) =>
      _packages.exportMoyue(document);

  Future<MoyueExport> exportFolder(LibraryFolder folder) =>
      _packages.exportMoyueFolder(folder.id);

  Future<ReadingDocument> moveDocument({
    required ReadingDocument document,
    required LibraryFolder target,
  }) async {
    final moved = await _packages.moveDocument(
      document: document,
      target: target,
    );
    notifyListeners();
    return moved;
  }

  /// 批量移动期间只在全部文件完成后刷新一次页面，避免每个文件都触发一次
  /// 文件夹重载并与拖拽结束动画争用 widget 生命周期。
  Future<List<ReadingDocument>> moveDocuments({
    required List<ReadingDocument> documents,
    required LibraryFolder target,
    String? targetDirectory,
  }) async {
    final moved = <ReadingDocument>[];
    for (final document in documents) {
      final visibleName = document.logicalPath == null
          ? '${document.title}.${document.kind.extension}'
          : document.logicalPath!.split('/').last;
      final targetLogicalPath = targetDirectory == null
          ? null
          : targetDirectory.isEmpty
          ? visibleName
          : '$targetDirectory/$visibleName';
      moved.add(
        await _packages.moveDocument(
          document: document,
          target: target,
          targetLogicalPath: targetLogicalPath,
        ),
      );
    }
    if (moved.isNotEmpty) notifyListeners();
    return moved;
  }

  Future<String> moveSubfolder({
    required LibraryFolder sourceRoot,
    required String logicalPath,
    required LibraryFolder targetRoot,
    String targetParentPath = '',
  }) async {
    final movedPath = await _packages.moveSubfolder(
      sourceRoot: sourceRoot,
      logicalPath: logicalPath,
      targetRoot: targetRoot,
      targetParentPath: targetParentPath,
    );
    notifyListeners();
    return movedPath;
  }

  /// 文件夹页的一次移动手势只触发一次刷新，避免目录和文档分批移动时
  /// 页面监听器在中间态反复重建。
  Future<void> moveFolderItems({
    required LibraryFolder sourceRoot,
    required List<ReadingDocument> documents,
    required List<String> subfolderPaths,
    required LibraryFolder? targetRoot,
    String targetParentPath = '',
  }) async {
    if (targetRoot == null && subfolderPaths.isNotEmpty) {
      throw const FormatException('子文件夹不能拆成首页单文档');
    }
    final topLevelPaths = subfolderPaths
        .where((path) {
          return !subfolderPaths.any(
            (other) =>
                other != path && (path == other || path.startsWith('$other/')),
          );
        })
        .toList(growable: false);
    for (final path in topLevelPaths) {
      await _packages.moveSubfolder(
        sourceRoot: sourceRoot,
        logicalPath: path,
        targetRoot: targetRoot!,
        targetParentPath: targetParentPath,
      );
    }
    final movedDirectorySet = topLevelPaths.toSet();
    final standaloneDocuments = documents.where((document) {
      final logicalPath = document.logicalPath;
      if (logicalPath == null) return true;
      return !movedDirectorySet.any(
        (directory) => logicalPath.startsWith('$directory/'),
      );
    });
    if (targetRoot == null) {
      for (final document in standaloneDocuments) {
        await _packages.moveDocumentToLibrary(document);
      }
    } else {
      for (final document in standaloneDocuments) {
        final visibleName = document.logicalPath == null
            ? '${document.title}.${document.kind.extension}'
            : document.logicalPath!.split('/').last;
        final targetLogicalPath = targetParentPath.isEmpty
            ? visibleName
            : '$targetParentPath/$visibleName';
        await _packages.moveDocument(
          document: document,
          target: targetRoot,
          targetLogicalPath: targetLogicalPath,
        );
      }
    }
    if (topLevelPaths.isNotEmpty || standaloneDocuments.isNotEmpty) {
      notifyListeners();
    }
  }

  /// 把文件夹内文档拆成首页上的独立文档。
  Future<List<ReadingDocument>> moveDocumentsToLibrary(
    List<ReadingDocument> documents,
  ) async {
    final moved = <ReadingDocument>[];
    for (final document in documents) {
      moved.add(await _packages.moveDocumentToLibrary(document));
    }
    if (moved.isNotEmpty) notifyListeners();
    return moved;
  }

  Future<Uint8List?> readLinkedResource(
    ReadingDocument document,
    String link,
  ) => _packages.readLinkedResource(document, link);

  /// 把编辑器选中的图片写入文档目录的 images/ 子目录，
  /// 返回 Markdown 相对链接；文档不支持时返回 null。
  Future<String?> saveDocumentImage({
    required ReadingDocument document,
    required String fileName,
    required Uint8List bytes,
  }) {
    return _packages.saveImageResource(
      document: document,
      fileName: fileName,
      bytes: bytes,
    );
  }

  /// 清理文档 images/ 目录下未被同目录任何文档引用的图片。
  /// [pendingContent] 为编辑器未落盘的正文快照，参与引用判定。
  Future<int> cleanupUnreferencedImages(
    ReadingDocument document, {
    String? pendingContent,
  }) {
    return _packages.cleanupUnreferencedImages(
      document,
      pendingContent: pendingContent,
    );
  }

  Future<void> deleteDocument(ReadingDocument document) async {
    if (document.folderId == null) {
      await _backend.deleteDocument(document);
    } else {
      await _packages.deleteDocument(document);
    }
    notifyListeners();
  }

  Future<List<FeedSource>> loadFeedSources() => _packages.loadFeedSources();
  Future<String?> readFeedXml(FeedSource source) => _packages.readFeed(source);

  Future<void> saveFeedSources(List<FeedSource> sources) async {
    for (final source in sources) {
      final existing = await _packages.readFeed(source) ?? '';
      await _packages.saveFeed(source, existing);
    }
    notifyListeners();
  }

  Future<FeedSource> saveFeedXml(FeedSource source, String xml) async {
    return _packages.saveFeed(source, xml);
  }

  Future<void> deleteFeed(FeedSource source) async {
    await _packages.deleteFeed(source);
    notifyListeners();
  }
}

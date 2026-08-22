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

  Future<void> deleteFolder(LibraryFolder folder) async {
    await _packages.deleteFolderById(folder.id);
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
  }) async {
    final document = await _packages.importIntoFolder(
      folder: folder,
      fileName: fileName,
      bytes: bytes,
    );
    notifyListeners();
    return document;
  }

  Future<ReadingDocument> createMarkdownInFolder({
    required LibraryFolder folder,
    required String title,
  }) {
    final trimmed = title.trim();
    final fileName = trimmed.toLowerCase().endsWith('.md')
        ? trimmed
        : '$trimmed.md';
    return importIntoFolder(
      folder: folder,
      fileName: fileName,
      bytes: Uint8List(0),
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

  Future<MoyueExport> exportMoyue(ReadingDocument document) =>
      _packages.exportMoyue(document);

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

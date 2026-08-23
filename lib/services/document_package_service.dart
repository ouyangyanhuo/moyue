import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/database/index_models.dart';
import 'package:moyue_application/services/database/moyue_index_database.dart';
import 'package:moyue_application/services/storage/package_file_store.dart';
import 'package:moyue_application/services/storage/package_file_store_base.dart';
import 'package:moyue_application/services/text_decoder.dart';
import 'package:path/path.dart' as p;

class MoyueExport {
  const MoyueExport({required this.fileName, required this.bytes});
  final String fileName;
  final Uint8List bytes;
}

class DocumentPackageService {
  /// [store] 与 [documentsLoader] 供测试注入内存实现，
  /// 生产环境保持默认的平台存储与索引查询。
  DocumentPackageService({
    PackageFileStore? store,
    Future<List<ReadingDocument>> Function()? documentsLoader,
  }) : _files = store ?? createPackageFileStore(),
       // ignore: prefer_initializing_formals
       _documentsLoader = documentsLoader;

  final PackageFileStore _files;
  final Future<List<ReadingDocument>> Function()? _documentsLoader;
  MoyueIndexDatabase? _index;

  /// 编辑器插入图片允许的扩展名。
  static const Set<String> imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
  };

  /// 编辑器插入图片统一存放的子目录（相对文档所在目录）。
  static const String imageDirName = 'images';

  Future<MoyueIndexDatabase> get index async =>
      _index ??= MoyueIndexDatabase(await _files.databasePath());

  Future<void> close() async {
    await _index?.close();
    _index = null;
  }

  /// 把编辑器选中的图片写入文档所在目录的 images/ 子目录，
  /// 返回可直接用于 Markdown 的相对链接（如 `images/xxx.png`）。
  /// 文档缺少目录信息（folderId / relativePath）时返回 null。
  Future<String?> saveImageResource({
    required ReadingDocument document,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final documentPath = document.relativePath;
    final folderId = document.folderId;
    if (documentPath == null || folderId == null) return null;
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'png';
    if (!imageExtensions.contains(extension)) return null;
    final baseName = fileName
        .split('.')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final name = baseName.isEmpty
        ? 'img_$stamp.$extension'
        : 'img_${stamp}_$baseName.$extension';
    final documentDir = p.posix.dirname(documentPath);
    final resourcePath = p.posix.join(documentDir, imageDirName, name);
    await _files.writeFiles({resourcePath: bytes});
    try {
      await (await index).upsertResource(
        ResourceRecord(
          id: '$folderId-res-${sha256.convert(utf8.encode(resourcePath)).toString().substring(0, 16)}',
          folderId: folderId,
          documentId: document.id,
          name: name,
          mimeType: _mimeType(name),
          relativePath: resourcePath,
          contentHash: sha256.convert(bytes).toString(),
          sizeBytes: bytes.length,
        ),
      );
    } on Object {
      // 资源索引可由导出时的正文引用重新构建；索引暂不可用不应让编辑器
      // 已成功写入的图片丢失。
    }
    return '$imageDirName/$name';
  }

  /// 清理文档所在目录 images/ 下未被引用的图片。
  ///
  /// 「被引用」以同一目录内所有文档（Markdown/HTML）的图片链接为准，
  /// 避免误删同文件夹其他文档正在使用的资源。[pendingContent] 是编辑器
  /// 中尚未落盘的正文快照：退出编辑器时若未保存，磁盘正文还不含新插入
  /// 的链接，必须把它并入引用判定，否则刚插入的图片会被误删。
  /// 返回删除的文件数。
  Future<int> cleanupUnreferencedImages(
    ReadingDocument document, {
    String? pendingContent,
  }) async {
    final documentPath = document.relativePath;
    if (documentPath == null || document.folderId == null) return 0;
    final documentDir = p.posix.dirname(documentPath);
    final imagesDir = p.posix.join(documentDir, imageDirName);

    final referenced = <String>{};
    if (pendingContent != null) {
      referenced.addAll(extractImageReferences(pendingContent));
    }
    final siblings = await (_documentsLoader?.call() ?? loadDocuments());
    for (final sibling in siblings) {
      final siblingPath = sibling.relativePath;
      if (siblingPath == null) continue;
      if (p.posix.dirname(siblingPath) != documentDir) continue;
      referenced.addAll(extractImageReferences(sibling.content));
    }

    final stored = await _files.listFiles(imagesDir);
    var deleted = 0;
    for (final path in stored) {
      final link = '$imageDirName/${p.posix.basename(path)}';
      if (referenced.contains(link)) continue;
      await _files.deleteFile(path);
      deleted++;
    }
    return deleted;
  }

  /// 从 Markdown / HTML 文本中提取本地图片引用，
  /// 归一化为相对文档目录的链接（忽略网络与 data: URI）。
  @visibleForTesting
  static Set<String> extractImageReferences(String content) {
    final references = <String>{};
    void addMatch(String raw) {
      var link = raw.trim();
      if (link.isEmpty || link.contains('://')) return;
      final uri = Uri.tryParse(link);
      if (uri == null || uri.hasScheme) return;
      link = uri.path;
      if (link.startsWith('./')) link = link.substring(2);
      if (link.isEmpty || link.startsWith('/')) return;
      references.add(Uri.decodeComponent(link));
    }

    final markdown = RegExp(r'!\[[^\]]*\]\(\s*<?([^)<>\s]+)>?\s*');
    for (final match in markdown.allMatches(content)) {
      addMatch(match.group(1)!);
    }
    final html = RegExp(
      r"""<img[^>]+src\s*=\s*["']([^"']+)["']""",
      caseSensitive: false,
    );
    for (final match in html.allMatches(content)) {
      addMatch(match.group(1)!);
    }
    return references;
  }

  Future<List<ReadingDocument>> loadDocuments() async {
    final rows = await (await index).primaryDocuments();
    final documents = <ReadingDocument>[];
    for (final row in rows) {
      final relativePath = row['relative_path']! as String;
      try {
        documents.add(
          ReadingDocument(
            id: row['id']! as String,
            title: row['name']! as String,
            content: decodeImportedText(await _files.readBytes(relativePath)),
            kind: row['kind'] == 'html'
                ? DocumentKind.html
                : DocumentKind.markdown,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              row['updated_at']! as int,
            ),
            sourceLabel: row['single'] == 1 ? '本地文件' : '文档包',
            filePath: relativePath,
            folderId: row['folder_id']! as String,
            relativePath: relativePath,
            logicalPath: _logicalPath(
              row,
              folderPath: row['folder_path']! as String,
            ),
          ),
        );
      } on Object {
        // A missing file is isolated to its package and must not crash startup.
      }
    }
    return documents;
  }

  Future<List<LibraryFolder>> loadFolders() async {
    final folderRows = await (await index).libraryFolders();
    final folders = <LibraryFolder>[];
    for (final folderRow in folderRows) {
      final folderId = folderRow['id']! as String;
      final rows = await (await index).packageDocuments(folderId);
      final nestedRows = await (await index).nestedFolders(folderId);
      final documents = <ReadingDocument>[];
      for (final row in rows) {
        if (row['kind'] == 'rss') continue;
        final relativePath = row['relative_path']! as String;
        try {
          documents.add(
            ReadingDocument(
              id: row['id']! as String,
              title: row['name']! as String,
              content: decodeImportedText(await _files.readBytes(relativePath)),
              kind: row['kind'] == 'html'
                  ? DocumentKind.html
                  : DocumentKind.markdown,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                row['updated_at']! as int,
              ),
              sourceLabel: '文件夹',
              filePath: relativePath,
              folderId: folderId,
              relativePath: relativePath,
              logicalPath: _logicalPath(
                row,
                folderPath: folderRow['relative_path']! as String,
              ),
            ),
          );
        } on Object {
          // Keep the folder visible even if one indexed file is missing.
        }
      }
      folders.add(
        LibraryFolder(
          id: folderId,
          name: folderRow['name']! as String,
          documents: documents,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            folderRow['updated_at']! as int,
          ),
          subfolderPaths: nestedRows
              .map((row) => row['logical_path']! as String)
              .where((path) => path.isNotEmpty)
              .toList(growable: false),
        ),
      );
    }
    return folders;
  }

  Future<void> createFolder(String name) async {
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}-folder';
    final relativePath = 'markdown/$id';
    await (await index).insertPackage(
      folder: FolderRecord(
        id: id,
        category: 'markdown',
        name: name,
        single: false,
        marker: 'user-folder',
        relativePath: relativePath,
        entryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
      documents: const [],
      resources: const [],
      writeFiles: () => _files.createFolder(relativePath),
    );
  }

  /// 在一个首页根文件夹内创建可独立存在的空子目录。
  Future<String> createSubfolder({
    required LibraryFolder rootFolder,
    required String parentPath,
    required String name,
  }) async {
    final safeName = name.trim();
    if (safeName.isEmpty || safeName == '.' || safeName == '..') {
      throw const FormatException('文件夹名称不能为空');
    }
    if (safeName.contains('/') || safeName.contains('\\')) {
      throw const FormatException('文件夹名称不能包含路径分隔符');
    }
    final db = await index;
    final rootRow = await db.folder(rootFolder.id);
    if (rootRow == null || rootRow['parent_id'] != null) {
      throw StateError('根文件夹不存在');
    }
    final normalizedParent = p.posix.normalize(parentPath.trim());
    final parentLogicalPath = normalizedParent == '.' ? '' : normalizedParent;
    if (parentLogicalPath.startsWith('../') ||
        p.posix.isAbsolute(parentLogicalPath)) {
      throw const FormatException('父文件夹路径不安全');
    }
    var parentId = rootFolder.id;
    var accumulatedPath = '';
    for (final segment
        in parentLogicalPath.split('/').where((part) => part.isNotEmpty)) {
      accumulatedPath = accumulatedPath.isEmpty
          ? segment
          : p.posix.join(accumulatedPath, segment);
      final existing = await db.nestedFolder(rootFolder.id, accumulatedPath);
      if (existing != null) {
        parentId = existing['id']! as String;
        continue;
      }
      // ZIP/.moyue 导入形成的目录过去只存在于 documents.logical_path。
      // 用户第一次在其中新建内容时，把这段隐式路径补成显式 folders 行。
      final materializedAt = DateTime.now();
      final materializedId =
          '${materializedAt.microsecondsSinceEpoch}-${sha256.convert(utf8.encode(accumulatedPath)).toString().substring(0, 8)}-subfolder';
      final materializedRelativePath = p.posix.join(
        rootRow['relative_path']! as String,
        '.folders',
        materializedId,
      );
      await db.insertPackage(
        folder: FolderRecord(
          id: materializedId,
          category: rootRow['category']! as String,
          name: segment,
          single: false,
          marker: 'nested-folder',
          relativePath: materializedRelativePath,
          entryCount: 0,
          createdAt: materializedAt,
          updatedAt: materializedAt,
          parentId: parentId,
          logicalPath: accumulatedPath,
        ),
        documents: const [],
        resources: const [],
        writeFiles: () => _files.createFolder(materializedRelativePath),
      );
      parentId = materializedId;
    }
    if (await db.siblingFolderExists(parentId, safeName)) {
      throw const FormatException('同一目录下已存在同名文件夹');
    }

    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}-subfolder';
    final logicalPath = parentLogicalPath.isEmpty
        ? safeName
        : p.posix.join(parentLogicalPath, safeName);
    final impliedByDocument = rootFolder.documents.any((document) {
      final path = document.logicalPath;
      return path != null && p.posix.isWithin(logicalPath, path);
    });
    if (impliedByDocument) {
      throw const FormatException('同一目录下已存在同名文件夹');
    }
    final relativePath = p.posix.join(
      rootRow['relative_path']! as String,
      '.folders',
      id,
    );
    await db.insertPackage(
      folder: FolderRecord(
        id: id,
        category: rootRow['category']! as String,
        name: safeName,
        single: false,
        marker: 'nested-folder',
        relativePath: relativePath,
        entryCount: 0,
        createdAt: now,
        updatedAt: now,
        parentId: parentId,
        logicalPath: logicalPath,
      ),
      documents: const [],
      resources: const [],
      writeFiles: () => _files.createFolder(relativePath),
    );
    return logicalPath;
  }

  Future<ReadingDocument> importIntoFolder({
    required LibraryFolder folder,
    required String fileName,
    required Uint8List bytes,
    String logicalDirectory = '',
  }) async {
    final extension = _extension(fileName);
    if (extension != 'md' && extension != 'html') {
      throw const FormatException('文件夹内仅支持导入 .md 或 .html 文件');
    }
    final folderRow = await (await index).folder(folder.id);
    if (folderRow == null) throw StateError('文件夹不存在');
    final safeName = p.posix.basename(_safeArchivePath(fileName));
    final existing = await (await index).packageDocuments(folder.id);
    final now = DateTime.now();
    final documentId = '${now.microsecondsSinceEpoch}-doc';
    final relativePath = p.posix.join(
      folderRow['relative_path']! as String,
      '.documents',
      documentId,
      safeName,
    );
    final normalizedDirectory = p.posix.normalize(logicalDirectory.trim());
    if (normalizedDirectory.startsWith('../') ||
        p.posix.isAbsolute(normalizedDirectory)) {
      throw const FormatException('目标文件夹路径不安全');
    }
    final logicalPath = normalizedDirectory == '.'
        ? safeName
        : p.posix.join(normalizedDirectory, safeName);
    final record = DocumentRecord(
      id: documentId,
      folderId: folder.id,
      name: p.posix.basenameWithoutExtension(safeName),
      kind: extension == 'html' ? 'html' : 'markdown',
      relativePath: relativePath,
      logicalPath: logicalPath,
      isPrimary: existing.isEmpty,
      contentHash: sha256.convert(bytes).toString(),
      createdAt: now,
      updatedAt: now,
    );
    await (await index).insertDocument(
      document: record,
      writeFile: () => _files.writeFiles({relativePath: bytes}),
    );
    return ReadingDocument(
      id: record.id,
      title: record.name,
      content: decodeImportedText(bytes),
      kind: extension == 'html' ? DocumentKind.html : DocumentKind.markdown,
      updatedAt: now,
      sourceLabel: '文件夹',
      filePath: relativePath,
      folderId: folder.id,
      relativePath: relativePath,
      logicalPath: logicalPath,
    );
  }

  Future<ReadingDocument> importFile(String fileName, Uint8List bytes) async {
    final extension = _extension(fileName);
    if (extension == 'md' || extension == 'html') {
      return _importEntries(
        sourceName: fileName,
        entries: {_safeArchivePath(fileName): bytes},
        single: true,
      );
    }
    if (extension != 'zip' && extension != 'moyue') {
      throw const FormatException('仅支持 Markdown、HTML、ZIP 或 .moyue 文件');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final entries = <String, Uint8List>{};
    for (final file in archive) {
      if (!file.isFile || file.isSymbolicLink) continue;
      final path = _safeArchivePath(decodeArchiveFileName(file.name));
      if (!_isAllowedPackageEntry(path)) {
        throw FormatException('压缩包包含不支持的文件类型：$path');
      }
      entries[path] = file.readBytes() ?? Uint8List(0);
    }
    if (entries.isEmpty) throw const FormatException('压缩包为空');
    if (entries.length < 2) {
      throw const FormatException('ZIP 或 .moyue 中至少需要包含 2 个文件');
    }
    return _importEntries(
      sourceName: fileName,
      entries: entries,
      single: false,
      requireMoyueMeta: extension == 'moyue',
    );
  }

  /// 将单文件或文档包导入已有文件夹。文档包先按常规导入规则完成校验与
  /// 索引，再把其中的每份文档移动进目标文件夹，从而复用同一套资源搬运
  /// 与事务逻辑，并保留压缩包内的相对目录结构。
  Future<List<ReadingDocument>> importPackageIntoFolder({
    required LibraryFolder folder,
    required String fileName,
    required Uint8List bytes,
    String logicalDirectory = '',
  }) async {
    final extension = _extension(fileName);
    if (extension == 'md' || extension == 'html') {
      return [
        await importIntoFolder(
          folder: folder,
          fileName: fileName,
          bytes: bytes,
          logicalDirectory: logicalDirectory,
        ),
      ];
    }
    if (extension != 'zip' && extension != 'moyue') {
      throw const FormatException('仅支持 Markdown、HTML、ZIP 或 .moyue 文件');
    }

    final importedPrimary = await importFile(fileName, bytes);
    final sourceFolderId = importedPrimary.folderId;
    if (sourceFolderId == null) {
      throw StateError('文档包已导入，但无法读取它的文件夹索引');
    }
    final db = await index;
    final sourceFolderRow = await db.folder(sourceFolderId);
    if (sourceFolderRow == null) {
      throw StateError('文档包已导入，但无法读取它的文件夹索引');
    }
    final sourceDocuments = <ReadingDocument>[];
    for (final row in await db.packageDocuments(sourceFolderId)) {
      final relativePath = row['relative_path']! as String;
      sourceDocuments.add(
        ReadingDocument(
          id: row['id']! as String,
          title: row['name']! as String,
          content: decodeImportedText(await _files.readBytes(relativePath)),
          kind: row['kind'] == 'html'
              ? DocumentKind.html
              : DocumentKind.markdown,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row['updated_at']! as int,
          ),
          sourceLabel: '文档包',
          filePath: relativePath,
          folderId: sourceFolderId,
          relativePath: relativePath,
          logicalPath: _logicalPath(
            row,
            folderPath: sourceFolderRow['relative_path']! as String,
          ),
        ),
      );
    }
    final normalizedDirectory = p.posix.normalize(logicalDirectory.trim());
    if (normalizedDirectory.startsWith('../') ||
        p.posix.isAbsolute(normalizedDirectory)) {
      throw const FormatException('目标文件夹路径不安全');
    }
    final moved = <ReadingDocument>[];
    for (final document in sourceDocuments) {
      final sourceLogicalPath =
          document.logicalPath ??
          '${document.title}.${document.kind.extension}';
      final targetLogicalPath = normalizedDirectory == '.'
          ? sourceLogicalPath
          : p.posix.join(normalizedDirectory, sourceLogicalPath);
      moved.add(
        await moveDocument(
          document: document,
          target: folder,
          targetLogicalPath: targetLogicalPath,
        ),
      );
    }
    return moved;
  }

  Future<ReadingDocument> _importEntries({
    required String sourceName,
    required Map<String, Uint8List> entries,
    required bool single,
    bool requireMoyueMeta = false,
  }) async {
    final metaBytes = entries['meta.json'];
    if (requireMoyueMeta && metaBytes == null) {
      throw const FormatException('.moyue 缺少 meta.json');
    }
    final meta = metaBytes == null
        ? <String, Object?>{}
        : jsonDecode(decodeImportedText(metaBytes)) as Map<String, Object?>;
    if (meta.isNotEmpty && meta['format'] != 'moyue') {
      throw const FormatException('meta.json 的 format 必须为 moyue');
    }
    if (meta.isNotEmpty && meta['format_version'] != 1) {
      throw const FormatException('暂不支持此 .moyue 格式版本');
    }

    final declaredDocuments = meta['documents'];
    final documentEntries =
        <({String archivePath, String logicalPath, String sourceId})>[];
    if (declaredDocuments is List) {
      for (var index = 0; index < declaredDocuments.length; index++) {
        final value = declaredDocuments[index];
        if (value is! Map) throw const FormatException('文档元信息格式不正确');
        final archivePath = _safeArchivePath(
          (value['archive_path'] ?? value['path']) as String,
        );
        final logicalPath = _safeArchivePath(
          (value['path'] ?? archivePath) as String,
        );
        if (!_isDocument(logicalPath) || !entries.containsKey(archivePath)) {
          throw FormatException('文档元信息指向了不存在的文件：$logicalPath');
        }
        documentEntries.add((
          archivePath: archivePath,
          logicalPath: logicalPath,
          sourceId: (value['id'] as String?) ?? 'document-${index + 1}',
        ));
      }
    } else {
      final paths = entries.keys.where(_isDocument).toList()..sort();
      for (var index = 0; index < paths.length; index++) {
        documentEntries.add((
          archivePath: paths[index],
          logicalPath: paths[index],
          sourceId: 'document-${index + 1}',
        ));
      }
    }
    if (documentEntries.isEmpty) {
      throw const FormatException('没有找到 Markdown 或 HTML 文件');
    }
    final declaredPrimary = meta['primary_document'] as String?;
    final declaredPrimaryId = meta['primary_document_id'] as String?;
    var primaryEntry = documentEntries.first;
    if (declaredPrimary != null || declaredPrimaryId != null) {
      final matches = documentEntries.where(
        (entry) =>
            (declaredPrimaryId != null &&
                entry.sourceId == declaredPrimaryId) ||
            (declaredPrimary != null &&
                (entry.archivePath == declaredPrimary ||
                    entry.logicalPath == declaredPrimary)),
      );
      if (matches.isEmpty) {
        throw const FormatException('meta.json 指定的主文档不存在');
      }
      primaryEntry = matches.first;
    }

    final now = DateTime.now();
    final folderId =
        '${now.microsecondsSinceEpoch}-${sha256.convert(bytesForId(sourceName, entries)).toString().substring(0, 10)}';
    final kind = _kindFor(primaryEntry.logicalPath);
    final category = kind == DocumentKind.html ? 'html' : 'markdown';
    final folderPath = '$category/$folderId';
    final displayName = (meta['display_name'] as String?)?.trim();
    final folderName = displayName == null || displayName.isEmpty
        ? p.posix.basenameWithoutExtension(sourceName)
        : displayName;
    final marker = (meta['marker'] as String?) ?? 'imported';
    final documents = <DocumentRecord>[];
    final resources = <ResourceRecord>[];
    final files = <String, Uint8List>{};

    final sourceDocumentIds = <String, DocumentRecord>{};
    for (final entry in documentEntries) {
      final documentId = '$folderId-doc-${documents.length + 1}';
      final relativePath = declaredDocuments is List
          ? p.posix.join(
              folderPath,
              '.documents',
              documentId,
              p.posix.basename(entry.logicalPath),
            )
          : '$folderPath/${entry.logicalPath}';
      final data = entries[entry.archivePath]!;
      final record = DocumentRecord(
        id: documentId,
        folderId: folderId,
        name: p.posix.basenameWithoutExtension(entry.logicalPath),
        kind: _kindFor(entry.logicalPath) == DocumentKind.html
            ? 'html'
            : 'markdown',
        relativePath: relativePath,
        logicalPath: entry.logicalPath,
        isPrimary: entry == primaryEntry,
        contentHash: sha256.convert(data).toString(),
        createdAt: now,
        updatedAt: now,
      );
      documents.add(record);
      sourceDocumentIds[entry.sourceId] = record;
      files[relativePath] = data;
    }

    final declaredResources = meta['resources'];
    final resourceEntries =
        <({String archivePath, String logicalPath, String? documentId})>[];
    if (declaredResources is List) {
      for (final value in declaredResources) {
        if (value is! Map) throw const FormatException('资源元信息格式不正确');
        final archivePath = _safeArchivePath(
          (value['archive_path'] ?? value['path']) as String,
        );
        if (!entries.containsKey(archivePath)) {
          throw FormatException('资源元信息指向了不存在的文件：$archivePath');
        }
        resourceEntries.add((
          archivePath: archivePath,
          logicalPath: _safeArchivePath(
            (value['path'] ?? p.posix.basename(archivePath)) as String,
          ),
          documentId: value['document_id'] as String?,
        ));
      }
    } else {
      final documentArchivePaths = documentEntries
          .map((entry) => entry.archivePath)
          .toSet();
      for (final path in entries.keys) {
        if (documentArchivePaths.contains(path) || path == 'meta.json') {
          continue;
        }
        resourceEntries.add((
          archivePath: path,
          logicalPath: path,
          documentId: null,
        ));
      }
    }
    for (final entry in resourceEntries) {
      final attachedDocument = entry.documentId == null
          ? null
          : sourceDocumentIds[entry.documentId];
      final relativePath = attachedDocument == null
          ? p.posix.join(folderPath, entry.logicalPath)
          : p.posix.normalize(
              p.posix.join(
                p.posix.dirname(attachedDocument.relativePath),
                entry.logicalPath,
              ),
            );
      final data = entries[entry.archivePath]!;
      resources.add(
        ResourceRecord(
          id: '$folderId-res-${resources.length + 1}',
          folderId: folderId,
          documentId: attachedDocument?.id,
          name: p.posix.basename(entry.logicalPath),
          mimeType: _mimeType(entry.logicalPath),
          relativePath: relativePath,
          contentHash: sha256.convert(data).toString(),
          sizeBytes: data.length,
        ),
      );
      files[relativePath] = data;
    }

    final folder = FolderRecord(
      id: folderId,
      category: category,
      name: folderName,
      single: single || documentEntries.length <= 2,
      marker: marker,
      relativePath: folderPath,
      entryCount: documents.length + resources.length,
      createdAt: now,
      updatedAt: now,
    );
    final db = await index;
    await db.insertPackage(
      folder: folder,
      documents: documents,
      resources: resources,
      writeFiles: () async {
        try {
          await _files.writeFiles(files);
        } on Object {
          await _files.deleteFolder(folderPath);
          rethrow;
        }
      },
    );
    final primary = documents.firstWhere((item) => item.isPrimary);
    return ReadingDocument(
      id: primary.id,
      title: primary.name,
      content: decodeImportedText(entries[primaryEntry.archivePath]!),
      kind: kind,
      updatedAt: now,
      sourceLabel: single ? '本地文件' : '文档包',
      filePath: primary.relativePath,
      folderId: folderId,
      relativePath: primary.relativePath,
      logicalPath: primary.logicalPath,
    );
  }

  Future<ReadingDocument> saveMarkdown({
    required String title,
    required String content,
    ReadingDocument? existing,
  }) async {
    final data = Uint8List.fromList(utf8.encode(content));
    if (existing?.folderId == null || existing?.relativePath == null) {
      return importFile('$title.md', data);
    }
    final now = DateTime.now();
    final db = await index;
    final rows = await db.packageDocuments(existing!.folderId!);
    final currentRows = rows.where((row) => row['id'] == existing.id);
    final currentRow = currentRows.isEmpty ? null : currentRows.first;
    final updated = DocumentRecord(
      id: existing.id,
      folderId: existing.folderId!,
      name: title,
      kind: 'markdown',
      relativePath: existing.relativePath!,
      logicalPath: _renamedLogicalPath(existing, title, 'md'),
      isPrimary: currentRow?['is_primary'] == 1,
      contentHash: sha256.convert(data).toString(),
      createdAt: currentRow == null
          ? existing.updatedAt
          : DateTime.fromMillisecondsSinceEpoch(
              currentRow['created_at']! as int,
            ),
      updatedAt: now,
    );
    await db.updateDocument(updated);
    await _files.writeFiles({updated.relativePath: data});
    return existing.copyWith(
      title: title,
      content: content,
      updatedAt: now,
      logicalPath: updated.logicalPath,
    );
  }

  /// 把单个文档移动到另一个用户文件夹。目标中的同名文档不会被覆盖，
  /// 因为实际文件始终存放在 `.documents/<document-id>/` 下。
  Future<ReadingDocument> moveDocument({
    required ReadingDocument document,
    required LibraryFolder target,
    String? targetLogicalPath,
  }) async {
    final sourceFolderId = document.folderId;
    final sourcePath = document.relativePath;
    if (sourceFolderId == null || sourcePath == null) {
      throw StateError('未索引的旧文档不能直接移动');
    }
    if (sourceFolderId == target.id) return document;
    final db = await index;
    final sourceFolder = await db.folder(sourceFolderId);
    final targetFolder = await db.folder(target.id);
    if (sourceFolder == null || targetFolder == null) {
      throw StateError('源文件夹或目标文件夹不存在');
    }

    final now = DateTime.now();
    final extension = document.kind.extension;
    final requestedLogicalPath = _safeArchivePath(
      targetLogicalPath ??
          document.logicalPath ??
          '${document.title}.$extension',
    );
    final visibleName = p.posix.basename(requestedLogicalPath);
    final targetPath = p.posix.join(
      targetFolder['relative_path']! as String,
      '.documents',
      document.id,
      visibleName,
    );
    final targetFiles = <String, Uint8List>{
      targetPath: await _files.readBytes(sourcePath),
    };
    final resources = <ResourceRecord>[];
    for (final link in _localAssetReferences(document.content)) {
      final sourceResource = p.posix.normalize(
        p.posix.join(p.posix.dirname(sourcePath), link),
      );
      final sourceBase = sourceFolder['relative_path']! as String;
      if (sourceResource != sourceBase &&
          !p.posix.isWithin(sourceBase, sourceResource)) {
        continue;
      }
      try {
        final bytes = await _files.readBytes(sourceResource);
        final targetResource = p.posix.normalize(
          p.posix.join(p.posix.dirname(targetPath), link),
        );
        targetFiles[targetResource] = bytes;
        resources.add(
          ResourceRecord(
            id: '${document.id}-res-${resources.length + 1}',
            folderId: target.id,
            documentId: document.id,
            name: p.posix.basename(targetResource),
            mimeType: _mimeType(targetResource),
            relativePath: targetResource,
            contentHash: sha256.convert(bytes).toString(),
            sizeBytes: bytes.length,
          ),
        );
      } on Object {
        // 断裂的相对链接保留在正文中，不阻止用户移动文档。
      }
    }
    final targetDocuments = await db.packageDocuments(target.id);
    final record = DocumentRecord(
      id: document.id,
      folderId: target.id,
      name: document.title,
      kind: document.kind == DocumentKind.html ? 'html' : 'markdown',
      relativePath: targetPath,
      logicalPath: requestedLogicalPath,
      isPrimary: targetDocuments.isEmpty,
      contentHash: sha256.convert(targetFiles[targetPath]!).toString(),
      createdAt: document.updatedAt,
      updatedAt: now,
    );
    await db.moveDocument(
      document: record,
      sourceFolderId: sourceFolderId,
      resources: resources,
      writeFiles: () => _files.writeFiles(targetFiles),
    );

    try {
      final sourceDocuments = await db.packageDocuments(sourceFolderId);
      if (sourceDocuments.isEmpty && sourceFolder['marker'] != 'user-folder') {
        await db.deleteFolder(sourceFolderId);
        await _files.deleteFolder(sourceFolder['relative_path']! as String);
      } else if (_isPrivateDocumentPath(sourcePath, document.id)) {
        await _files.deleteFolder(p.posix.dirname(sourcePath));
      } else {
        await _files.deleteFile(sourcePath);
      }
    } on Object {
      // 目标文件及索引已经提交成功。源端清理失败只会留下可在后续审计中
      // 回收的孤儿文件，不能把一次成功移动报告成失败并让 UI 重试。
    }
    return document.copyWith(
      folderId: target.id,
      relativePath: targetPath,
      filePath: targetPath,
      logicalPath: requestedLogicalPath,
      sourceLabel: '文件夹',
      updatedAt: now,
    );
  }

  /// 将文件夹文档拆分为首页上的独立单文件记录。
  Future<ReadingDocument> moveDocumentToLibrary(
    ReadingDocument document,
  ) async {
    if (document.folderId == null || document.relativePath == null) {
      throw StateError('未索引的旧文档不能从文件夹移出');
    }
    final now = DateTime.now();
    final category = document.kind == DocumentKind.html ? 'html' : 'markdown';
    final digest = sha256
        .convert(utf8.encode('${document.id}-${now.microsecondsSinceEpoch}'))
        .toString()
        .substring(0, 10);
    final folderId = '${now.microsecondsSinceEpoch}-$digest';
    final relativePath = '$category/$folderId';
    final db = await index;
    await db.insertPackage(
      folder: FolderRecord(
        id: folderId,
        category: category,
        name: document.title,
        single: true,
        marker: 'detached',
        relativePath: relativePath,
        entryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
      documents: const [],
      resources: const [],
      writeFiles: () => _files.createFolder(relativePath),
    );
    try {
      return await moveDocument(
        document: document,
        target: LibraryFolder(
          id: folderId,
          name: document.title,
          documents: const [],
          updatedAt: now,
        ),
      );
    } on Object {
      await db.deleteFolder(folderId);
      await _files.deleteFolder(relativePath);
      rethrow;
    }
  }

  Future<void> deleteDocument(ReadingDocument document) async {
    final folderId = document.folderId;
    if (folderId == null) return;
    final folder = await (await index).folder(folderId);
    if (folder == null) return;
    final documents = await (await index).packageDocuments(folderId);
    if (documents.length <= 1 && folder['marker'] != 'user-folder') {
      await (await index).deleteFolder(folderId);
      await _files.deleteFolder(folder['relative_path']! as String);
      return;
    }
    await (await index).deleteDocument(document.id, folderId);
    if (document.relativePath case final path?) {
      if (_isPrivateDocumentPath(path, document.id)) {
        await _files.deleteFolder(p.posix.dirname(path));
      } else {
        await _files.deleteFile(path);
      }
    }
  }

  Future<void> renameFolder(String folderId, String name) =>
      index.then((db) => db.renameFolder(folderId, name));

  Future<void> deleteFolderById(String folderId) async {
    final folder = await (await index).folder(folderId);
    if (folder == null) return;
    await (await index).deleteFolder(folderId);
    await _files.deleteFolder(folder['relative_path']! as String);
  }

  Future<MoyueExport> exportMoyue(ReadingDocument document) async {
    final folderId = document.folderId;
    if (folderId == null) throw StateError('文档尚未进入文档包索引');
    return exportMoyueFolder(folderId);
  }

  Future<MoyueExport> exportMoyueFolder(String folderId) async {
    final db = await index;
    final folder = await db.folder(folderId);
    if (folder == null) throw StateError('找不到文档包');
    final docs = await db.packageDocuments(folderId);
    if (docs.isEmpty) throw StateError('空文件夹无法导出');
    final resources = await db.packageResources(folderId);
    final base = folder['relative_path']! as String;
    final archive = Archive();
    final documentMeta = <Map<String, Object?>>[];
    final resourceMeta = <Map<String, Object?>>[];
    final docsById = {for (final row in docs) row['id']! as String: row};
    for (final row in docs) {
      final id = row['id']! as String;
      final logicalPath = _logicalPath(row, folderPath: base);
      final archivePath = p.posix.join(
        'payload',
        'documents',
        id,
        p.posix.basename(logicalPath),
      );
      archive.addFile(
        ArchiveFile.bytes(
          archivePath,
          await _files.readBytes(row['relative_path']! as String),
        ),
      );
      documentMeta.add({
        'id': id,
        'path': logicalPath,
        'archive_path': archivePath,
        'kind': row['kind'],
        'sha256': row['content_hash'],
      });
    }
    for (final row in resources) {
      final id = row['id']! as String;
      final documentId = row['document_id'] as String?;
      final relative = row['relative_path']! as String;
      String logicalPath;
      final attachedDocument = documentId == null ? null : docsById[documentId];
      if (attachedDocument != null) {
        logicalPath = p.posix.relative(
          relative,
          from: p.posix.dirname(attachedDocument['relative_path']! as String),
        );
      } else {
        logicalPath = p.posix.relative(relative, from: base);
      }
      final archivePath = p.posix.join(
        'payload',
        'resources',
        id,
        p.posix.basename(logicalPath),
      );
      archive.addFile(
        ArchiveFile.bytes(archivePath, await _files.readBytes(relative)),
      );
      resourceMeta.add({
        'id': id,
        'document_id': documentId,
        'path': logicalPath,
        'archive_path': archivePath,
        'mime_type': row['mime_type'],
        'sha256': row['content_hash'],
        'size': row['size_bytes'],
      });
    }
    final attachedPairs = <String>{
      for (final row in resources)
        if (row['document_id'] != null)
          '${row['document_id']}|${row['relative_path']}',
    };
    for (final document in docs) {
      final documentId = document['id']! as String;
      final documentPath = document['relative_path']! as String;
      final content = decodeImportedText(await _files.readBytes(documentPath));
      for (final link in _localAssetReferences(content)) {
        final relative = p.posix.normalize(
          p.posix.join(p.posix.dirname(documentPath), link),
        );
        if (relative != base && !p.posix.isWithin(base, relative)) continue;
        if (!attachedPairs.add('$documentId|$relative')) continue;
        try {
          final bytes = await _files.readBytes(relative);
          final resourceId =
              '$documentId-derived-${sha256.convert(utf8.encode(link)).toString().substring(0, 12)}';
          final archivePath = p.posix.join(
            'payload',
            'resources',
            resourceId,
            p.posix.basename(link),
          );
          archive.addFile(ArchiveFile.bytes(archivePath, bytes));
          resourceMeta.add({
            'id': resourceId,
            'document_id': documentId,
            'path': link,
            'archive_path': archivePath,
            'mime_type': _mimeType(link),
            'sha256': sha256.convert(bytes).toString(),
            'size': bytes.length,
          });
        } on Object {
          // 断裂链接保持在正文中，不阻止其余内容导出。
        }
      }
    }
    final primaryRows = docs.where((row) => row['is_primary'] == 1);
    final primary = primaryRows.isEmpty ? docs.first : primaryRows.first;
    final primaryId = primary['id']! as String;
    final primaryMeta = documentMeta.firstWhere(
      (item) => item['id'] == primaryId,
    );
    final meta = {
      'format': 'moyue',
      'format_version': 1,
      'display_name': folder['name'],
      'marker': folder['marker'],
      'single': folder['single'] == 1,
      'primary_document_id': primaryId,
      'primary_document': primaryMeta['archive_path'],
      'documents': documentMeta,
      'resources': resourceMeta,
    };
    archive.addFile(
      ArchiveFile.string(
        'meta.json',
        const JsonEncoder.withIndent('  ').convert(meta),
      ),
    );
    return MoyueExport(
      fileName: '${_safeFileName(folder['name']! as String)}.moyue',
      bytes: ZipEncoder().encodeBytes(archive),
    );
  }

  Future<Uint8List?> readLinkedResource(
    ReadingDocument document,
    String link,
  ) async {
    final documentPath = document.relativePath;
    final folderId = document.folderId;
    if (documentPath == null || folderId == null) return null;
    final uri = Uri.tryParse(link);
    if (uri == null || uri.hasScheme || uri.path.isEmpty) return null;
    var relative = Uri.decodeComponent(uri.path);
    if (relative.startsWith('./')) relative = relative.substring(2);
    final folder = await (await index).folder(folderId);
    if (folder == null) return null;
    final folderPath = folder['relative_path']! as String;
    final resolved = p.posix.normalize(
      p.posix.join(p.posix.dirname(documentPath), relative),
    );
    if (resolved != folderPath && !p.posix.isWithin(folderPath, resolved)) {
      return null;
    }
    try {
      return await _files.readBytes(resolved);
    } on Object {
      return null;
    }
  }

  Future<List<FeedSource>> loadFeedSources() async {
    final rows = await (await index).rssDocuments();
    return rows
        .map((row) {
          return FeedSource(
            id: row['folder_id']! as String,
            title: row['name']! as String,
            url: Uri.parse(row['source_url']! as String),
            rawFilePath: row['relative_path']! as String,
          );
        })
        .toList(growable: false);
  }

  Future<FeedSource> saveFeed(FeedSource source, String xml) async {
    final now = DateTime.now();
    final folderId = source.id;
    final folderPath = 'rss/$folderId';
    final relativePath = '$folderPath/feed.xml';
    final data = Uint8List.fromList(utf8.encode(xml));
    final folder = FolderRecord(
      id: folderId,
      category: 'rss',
      name: source.title,
      single: true,
      marker: 'rss-feed',
      relativePath: folderPath,
      entryCount: 1,
      createdAt: now,
      updatedAt: now,
    );
    final document = DocumentRecord(
      id: '$folderId-feed',
      folderId: folderId,
      name: source.title,
      kind: 'rss',
      relativePath: relativePath,
      logicalPath: 'feed.xml',
      isPrimary: true,
      contentHash: sha256.convert(data).toString(),
      createdAt: now,
      updatedAt: now,
      sourceUrl: source.url.toString(),
    );
    await (await index).upsertRss(
      folder: folder,
      document: document,
      writeFile: () => _files.writeFiles({relativePath: data}),
    );
    return source.copyWith(rawFilePath: relativePath);
  }

  Future<String?> readFeed(FeedSource source) async {
    final path = source.rawFilePath;
    if (path == null) return null;
    try {
      return await _files.readText(path);
    } on Object {
      return null;
    }
  }

  Future<void> deleteFeed(FeedSource source) async {
    final folder = await (await index).folder(source.id);
    if (folder == null) return;
    await (await index).deleteFolder(source.id);
    await _files.deleteFolder(folder['relative_path']! as String);
  }

  List<int> bytesForId(
    String sourceName,
    Map<String, Uint8List> entries,
  ) => utf8.encode(
    '$sourceName:${entries.keys.join('|')}:${entries.values.fold<int>(0, (sum, value) => sum + value.length)}',
  );

  String _safeArchivePath(String value) {
    final normalized = p.posix.normalize(value.replaceAll('\\', '/'));
    if (normalized == '.' ||
        normalized.startsWith('../') ||
        normalized.startsWith('/')) {
      throw const FormatException('压缩包包含不安全路径');
    }
    return normalized;
  }

  String _extension(String value) =>
      p.extension(value).replaceFirst('.', '').toLowerCase();
  bool _isDocument(String value) =>
      const {'md', 'html'}.contains(_extension(value));
  DocumentKind _kindFor(String value) =>
      _extension(value) == 'html' ? DocumentKind.html : DocumentKind.markdown;

  bool _isAllowedPackageEntry(String value) {
    if (value == 'meta.json') return true;
    return const {
      'md',
      'html',
      'css',
      'js',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'svg',
      'avif',
      'bmp',
      'ico',
      'mp4',
      'webm',
      'mov',
      'm4v',
      'ogv',
    }.contains(_extension(value));
  }

  String _safeFileName(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  String _logicalPath(Map<String, Object?> row, {required String folderPath}) {
    final stored = row['logical_path'] as String?;
    if (stored != null && stored.trim().isNotEmpty) return stored;
    return p.posix.relative(row['relative_path']! as String, from: folderPath);
  }

  String _renamedLogicalPath(
    ReadingDocument document,
    String title,
    String extension,
  ) {
    final previous = document.logicalPath;
    final parent = previous == null ? '.' : p.posix.dirname(previous);
    final fileName = '${_safeFileName(title)}.$extension';
    return parent == '.' ? fileName : p.posix.join(parent, fileName);
  }

  Set<String> _localAssetReferences(String content) {
    final links = extractImageReferences(content);
    final htmlAsset = RegExp(
      r'''<(?:link|script|video|source)[^>]+(?:href|src)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final match in htmlAsset.allMatches(content)) {
      final raw = match.group(1)!;
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.hasScheme || raw.startsWith('/')) continue;
      links.add(raw.startsWith('./') ? raw.substring(2) : uri.path);
    }
    final cssAsset = RegExp(
      r'''url\(\s*(["']?)([^"')]+)\1\s*\)''',
      caseSensitive: false,
    );
    for (final match in cssAsset.allMatches(content)) {
      final raw = match.group(2)!.trim();
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.hasScheme || raw.startsWith('/')) continue;
      links.add(raw.startsWith('./') ? raw.substring(2) : uri.path);
    }
    return links;
  }

  bool _isPrivateDocumentPath(String path, String documentId) =>
      path.contains('/.documents/$documentId/');

  String _mimeType(String path) {
    return switch (_extension(path)) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'avif' => 'image/avif',
      'bmp' => 'image/bmp',
      'ico' => 'image/x-icon',
      'css' => 'text/css',
      'js' => 'text/javascript',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'ogv' => 'video/ogg',
      _ => 'application/octet-stream',
    };
  }
}

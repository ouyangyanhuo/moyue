import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
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
  DocumentPackageService() : _files = createPackageFileStore();
  final PackageFileStore _files;
  MoyueIndexDatabase? _index;

  Future<MoyueIndexDatabase> get index async =>
      _index ??= MoyueIndexDatabase(await _files.databasePath());

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

  Future<ReadingDocument> importIntoFolder({
    required LibraryFolder folder,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final extension = _extension(fileName);
    if (extension != 'md' && extension != 'html') {
      throw const FormatException('文件夹内仅支持导入 .md 或 .html 文件');
    }
    final folderRow = await (await index).folder(folder.id);
    if (folderRow == null) throw StateError('文件夹不存在');
    final safeName = p.posix.basename(_safeArchivePath(fileName));
    final relativePath = '${folderRow['relative_path']}/$safeName';
    final existing = await (await index).packageDocuments(folder.id);
    if (existing.any((row) => row['relative_path'] == relativePath)) {
      throw FormatException('文件夹中已存在 $safeName');
    }
    final now = DateTime.now();
    final record = DocumentRecord(
      id: '${now.microsecondsSinceEpoch}-doc',
      folderId: folder.id,
      name: p.posix.basenameWithoutExtension(safeName),
      kind: extension == 'html' ? 'html' : 'markdown',
      relativePath: relativePath,
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

    final documentPaths = entries.keys.where(_isDocument).toList()..sort();
    if (documentPaths.isEmpty) {
      throw const FormatException('没有找到 Markdown 或 HTML 文件');
    }
    final declaredPrimary = meta['primary_document'] as String?;
    final primaryPath = declaredPrimary != null
        ? _safeArchivePath(declaredPrimary)
        : documentPaths.first;
    if (!documentPaths.contains(primaryPath)) {
      throw const FormatException('meta.json 指定的主文档不存在');
    }

    final now = DateTime.now();
    final folderId =
        '${now.microsecondsSinceEpoch}-${sha256.convert(bytesForId(sourceName, entries)).toString().substring(0, 10)}';
    final kind = _kindFor(primaryPath);
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

    for (final path in documentPaths) {
      final relativePath = '$folderPath/$path';
      final data = entries[path]!;
      documents.add(
        DocumentRecord(
          id: '$folderId-doc-${documents.length + 1}',
          folderId: folderId,
          name: p.posix.basenameWithoutExtension(path),
          kind: _kindFor(path) == DocumentKind.html ? 'html' : 'markdown',
          relativePath: relativePath,
          isPrimary: path == primaryPath,
          contentHash: sha256.convert(data).toString(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      files[relativePath] = data;
    }
    for (final entry in entries.entries) {
      if (_isDocument(entry.key) || entry.key == 'meta.json') continue;
      final relativePath = '$folderPath/${entry.key}';
      resources.add(
        ResourceRecord(
          id: '$folderId-res-${resources.length + 1}',
          folderId: folderId,
          documentId: null,
          name: p.posix.basename(entry.key),
          mimeType: _mimeType(entry.key),
          relativePath: relativePath,
          contentHash: sha256.convert(entry.value).toString(),
          sizeBytes: entry.value.length,
        ),
      );
      files[relativePath] = entry.value;
    }

    final folder = FolderRecord(
      id: folderId,
      category: category,
      name: folderName,
      single: single || documentPaths.length <= 2,
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
      content: decodeImportedText(entries[primaryPath]!),
      kind: kind,
      updatedAt: now,
      sourceLabel: single ? '本地文件' : '文档包',
      filePath: primary.relativePath,
      folderId: folderId,
      relativePath: primary.relativePath,
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
    final updated = DocumentRecord(
      id: existing!.id,
      folderId: existing.folderId!,
      name: title,
      kind: 'markdown',
      relativePath: existing.relativePath!,
      isPrimary: true,
      contentHash: sha256.convert(data).toString(),
      createdAt: existing.updatedAt,
      updatedAt: now,
    );
    await (await index).updateDocument(updated);
    await _files.writeFiles({updated.relativePath: data});
    return existing.copyWith(title: title, content: content, updatedAt: now);
  }

  Future<void> deleteDocument(ReadingDocument document) async {
    final folderId = document.folderId;
    if (folderId == null) return;
    final folder = await (await index).folder(folderId);
    if (folder == null) return;
    final documents = await (await index).packageDocuments(folderId);
    if (documents.length <= 1) {
      await (await index).deleteFolder(folderId);
      await _files.deleteFolder(folder['relative_path']! as String);
      return;
    }
    await (await index).deleteDocument(document.id, folderId);
    if (document.relativePath case final path?) {
      await _files.deleteFile(path);
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
    final db = await index;
    final folder = await db.folder(folderId);
    if (folder == null) throw StateError('找不到文档包');
    final docs = await db.packageDocuments(folderId);
    final resources = await db.packageResources(folderId);
    final base = folder['relative_path']! as String;
    final archive = Archive();
    String packagePath(String relative) =>
        p.posix.relative(relative, from: base);
    for (final row in [...docs, ...resources]) {
      final relative = row['relative_path']! as String;
      archive.addFile(
        ArchiveFile.bytes(
          packagePath(relative),
          await _files.readBytes(relative),
        ),
      );
    }
    final primary = docs.firstWhere((row) => row['is_primary'] == 1);
    final meta = {
      'format': 'moyue',
      'format_version': 1,
      'display_name': folder['name'],
      'marker': folder['marker'],
      'single': folder['single'] == 1,
      'primary_document': packagePath(primary['relative_path']! as String),
      'documents': docs
          .map(
            (row) => {
              'path': packagePath(row['relative_path']! as String),
              'kind': row['kind'],
              'sha256': row['content_hash'],
            },
          )
          .toList(),
      'resources': resources
          .map(
            (row) => {
              'path': packagePath(row['relative_path']! as String),
              'mime_type': row['mime_type'],
              'sha256': row['content_hash'],
              'size': row['size_bytes'],
            },
          )
          .toList(),
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
    final folder = await (await index).folder(folderId);
    if (folder == null) return null;
    final folderPath = folder['relative_path']! as String;
    final resolved = p.posix.normalize(
      p.posix.join(p.posix.dirname(documentPath), uri.path),
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

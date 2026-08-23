import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/database/moyue_index_database.dart';
import 'package:moyue_application/services/document_package_service.dart';
import 'package:moyue_application/services/storage/package_file_store_base.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _IndexedMemoryStore implements PackageFileStore {
  _IndexedMemoryStore(this.root);

  final Directory root;
  final Map<String, Uint8List> files = {};

  @override
  Future<String> databasePath() async => p.join(root.path, 'index.db');

  @override
  Future<void> createFolder(String relativePath) async {
    files['$relativePath/'] = Uint8List(0);
  }

  @override
  Future<void> writeFiles(Map<String, Uint8List> newFiles) async {
    files.addAll(newFiles);
  }

  @override
  Future<Uint8List> readBytes(String relativePath) async {
    final bytes = files[relativePath];
    if (bytes == null) throw StateError('missing $relativePath');
    return bytes;
  }

  @override
  Future<String> readText(String relativePath) async =>
      utf8.decode(await readBytes(relativePath));

  @override
  Future<void> deleteFile(String relativePath) async {
    files.remove(relativePath);
  }

  @override
  Future<void> deleteFolder(String relativePath) async {
    files.removeWhere(
      (path, _) => path == relativePath || path.startsWith('$relativePath/'),
    );
  }

  @override
  Future<List<String>> listFiles(String relativeDir) async {
    final prefix = '$relativeDir/';
    return files.keys
        .where((path) => path.startsWith(prefix))
        .where((path) => !path.substring(prefix.length).contains('/'))
        .toList(growable: false);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  test('同一文件夹允许同名文档，物理文件互不覆盖且 moyue 可逆', () async {
    final root = await Directory.systemTemp.createTemp('moyue-storage-v4-');
    final store = _IndexedMemoryStore(root);
    final service = DocumentPackageService(store: store);
    addTearDown(() async {
      await service.close();
      await root.delete(recursive: true);
    });

    await service.createFolder('来源');
    await service.createFolder('目标');
    var folders = await service.loadFolders();
    final source = folders.singleWhere((folder) => folder.name == '来源');
    final target = folders.singleWhere((folder) => folder.name == '目标');

    var first = await service.importIntoFolder(
      folder: source,
      fileName: '同名.md',
      bytes: Uint8List.fromList(utf8.encode('# 第一份')),
    );
    final second = await service.importIntoFolder(
      folder: source,
      fileName: '同名.md',
      bytes: Uint8List.fromList(utf8.encode('# 第二份')),
    );
    final imageLink = await service.saveImageResource(
      document: first,
      fileName: '插图.png',
      bytes: Uint8List.fromList([1, 3, 5, 7]),
    );
    first = await service.saveMarkdown(
      title: first.title,
      content: '# 第一份\n\n![]($imageLink)',
      existing: first,
    );

    expect(first.logicalPath, '同名.md');
    expect(second.logicalPath, '同名.md');
    expect(first.relativePath, isNot(second.relativePath));
    expect(
      store.files[first.relativePath],
      isNot(store.files[second.relativePath]),
    );

    final export = await service.exportMoyueFolder(source.id);
    final archive = ZipDecoder().decodeBytes(export.bytes);
    final metaFile = archive.files.singleWhere(
      (file) => file.name == 'meta.json',
    );
    final meta = jsonDecode(utf8.decode(metaFile.readBytes()!)) as Map;
    final documents = (meta['documents'] as List).cast<Map>();
    expect(documents.map((item) => item['path']), everyElement('同名.md'));
    expect(documents.map((item) => item['archive_path']).toSet(), hasLength(2));

    final imported = await service.importFile(export.fileName, export.bytes);
    final importedRows = await (await service.index).packageDocuments(
      imported.folderId!,
    );
    expect(
      importedRows.map((row) => row['logical_path']),
      everyElement('同名.md'),
    );
    expect(
      importedRows.map((row) => row['relative_path']).toSet(),
      hasLength(2),
    );
    expect(
      await service.readLinkedResource(imported, imageLink!),
      Uint8List.fromList([1, 3, 5, 7]),
    );

    final moved = await service.moveDocument(document: first, target: target);
    expect(moved.folderId, target.id);
    expect(moved.logicalPath, '同名.md');
    folders = await service.loadFolders();
    expect(
      folders.singleWhere((folder) => folder.id == target.id).documents,
      contains(
        predicate(
          (document) => document is ReadingDocument && document.id == first.id,
        ),
      ),
    );

    final detached = await service.moveDocumentToLibrary(moved);
    expect(detached.folderId, isNot(target.id));
    expect(detached.logicalPath, '同名.md');
    expect(
      (await service.loadDocuments()).map((document) => document.id),
      contains(first.id),
    );
    expect(
      (await service.loadFolders())
          .singleWhere((folder) => folder.id == target.id)
          .documents
          .map((document) => document.id),
      isNot(contains(first.id)),
    );
    expect(
      await service.readLinkedResource(detached, imageLink),
      Uint8List.fromList([1, 3, 5, 7]),
    );
  });

  test('v3 索引升级时为旧文档补齐逻辑路径', () async {
    final root = await Directory.systemTemp.createTemp('moyue-storage-v3-');
    final databasePath = p.join(root.path, 'index.db');
    final legacy = await sqflite.openDatabase(
      databasePath,
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            name TEXT NOT NULL,
            single INTEGER NOT NULL,
            marker TEXT NOT NULL,
            relative_path TEXT NOT NULL UNIQUE,
            entry_count INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            relative_path TEXT NOT NULL UNIQUE,
            is_primary INTEGER NOT NULL DEFAULT 0,
            content_hash TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            source_url TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE resources (
            id TEXT PRIMARY KEY,
            folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
            document_id TEXT REFERENCES documents(id) ON DELETE SET NULL,
            name TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            relative_path TEXT NOT NULL UNIQUE,
            content_hash TEXT NOT NULL,
            size_bytes INTEGER NOT NULL
          )
        ''');
        final now = DateTime(2026).millisecondsSinceEpoch;
        await db.insert('folders', {
          'id': 'legacy-folder',
          'category': 'markdown',
          'name': '旧文档',
          'single': 1,
          'marker': 'imported',
          'relative_path': 'markdown/legacy-folder',
          'entry_count': 1,
          'created_at': now,
          'updated_at': now,
        });
        await db.insert('documents', {
          'id': 'legacy-document',
          'folder_id': 'legacy-folder',
          'name': '旧文档',
          'kind': 'markdown',
          'relative_path': 'markdown/legacy-folder/旧文档.md',
          'is_primary': 1,
          'content_hash': 'legacy',
          'created_at': now,
          'updated_at': now,
          'source_url': null,
        });
      },
    );
    await legacy.close();

    final index = MoyueIndexDatabase(databasePath);
    addTearDown(() async {
      await index.close();
      await root.delete(recursive: true);
    });
    final rows = await index.packageDocuments('legacy-folder');
    expect(rows.single['logical_path'], '旧文档.md');
  });

  test('空的嵌套文件夹会持久化，内部文档保留逻辑目录', () async {
    final root = await Directory.systemTemp.createTemp('moyue-storage-v5-');
    final store = _IndexedMemoryStore(root);
    var service = DocumentPackageService(store: store);
    addTearDown(() async {
      await service.close();
      await root.delete(recursive: true);
    });

    await service.createFolder('书库');
    var folder = (await service.loadFolders()).single;
    await service.createSubfolder(
      rootFolder: folder,
      parentPath: '',
      name: '第一卷',
    );
    await service.createSubfolder(
      rootFolder: folder,
      parentPath: '第一卷',
      name: '插图',
    );
    folder = (await service.loadFolders()).single;
    expect(folder.subfolderPaths, ['第一卷', '第一卷/插图']);

    final document = await service.importIntoFolder(
      folder: folder,
      fileName: '序章.md',
      bytes: Uint8List.fromList(utf8.encode('# 序章')),
      logicalDirectory: '第一卷',
    );
    expect(document.logicalPath, '第一卷/序章.md');

    await service.close();
    service = DocumentPackageService(store: store);
    folder = (await service.loadFolders()).single;
    expect(folder.subfolderPaths, ['第一卷', '第一卷/插图']);
    expect(folder.documents.single.logicalPath, '第一卷/序章.md');

    await service.deleteDocument(folder.documents.single);
    folder = (await service.loadFolders()).single;
    expect(folder.documents, isEmpty);
    expect(folder.subfolderPaths, ['第一卷', '第一卷/插图']);
  });

  test('删除子文件夹会递归删除文档和显式后代并保留同级目录', () async {
    final root = await Directory.systemTemp.createTemp('moyue-delete-subdir-');
    final store = _IndexedMemoryStore(root);
    final service = DocumentPackageService(store: store);
    addTearDown(() async {
      await service.close();
      await root.delete(recursive: true);
    });

    await service.createFolder('书库');
    var folder = (await service.loadFolders()).single;
    await service.createSubfolder(
      rootFolder: folder,
      parentPath: '',
      name: '待删除',
    );
    await service.createSubfolder(
      rootFolder: folder,
      parentPath: '待删除',
      name: '下级',
    );
    await service.createSubfolder(
      rootFolder: folder,
      parentPath: '',
      name: '保留',
    );
    folder = (await service.loadFolders()).single;
    await service.importIntoFolder(
      folder: folder,
      fileName: '第一篇.md',
      bytes: Uint8List.fromList(utf8.encode('# 第一篇')),
      logicalDirectory: '待删除',
    );
    await service.importIntoFolder(
      folder: folder,
      fileName: '第二篇.md',
      bytes: Uint8List.fromList(utf8.encode('# 第二篇')),
      logicalDirectory: '待删除/下级',
    );
    await service.importIntoFolder(
      folder: folder,
      fileName: '保留.md',
      bytes: Uint8List.fromList(utf8.encode('# 保留')),
      logicalDirectory: '保留',
    );
    folder = (await service.loadFolders()).single;

    await service.deleteSubfolder(rootFolder: folder, logicalPath: '待删除');

    folder = (await service.loadFolders()).single;
    expect(folder.subfolderPaths, ['保留']);
    expect(folder.documents.map((document) => document.logicalPath), [
      '保留/保留.md',
    ]);
    expect(store.files.keys.where((path) => path.contains('第一篇.md')), isEmpty);
    expect(store.files.keys.where((path) => path.contains('第二篇.md')), isEmpty);
  });

  test('同一根文件夹内移动整棵子目录会更新逻辑路径并拒绝移入后代', () async {
    final root = await Directory.systemTemp.createTemp('moyue-move-subdir-');
    final store = _IndexedMemoryStore(root);
    final service = DocumentPackageService(store: store);
    addTearDown(() async {
      await service.close();
      await root.delete(recursive: true);
    });

    await service.createFolder('书库');
    var folder = (await service.loadFolders()).single;
    await service.createSubfolder(
      rootFolder: folder,
      parentPath: '',
      name: '甲',
    );
    await service.createSubfolder(
      rootFolder: folder,
      parentPath: '甲',
      name: '下级',
    );
    await service.createSubfolder(
      rootFolder: folder,
      parentPath: '',
      name: '乙',
    );
    folder = (await service.loadFolders()).single;
    var document = await service.importIntoFolder(
      folder: folder,
      fileName: '正文.md',
      bytes: Uint8List.fromList(utf8.encode('# 正文')),
      logicalDirectory: '甲/下级',
    );
    final originalPhysicalPath = document.relativePath;
    final imageLink = await service.saveImageResource(
      document: document,
      fileName: '图.png',
      bytes: Uint8List.fromList([2, 4, 6, 8]),
    );
    document = await service.saveMarkdown(
      title: document.title,
      content: '# 正文\n\n![]($imageLink)',
      existing: document,
    );
    folder = (await service.loadFolders()).single;

    await expectLater(
      service.moveSubfolder(
        sourceRoot: folder,
        logicalPath: '甲',
        targetRoot: folder,
        targetParentPath: '甲/下级',
      ),
      throwsA(isA<FormatException>()),
    );

    final movedPath = await service.moveSubfolder(
      sourceRoot: folder,
      logicalPath: '甲',
      targetRoot: folder,
      targetParentPath: '乙',
    );
    expect(movedPath, '乙/甲');
    folder = (await service.loadFolders()).single;
    expect(folder.subfolderPaths, ['乙', '乙/甲', '乙/甲/下级']);
    final moved = folder.documents.single;
    expect(moved.logicalPath, '乙/甲/下级/正文.md');
    expect(moved.relativePath, originalPhysicalPath);
    expect(
      await service.readLinkedResource(moved, imageLink!),
      Uint8List.fromList([2, 4, 6, 8]),
    );
  });

  test('跨根移动子目录会保留空目录和图片资源并为同名目标自动改名', () async {
    final root = await Directory.systemTemp.createTemp(
      'moyue-move-subdir-cross-root-',
    );
    final store = _IndexedMemoryStore(root);
    final service = DocumentPackageService(store: store);
    addTearDown(() async {
      await service.close();
      await root.delete(recursive: true);
    });

    await service.createFolder('来源');
    await service.createFolder('目标');
    var folders = await service.loadFolders();
    var source = folders.singleWhere((folder) => folder.name == '来源');
    var target = folders.singleWhere((folder) => folder.name == '目标');
    await service.createSubfolder(
      rootFolder: source,
      parentPath: '',
      name: '章节',
    );
    await service.createSubfolder(
      rootFolder: source,
      parentPath: '章节',
      name: '空目录',
    );
    await service.createSubfolder(
      rootFolder: target,
      parentPath: '',
      name: '章节',
    );
    folders = await service.loadFolders();
    source = folders.singleWhere((folder) => folder.id == source.id);
    target = folders.singleWhere((folder) => folder.id == target.id);
    var document = await service.importIntoFolder(
      folder: source,
      fileName: '正文.md',
      bytes: Uint8List.fromList(utf8.encode('# 正文')),
      logicalDirectory: '章节',
    );
    final imageLink = await service.saveImageResource(
      document: document,
      fileName: '封面.png',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );
    document = await service.saveMarkdown(
      title: document.title,
      content: '# 正文\n\n![]($imageLink)',
      existing: document,
    );

    final movedPath = await service.moveSubfolder(
      sourceRoot: source,
      logicalPath: '章节',
      targetRoot: target,
    );
    expect(movedPath, '章节 (2)');
    folders = await service.loadFolders();
    source = folders.singleWhere((folder) => folder.id == source.id);
    target = folders.singleWhere((folder) => folder.id == target.id);
    expect(source.documents, isEmpty);
    expect(source.subfolderPaths, isEmpty);
    expect(target.subfolderPaths, ['章节', '章节 (2)', '章节 (2)/空目录']);
    final moved = target.documents.single;
    expect(moved.folderId, target.id);
    expect(moved.logicalPath, '章节 (2)/正文.md');
    expect(moved.relativePath, startsWith('markdown/${target.id}/'));
    final movedResources = await (await service.index).packageResources(
      target.id,
    );
    expect(movedResources, isNotEmpty);
    expect(
      movedResources,
      everyElement(
        predicate<Map<String, Object?>>(
          (row) =>
              row['folder_id'] == target.id &&
              (row['relative_path']! as String).startsWith(
                'markdown/${target.id}/',
              ),
        ),
      ),
    );
    expect(
      await service.readLinkedResource(moved, imageLink!),
      Uint8List.fromList([1, 2, 3, 4]),
    );
  });

  test('ZIP 文档包可导入现有文件夹并保留包内目录与资源', () async {
    final root = await Directory.systemTemp.createTemp('moyue-folder-zip-');
    final store = _IndexedMemoryStore(root);
    final service = DocumentPackageService(store: store);
    addTearDown(() async {
      await service.close();
      await root.delete(recursive: true);
    });

    await service.createFolder('目标');
    final target = (await service.loadFolders()).single;
    final archive = Archive()
      ..addFile(ArchiveFile.string('开篇.md', '# 开篇'))
      ..addFile(
        ArchiveFile.string('章节/正文.html', '<h1>正文</h1><img src="插图.png">'),
      )
      ..addFile(ArchiveFile('章节/插图.png', 4, [1, 2, 3, 4]));

    final moved = await service.importPackageIntoFolder(
      folder: target,
      fileName: '文档包.zip',
      bytes: Uint8List.fromList(ZipEncoder().encodeBytes(archive)),
      logicalDirectory: '已导入',
    );

    expect(moved, hasLength(2));
    expect(moved.map((document) => document.logicalPath).toSet(), {
      '已导入/开篇.md',
      '已导入/章节/正文.html',
    });
    final html = moved.singleWhere(
      (document) => document.kind == DocumentKind.html,
    );
    final movedImagePath = p.posix.join(
      p.posix.dirname(html.relativePath!),
      '插图.png',
    );
    expect(store.files.keys, contains(movedImagePath));
    expect(
      await service.readLinkedResource(html, '插图.png'),
      Uint8List.fromList([1, 2, 3, 4]),
    );
    final folders = await service.loadFolders();
    expect(folders, hasLength(1));
    expect(folders.single.documents, hasLength(2));
  });
}

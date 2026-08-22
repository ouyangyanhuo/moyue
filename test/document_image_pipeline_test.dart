import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/document_package_service.dart';
import 'package:moyue_application/services/storage/package_file_store_base.dart';

/// 内存版存储，模拟应用数据目录。
class _MemoryStore implements PackageFileStore {
  final files = <String, Uint8List>{};

  @override
  Future<String> databasePath() async => 'memory://moyue_index.db';

  @override
  Future<void> createFolder(String relativePath) async {
    files['$relativePath/'] = Uint8List(0);
  }

  @override
  Future<void> writeFiles(Map<String, Uint8List> newFiles) async =>
      files.addAll(newFiles);

  @override
  Future<Uint8List> readBytes(String relativePath) async {
    final value = files[relativePath];
    if (value == null) throw StateError('missing: $relativePath');
    return value;
  }

  @override
  Future<String> readText(String relativePath) async =>
      String.fromCharCodes(await readBytes(relativePath));

  @override
  Future<void> deleteFile(String relativePath) async => files.remove(relativePath);

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
        .toList()
      ..sort();
  }
}

ReadingDocument _doc(
  String id,
  String relativePath, {
  String content = '',
}) => ReadingDocument(
  id: id,
  title: id,
  content: content,
  kind: DocumentKind.markdown,
  updatedAt: DateTime(2026),
  folderId: 'f1',
  filePath: relativePath,
  relativePath: relativePath,
);

void main() {
  test('saveImageResource 写入文档旁 images/ 目录并返回相对链接', () async {
    final store = _MemoryStore();
    final service = DocumentPackageService(store: store);
    final document = _doc('d1', 'markdown/f1/inner/note.md');

    final link = await service.saveImageResource(
      document: document,
      fileName: '我的 截图.PNG',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(link, isNotNull);
    expect(link!.startsWith('images/img_'), isTrue);
    expect(link.endsWith('.png'), isTrue);
    // 物理位置 = 文档所在目录/images/<link 的文件名>
    expect(
      store.files.keys.where((path) => path.contains('/images/')).single,
      'markdown/f1/inner/$link',
    );
  });

  test('saveImageResource 对缺少目录信息的文档返回 null', () async {
    final service = DocumentPackageService(store: _MemoryStore());
    final legacy = ReadingDocument(
      id: 'legacy',
      title: '旧文档',
      content: '',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    final link = await service.saveImageResource(
      document: legacy,
      fileName: 'a.png',
      bytes: Uint8List(0),
    );
    expect(link, isNull);
  });

  test('cleanupUnreferencedImages 删除孤儿图片并保留被引用图片', () async {
    final store = _MemoryStore()
      ..files['markdown/f1/images/a.png'] = Uint8List.fromList([1])
      ..files['markdown/f1/images/orphan.png'] = Uint8List.fromList([2]);
    final document = _doc(
      'd1',
      'markdown/f1/note.md',
      content: '# 正文\n![a](images/a.png)',
    );
    final service = DocumentPackageService(
      store: store,
      documentsLoader: () async => [document],
    );

    final deleted = await service.cleanupUnreferencedImages(document);

    expect(deleted, 1);
    expect(store.files.containsKey('markdown/f1/images/a.png'), isTrue);
    expect(store.files.containsKey('markdown/f1/images/orphan.png'), isFalse);
  });

  test('pendingContent 保护未落盘的新插入图片不被清理', () async {
    final store = _MemoryStore()
      ..files['markdown/f1/images/new.png'] = Uint8List.fromList([9]);
    // 磁盘正文还没有图片链接（尚未保存）。
    final document = _doc('d1', 'markdown/f1/note.md', content: '# 正文');
    final service = DocumentPackageService(
      store: store,
      documentsLoader: () async => [document],
    );

    final pending = '# 正文\n![新图](images/new.png)';
    final deletedWithPending = await service.cleanupUnreferencedImages(
      document,
      pendingContent: pending,
    );
    expect(deletedWithPending, 0);
    expect(store.files.containsKey('markdown/f1/images/new.png'), isTrue);

    // 不带快照时才会按磁盘内容判定为孤儿（对应旧行为的误删场景）。
    final deletedWithout = await service.cleanupUnreferencedImages(document);
    expect(deletedWithout, 1);
  });

  test('清理只作用于当前文档目录，不影响同包其他目录的图片', () async {
    final store = _MemoryStore()
      ..files['markdown/f1/sub/images/x.png'] = Uint8List(0)
      ..files['markdown/f1/root-images/y.png'] = Uint8List(0);
    final document = _doc('d1', 'markdown/f1/root.md');
    final service = DocumentPackageService(
      store: store,
      documentsLoader: () async => [document],
    );

    await service.cleanupUnreferencedImages(document);

    expect(store.files.containsKey('markdown/f1/sub/images/x.png'), isTrue);
  });
}

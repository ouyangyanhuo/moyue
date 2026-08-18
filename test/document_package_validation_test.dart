import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/services/document_package_service.dart';
import 'package:moyue_application/models/library_folder.dart';

void main() {
  test('ZIP 或 moyue 至少需要两个实际文件', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('index.html', '<h1>Hello</h1>'));
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));

    await expectLater(
      DocumentPackageService().importFile('single.zip', bytes),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('至少需要包含 2 个文件'),
        ),
      ),
    );
  });

  test('压缩包会拒绝白名单之外的文件', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('index.html', '<h1>Hello</h1>'))
      ..addFile(ArchiveFile.string('payload.exe', 'not executable'));
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));

    await expectLater(
      DocumentPackageService().importFile('unsafe.zip', bytes),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('payload.exe'),
        ),
      ),
    );
  });

  test('外层文件扩展名只允许 zip、moyue、md 和 html', () async {
    await expectLater(
      DocumentPackageService().importFile(
        'legacy.markdown',
        Uint8List.fromList([35, 32, 84]),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('文件夹内明确拒绝 ZIP 和 moyue 文档包', () async {
    await expectLater(
      DocumentPackageService().importIntoFolder(
        folder: LibraryFolder(
          id: 'folder',
          name: '文件夹',
          documents: const [],
          updatedAt: DateTime(2026),
        ),
        fileName: 'package.zip',
        bytes: Uint8List(0),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

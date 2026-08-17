import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/services/text_decoder.dart';

void main() {
  test('导入文本可识别 UTF-8 BOM', () {
    final bytes = Uint8List.fromList([
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode('# 中文标题'),
    ]);
    expect(decodeImportedText(bytes), '# 中文标题');
  });

  test('导入文本在 UTF-8 无效时回退到 GBK', () {
    final bytes = Uint8List.fromList(gbk.encode('# 中文标题\n正文内容'));
    expect(decodeImportedText(bytes), '# 中文标题\n正文内容');
  });

  test('旧式 ZIP 的 GBK 中文文件名可以恢复', () {
    final encodedName = gbk.encode('中文文档.md');
    final archiveName = String.fromCharCodes(encodedName);
    expect(decodeArchiveFileName(archiveName), '中文文档.md');
  });
}

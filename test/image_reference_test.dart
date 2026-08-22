import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/services/document_package_service.dart';

void main() {
  group('DocumentPackageService.extractImageReferences', () {
    test('提取 Markdown 图片链接', () {
      final refs = DocumentPackageService.extractImageReferences(
        '前文\n![截图](images/img_1.png)\n![带空格]( images/pic%202.webp )',
      );
      expect(refs, contains('images/img_1.png'));
      expect(refs, contains('images/pic 2.webp'));
      expect(refs.length, 2);
    });

    test('提取 HTML img 标签的 src', () {
      final refs = DocumentPackageService.extractImageReferences(
        '<p>图 <IMG SRC="images/a.jpg"></p><img src=\'images/b.png\'>',
      );
      expect(refs, {'images/a.jpg', 'images/b.png'});
    });

    test('忽略网络图片与 data URI', () {
      final refs = DocumentPackageService.extractImageReferences(
        '![外链](https://example.com/a.png) ![内联](data:image/png;base64,AAAA) '
        '![绝对](/root/x.png)',
      );
      expect(refs, isEmpty);
    });

    test('归一化 ./ 前缀与查询参数', () {
      final refs = DocumentPackageService.extractImageReferences(
        '![x](./images/x.png?v=1)',
      );
      expect(refs, {'images/x.png'});
    });
  });
}

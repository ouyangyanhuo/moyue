import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/services/debug_service.dart';

void main() {
  group('DebugService.parseLockContent', () {
    test('标准内容 debug = true 判定为开启', () {
      expect(DebugService.parseLockContent('debug = true'), isTrue);
    });

    test('忽略大小写与空白', () {
      expect(DebugService.parseLockContent('DEBUG=TRUE'), isTrue);
      expect(DebugService.parseLockContent('  debug   =   true  \n'), isTrue);
      expect(DebugService.parseLockContent('Debug = True\r\n'), isTrue);
    });

    test('多行文件中任一行命中即开启', () {
      expect(
        DebugService.parseLockContent('# moyue debug lock\ndebug = true\n'),
        isTrue,
      );
    });

    test('false 或其他内容判定为关闭', () {
      expect(DebugService.parseLockContent('debug = false'), isFalse);
      expect(DebugService.parseLockContent('debug=true1'), isFalse);
      expect(DebugService.parseLockContent(''), isFalse);
      expect(DebugService.parseLockContent('garbage content'), isFalse);
    });
  });
}

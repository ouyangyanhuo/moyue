// 这是一个基础的 Flutter 组件测试。
//
// 如需在测试中与组件交互，请使用 flutter_test 软件包中的 WidgetTester 工具。
// 例如，可以发送点击和滚动手势。也可以使用 WidgetTester 在组件树中查找子组件、
// 读取文本，并验证组件属性值是否正确。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moyue_application/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 构建应用程序并触发一帧。
    await tester.pumpWidget(const MyApp());

    // 验证计数器从 0 开始。
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // 点击“+”图标并触发一帧。
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // 验证计数器已递增。
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

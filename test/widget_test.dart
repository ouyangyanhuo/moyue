import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/app/moyue_app.dart';

void main() {
  testWidgets('核心 Dock 可在阅读、编辑和订阅页面间切换', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MoyueApp());
    await tester.pumpAndSettle();

    expect(find.text('阅读'), findsWidgets);
    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('设计随笔'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byIcon(Icons.edit_outlined).last));
    await tester.pumpAndSettle();
    expect(find.text('所有更改均已保存'), findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.byIcon(Icons.rss_feed_outlined).last),
    );
    await tester.pumpAndSettle();
    expect(find.text('订阅源'), findsOneWidget);
    expect(find.text('少数派'), findsWidgets);
  });

  testWidgets('圆形搜索按钮可以展开并过滤文档', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MoyueApp());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('搜索').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expanded-search')), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'HTML');
    await tester.pumpAndSettle();
    expect(find.text('HTML 原生阅读示例'), findsOneWidget);
    expect(find.text('设计随笔'), findsNothing);
  });
}

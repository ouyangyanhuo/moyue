import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/app/moyue_app.dart';
import 'package:moyue_application/features/reader/library_page.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/rss/rss_page.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/models/reading_document.dart';

void main() {
  testWidgets('核心 Dock 仅包含阅读、订阅和设置，并展示空状态', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MoyueApp());
    await _pumpIo(tester);

    expect(find.text('阅读'), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    await tester.tapAt(
      tester.getCenter(find.byIcon(Icons.rss_feed_outlined).last),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('订阅源'), findsOneWidget);
    expect(find.text('还没有订阅'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byIcon(Icons.tune_outlined).last));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('圆形搜索按钮可以展开并过滤文档', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LibraryPage(documents: [], loading: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('还没有文档'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('搜索').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('expanded-search')), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '不存在的文档');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('没有匹配的文档'), findsOneWidget);
  });

  testWidgets('Markdown 草稿可通过 RestorationManager 恢复', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(
          restorationScopeId: 'test_app',
          home: MarkdownEditorPage(),
        ),
      ),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '恢复测试');
    await tester.enterText(fields.at(1), '不会因系统回收而丢失的正文');
    await tester.pump();

    await tester.restartAndRestore();

    expect(find.text('恢复测试'), findsOneWidget);
    expect(find.text('不会因系统回收而丢失的正文'), findsOneWidget);
  });

  testWidgets('长按文档进入多选删除模式并隐藏搜索与新增', (tester) async {
    final documents = [
      ReadingDocument(
        id: 'one',
        title: '第一篇',
        content: '# 第一篇',
        kind: DocumentKind.markdown,
        updatedAt: DateTime(2026),
      ),
      ReadingDocument(
        id: 'two',
        title: '第二篇',
        content: '# 第二篇',
        kind: DocumentKind.markdown,
        updatedAt: DateTime(2026),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryPage(documents: documents, loading: false)),
      ),
    );

    await tester.longPress(find.text('第一篇'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('已选择 1 项'), findsOneWidget);
    expect(find.byKey(const ValueKey('round-search-button')), findsNothing);
    expect(find.bySemanticsLabel('新建或导入'), findsNothing);
    expect(find.bySemanticsLabel('删除所选文档'), findsOneWidget);

    await tester.tap(find.text('第二篇'));
    await tester.pump();
    expect(find.text('已选择 2 项'), findsOneWidget);
  });

  testWidgets('点击新增 RSS 可稳定打开订阅表单', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RssPage())));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.bySemanticsLabel('添加订阅').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('添加 RSS 订阅'), findsWidgets);
    expect(find.text('订阅地址'), findsOneWidget);
    expect(find.text('添加订阅'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/app/moyue_app.dart';
import 'package:moyue_application/features/reader/library_page.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/rss/rss_page.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/widgets/scrolling_title.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';

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
    expect(find.byType(GlassSlider), findsOneWidget);
    expect(find.byType(GlassSwitch), findsNWidgets(2));
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Switch), findsNothing);

    final contrastSlider = tester.widget<GlassSlider>(find.byType(GlassSlider));
    expect(contrastSlider.thumbRadius, 15);
    expect(contrastSlider.trackHeight, 4);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('contrast-slider-touch-area')))
          .height,
      72,
    );
    expect(find.textContaining('Liquid 透明度'), findsNothing);
    final dock = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(dock.settings?.glassColor.a, 0);

    final glassTheme = tester.widget<GlassTheme>(find.byType(GlassTheme));
    expect(glassTheme.data.light.settings?.fresnelStrength, 0);
    expect(glassTheme.data.dark.settings?.fresnelStrength, 0);
    expect(glassTheme.data.light.settings?.edgeAbsorption, 0.06);
    expect(glassTheme.data.dark.settings?.edgeAbsorption, 0.09);
    for (final button in tester.widgetList<MoyueGlassIconButton>(
      find.byType(MoyueGlassIconButton),
    )) {
      expect(button.settings?.shadowElevation, 0);
      expect(button.settings?.shadow, isNotEmpty);
      expect(button.settings?.shadow?.single.spreadRadius, -3);
      expect(button.settings?.edgeAbsorption, 0.06);
      expect(button.settings?.thickness, 20);
      expect(button.settings?.chromaticAberration, 0.025);
      expect(button.settings?.refractiveIndex, 1.32);
    }
    for (final button in tester.widgetList<GlassButton>(
      find.descendant(
        of: find.byType(MoyueGlassIconButton),
        matching: find.byType(GlassButton),
      ),
    )) {
      // 所有玻璃圆钮都必须保持 premium，并由 FloatingPageShell /
      // FloatingDocumentHeader 固定在滚动视口之外的浮层里，
      // 保证按压位移效果与阅读页完全一致。
      expect(button.quality, GlassQuality.premium);
      expect(button.glowColor, Colors.transparent);
      expect(button.glowOpacity, 0);
      expect(button.ambientBaseLight, 0);
      expect(button.anchorStretch, isTrue);
      expect(button.stretch, 0.46);
      expect(button.settings?.shadow, isEmpty);
    }
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
    final searchField = tester.widget<GlassTextField>(
      find.descendant(
        of: find.byKey(const ValueKey('expanded-search')),
        matching: find.byType(GlassTextField),
      ),
    );
    expect(searchField.quality, GlassQuality.standard);
    expect(searchField.interactionBehavior, GlassInteractionBehavior.scaleOnly);
    expect(find.bySemanticsLabel('关闭搜索'), findsOneWidget);

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

    expect(find.text('恢复测试'), findsWidgets);
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

  testWidgets('一级页面第一次返回会提示再次返回', (tester) async {
    await tester.pumpWidget(const MoyueApp());
    await _pumpIo(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('再按一次返回桌面'), findsOneWidget);
  });

  testWidgets('编辑工具栏只在输入法稳定显示后贴在其上方', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: MarkdownEditorPage()),
      ),
    );
    await tester.pump();
    final canvasHeight = tester
        .getSize(find.byKey(const ValueKey('edit')))
        .height;
    expect(tester.getCenter(find.bySemanticsLabel('返回')).dy, lessThan(80));
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('editor-writing-surface')))
          .dy,
      920,
    );
    expect(find.byIcon(Icons.format_bold_rounded), findsNothing);

    await tester.tap(find.byType(TextField).last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byIcon(Icons.format_bold_rounded), findsNothing);
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump();

    expect(find.byIcon(Icons.format_bold_rounded), findsOneWidget);
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('keyboard-format-dock')))
          .dy,
      622,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('edit'))).height,
      canvasHeight,
    );
  });

  testWidgets('新建菜单提供指定选项及导入格式说明', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LibraryPage(documents: [], loading: false)),
      ),
    );
    await tester.tap(find.bySemanticsLabel('新建或导入'));
    await tester.pumpAndSettle();

    expect(find.text('新建 markdown'), findsOneWidget);
    expect(find.text('新建文件夹'), findsOneWidget);
    expect(find.text('导入文件或文档包'), findsOneWidget);

    await tester.tap(find.byTooltip('支持的文件格式'));
    await tester.pumpAndSettle();
    expect(find.textContaining('文档数量大于 2 时'), findsOneWidget);
  });

  testWidgets('创建文件夹关闭对话框时不会提前释放输入状态', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LibraryPage(documents: [], loading: false)),
      ),
    );
    await tester.tap(find.bySemanticsLabel('新建或导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '安全创建');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('文件夹内文档支持长按多选，标题支持重命名入口', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final folder = LibraryFolder(
      id: 'folder-1',
      name: '资料夹',
      updatedAt: DateTime(2026),
      documents: [
        ReadingDocument(
          id: 'inside-1',
          title: '内部文档',
          content: '# 正文',
          kind: DocumentKind.markdown,
          updatedAt: DateTime(2026),
          folderId: 'folder-1',
          relativePath: 'markdown/folder-1/inside.md',
        ),
      ],
    );
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(
          home: Scaffold(
            body: LibraryPage(
              documents: const [],
              folders: [folder],
              loading: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('资料夹'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('新建或导入文档'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('新建或导入文档'));
    await tester.pumpAndSettle();
    expect(find.text('新建 Markdown'), findsOneWidget);
    expect(find.text('导入 Markdown 或 HTML'), findsOneWidget);
    await tester.tap(find.text('新建 Markdown'));
    await tester.pumpAndSettle();
    expect(find.text('新建 Markdown'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('资料夹'));
    await tester.pumpAndSettle();
    expect(find.text('修改文件夹名称'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('内部文档'));
    await tester.pump();
    expect(find.bySemanticsLabel('删除所选文档'), findsOneWidget);
  });

  testWidgets('阅读器正文延伸到浮动上下 Dock 后方并移除墨模式', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final document = ReadingDocument(
      id: 'reader',
      title: '阅读测试',
      content: '# 正文内容',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderDetailPage(document: document)),
    );
    await tester.pump();

    expect(find.text('正文内容'), findsOneWidget);
    final initialBodyTop = tester.getTopLeft(find.text('正文内容')).dy;
    expect(initialBodyTop, greaterThanOrEqualTo(72));
    await tester.drag(find.text('正文内容'), const Offset(0, -90));
    await tester.pump();
    expect(tester.getTopLeft(find.text('正文内容')).dy, lessThan(initialBodyTop));
    expect(find.bySemanticsLabel('返回'), findsOneWidget);
    expect(find.bySemanticsLabel('编辑 Markdown'), findsOneWidget);
    expect(tester.getCenter(find.bySemanticsLabel('返回')).dy, lessThan(80));
    // 浮动头部的按钮固定在滚动内容之上（不在视口内），保留 premium 渲染。
    final floatingQualities = tester
        .widgetList<GlassButton>(
          find.descendant(
            of: find.byType(FloatingDocumentHeader),
            matching: find.byType(GlassButton),
          ),
        )
        .map((button) => button.quality);
    expect(floatingQualities, everyElement(GlassQuality.premium));
    expect(find.text('墨模式'), findsNothing);
    expect(find.byIcon(Icons.water_drop_outlined), findsNothing);
    expect(
      tester.getCenter(find.byIcon(Icons.format_list_bulleted_rounded)).dy,
      greaterThan(820),
    );
  });

  testWidgets('首页长文件名仅在 hover 或按住时滚动', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 90,
              child: ScrollingTitle('这是一个明显超出容器边界的超长文件名称.md'),
            ),
          ),
        ),
      ),
    );
    final text = find.text('这是一个明显超出容器边界的超长文件名称.md');
    final before = tester.getTopLeft(text).dx;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(300, 300));
    await mouse.moveTo(const Offset(20, 10));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    final after = tester.getTopLeft(text).dx;
    await mouse.removePointer();

    expect(after, lessThan(before));
  });

  testWidgets('RSS 订阅源使用长按多选删除模式', (tester) async {
    final source = FeedSource(
      id: 'rss-select',
      title: '测试订阅源',
      url: Uri.parse('https://example.com/rss.xml'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RssPage(initialSources: [source])),
      ),
    );
    await tester.pump();
    await tester.longPress(find.text('测试订阅源'));
    await tester.pump();

    expect(find.text('已选择 1 项'), findsOneWidget);
    expect(find.bySemanticsLabel('删除所选订阅'), findsOneWidget);
    expect(find.bySemanticsLabel('添加订阅'), findsNothing);
  });

  testWidgets('设置页墨模式开关保持禁用', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    final inkSwitch = tester.widget<GlassSwitch>(
      find.byType(GlassSwitch).first,
    );
    expect(inkSwitch.value, isFalse);
    expect(inkSwitch.width, 58);
    expect(inkSwitch.height, 26);
    expect(
      tester.getSize(find.byKey(const ValueKey('墨模式-switch-touch-area'))),
      const Size(104, 56),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('墨模式-switch-row-touch-area')))
          .height,
      80,
    );
    final disabledPointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(GlassSwitch).first,
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(disabledPointer.ignoring, isTrue);
    expect(find.text('暂未开放'), findsOneWidget);
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

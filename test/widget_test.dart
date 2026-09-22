import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/app/moyue_app.dart';
import 'package:moyue_application/features/reader/library_page.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/features/reader/native_html_view.dart';
import 'package:moyue_application/features/reader/webview_html_view.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/rss/rss_page.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_markdown_style.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/system_share_service.dart';
import 'package:moyue_application/widgets/scrolling_title.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';
import 'package:share_plus/share_plus.dart'
    show ShareParams, ShareResult, ShareResultStatus;

void main() {
  test('编辑器可恢复路由会保留文档逻辑路径', () {
    final document = ReadingDocument(
      id: 'nested-document',
      title: '章节',
      content: '# 章节',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
      folderId: 'folder',
      relativePath: 'markdown/folder/.documents/nested-document/章节.md',
      logicalPath: '第一卷/章节.md',
    );

    expect(markdownEditorArguments(document)?['logicalPath'], '第一卷/章节.md');
  });

  testWidgets('核心 Dock 仅包含阅读、订阅和设置，并展示空状态', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MoyueApp());
    await _pumpIo(tester);

    expect(find.text('Reading'), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    await tester.tapAt(
      tester.getCenter(find.byIcon(Icons.rss_feed_outlined).last),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('No subscriptions yet'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byIcon(Icons.tune_outlined).last));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Settings'), findsWidgets);
    // 对比度滑杆已随无效功能移除；设置页不再使用任何 Material 滑杆。
    expect(find.byType(GlassSlider), findsNothing);
    expect(find.byType(GlassSwitch), findsNWidgets(4));
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Switch), findsNothing);

    expect(find.textContaining('Liquid 透明度'), findsNothing);
    final dock = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(dock.quality, GlassQuality.premium);
    expect(dock.platformViewBackdrop, isFalse);
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

  testWidgets('首页滚动视口延伸到状态栏，初始标题仍避让系统图标', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(const MoyueApp());
    await _pumpIo(tester);

    await tester.tapAt(tester.getCenter(find.byIcon(Icons.tune_outlined).last));
    await tester.pump(const Duration(milliseconds: 500));
    final scroll = find.byKey(const PageStorageKey('settings-scroll'));
    final title = find.descendant(of: scroll, matching: find.text('Settings'));
    expect(tester.getTopLeft(scroll).dy, 0);
    expect(tester.getTopLeft(title).dy, greaterThanOrEqualTo(32));

    await tester.drag(scroll, const Offset(0, -160));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.getTopLeft(title).dy, lessThan(32));
  });

  testWidgets('首页 Dock 边缘渐变会随系统亮暗模式切换', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(MoyueApp(display: display));
    await _pumpIo(tester);

    LinearGradient gradient() =>
        (tester
                        .widget<DecoratedBox>(
                          find.byKey(const ValueKey('home-dock-edge-fade')),
                        )
                        .decoration
                    as BoxDecoration)
                .gradient!
            as LinearGradient;
    expect(
      ThemeData.estimateBrightnessForColor(gradient().colors.last),
      Brightness.dark,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    tester.platformDispatcher.onPlatformBrightnessChanged?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      ThemeData.estimateBrightnessForColor(gradient().colors.last),
      Brightness.light,
    );
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

  testWidgets('设置页 Dock 的附加按钮会打开作者关于信息', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MoyueApp());
    await _pumpIo(tester);
    await tester.tapAt(tester.getCenter(find.byIcon(Icons.tune_outlined).last));
    await tester.pump(const Duration(milliseconds: 350));

    final about = find.bySemanticsLabel('About Moyue');
    expect(about, findsOneWidget);
    await tester.tap(about);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Author'), findsOneWidget);
    expect(find.text('Magneto'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
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

  testWidgets('首页长按文档后直接显示分享与删除并隐藏搜索新增', (tester) async {
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
    expect(find.bySemanticsLabel('分享所选项目'), findsOneWidget);
    expect(find.bySemanticsLabel('删除所选项目'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);

    await tester.tap(find.text('第二篇'));
    await tester.pump();
    expect(find.text('已选择 2 项'), findsOneWidget);

    expect(find.bySemanticsLabel('分享所选项目'), findsOneWidget);
    expect(find.bySemanticsLabel('删除所选项目'), findsOneWidget);
  });

  testWidgets('点击新增 RSS 可稳定打开订阅表单', (tester) async {
    final key = GlobalKey<RssPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RssPage(key: key)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    unawaited(key.currentState!.showAddSource());
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

    expect(find.text('Press back again to exit'), findsOneWidget);
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
    expect(
      tester.getCenter(find.bySemanticsLabel('返回')).dy,
      lessThanOrEqualTo(80),
    );
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
    final formatBar = tester.widget<GlassButtonGroup>(
      find.byType(GlassButtonGroup),
    );
    expect(formatBar.quality, GlassQuality.premium);
    expect(formatBar.useOwnLayer, isTrue);

    // 格式工具只应操作正文，编辑标题时立即隐藏。
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(find.byIcon(Icons.format_bold_rounded), findsNothing);
    await tester.tap(find.byType(TextField).last);
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump();
    expect(find.byIcon(Icons.format_bold_rounded), findsOneWidget);

    final bodyField = tester.widget<TextField>(find.byType(TextField).last);
    expect(bodyField.scrollController, isNotNull);
    expect(
      (bodyField.decoration!.contentPadding! as EdgeInsets).bottom,
      greaterThan(300),
    );
    expect(
      (bodyField.decoration!.contentPadding! as EdgeInsets).bottom,
      lessThan(340),
      reason: '正文只为键盘留白，不应再为浮动工具栏挖出遮挡区',
    );
    await tester.enterText(
      find.byType(TextField).last,
      List<String>.generate(60, (index) => '第 $index 行正文').join('\n'),
    );
    await tester.pump();
    final bodyScrollController = bodyField.scrollController!;
    expect(bodyScrollController.position.maxScrollExtent, greaterThan(0));
    bodyScrollController.jumpTo(0);
    await tester.drag(find.byType(TextField).last, const Offset(0, -160));
    await tester.pump();
    expect(bodyScrollController.offset, greaterThan(0));
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

  testWidgets('编辑工具栏格式按钮再次点击会撤销标记并保持焦点', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
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

    final bodyFinder = find.byType(TextField).last;
    await tester.tap(bodyFinder);
    await tester.enterText(bodyFinder, '正文');
    final body = tester.widget<TextField>(bodyFinder);
    body.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 2,
    );
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.format_bold_rounded));
    await tester.pump();
    expect(body.controller!.text, '**正文**');
    expect(
      body.controller!.selection,
      const TextSelection(baseOffset: 2, extentOffset: 4),
    );
    await tester.tap(find.byIcon(Icons.format_bold_rounded));
    await tester.pump();
    expect(body.controller!.text, '正文');
    expect(
      body.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );

    await tester.tap(find.byIcon(Icons.title_rounded));
    await tester.pump();
    expect(body.controller!.text, '## 正文');
    await tester.tap(find.byIcon(Icons.title_rounded));
    await tester.pump();
    expect(body.controller!.text, '正文');
    expect(body.focusNode!.hasFocus, isTrue);
  });

  testWidgets('编辑器图片导入失败使用小型通用提示且不泄露错误', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _ThrowingFilePicker();
    addTearDown(() => FilePickerPlatform.instance = originalPicker);
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final document = ReadingDocument(
      id: 'editor-image-failure',
      title: '插图测试.md',
      content: '正文',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
      folderId: 'folder',
      relativePath: 'markdown/folder/editor-image-failure.md',
    );
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(home: MarkdownEditorPage(document: document)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField).last);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.image_outlined));
    await tester.pumpAndSettle();

    expect(find.text('图片导入失败'), findsOneWidget);
    expect(find.textContaining('private/storage/path'), findsNothing);
    final messageRect = tester.getRect(
      find.byKey(const ValueKey('moyue-message-content')),
    );
    expect(messageRect.width, lessThanOrEqualTo(280));
    expect(messageRect.height, lessThan(48));
  });

  testWidgets('新建菜单提供指定选项及导入格式说明', (tester) async {
    final key = GlobalKey<LibraryPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryPage(key: key, documents: const [], loading: false),
        ),
      ),
    );
    key.currentState!.showAddMenu();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('新建 Markdown'),
      ),
      findsOneWidget,
    );
    expect(find.text('新建文件夹'), findsOneWidget);
    expect(find.text('导入文件或文档包'), findsOneWidget);

    await tester.tap(find.byTooltip('支持的文件格式'));
    await tester.pumpAndSettle();
    expect(find.textContaining('.htm'), findsOneWidget);
    expect(find.textContaining('文档数量大于 2 时'), findsOneWidget);
  });

  testWidgets('导入不支持的文件会明确提示', (tester) async {
    final originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _SelectedFilePicker(
      _MemoryPlatformFile(name: '财务报表.pdf', bytes: Uint8List(3)),
    );
    addTearDown(() => FilePickerPlatform.instance = originalPicker);
    final key = GlobalKey<LibraryPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryPage(key: key, documents: const [], loading: false),
        ),
      ),
    );

    key.currentState!.showAddMenu();
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入文件或文档包'));
    await tester.pumpAndSettle();

    expect(find.text('不支持此文件'), findsOneWidget);
    expect(find.textContaining('财务报表.pdf'), findsOneWidget);
    expect(find.textContaining('.htm'), findsOneWidget);
  });

  testWidgets('创建文件夹关闭对话框时不会提前释放输入状态', (tester) async {
    final key = GlobalKey<LibraryPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryPage(key: key, documents: const [], loading: false),
        ),
      ),
    );
    key.currentState!.showAddMenu();
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '安全创建');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('文件夹页支持递归子目录并按物理层级导航', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    ReadingDocument doc(String id, String title, String relativePath) =>
        ReadingDocument(
          id: id,
          title: title,
          content: '',
          kind: DocumentKind.markdown,
          updatedAt: DateTime(2026),
          folderId: 'folder-1',
          filePath: relativePath,
          relativePath: relativePath,
        );
    final folder = LibraryFolder(
      id: 'folder-1',
      name: '资料夹',
      updatedAt: DateTime(2026),
      documents: [
        doc('root-doc', '根文档', 'markdown/folder-1/root.md'),
        doc('deep-doc', '深层文档', 'markdown/folder-1/二级文件夹/deep.md'),
      ],
      subfolderPaths: const ['空目录'],
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

    // 包根目录：直系文档可见，深层文档收在子目录内。
    expect(find.text('根文档'), findsOneWidget);
    expect(find.text('二级文件夹'), findsOneWidget);
    expect(find.text('空目录'), findsOneWidget);
    expect(find.text('深层文档'), findsNothing);

    await tester.tap(find.text('二级文件夹'));
    await tester.pumpAndSettle();

    // 进入子目录后标题为目录名，且能看到递归文档。
    expect(find.text('深层文档'), findsOneWidget);
    expect(find.text('二级文件夹'), findsOneWidget);
    expect(find.text('根文档'), findsNothing);
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
    expect(find.text('新建文件夹'), findsOneWidget);
    expect(find.text('导入文件或文档包'), findsOneWidget);
    expect(find.byTooltip('支持的文件格式'), findsOneWidget);
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
    expect(find.bySemanticsLabel('所选项目操作'), findsOneWidget);
  });

  testWidgets('文件夹内的子文件夹可长按选择并显示删除操作', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final folder = LibraryFolder(
      id: 'nested-delete-root',
      name: '书库',
      documents: const [],
      updatedAt: DateTime(2026),
      subfolderPaths: const ['待删除'],
    );
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(
          home: LibraryPage(
            documents: const [],
            folders: [folder],
            loading: false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('书库'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('待删除'));
    await tester.pump();
    expect(find.text('已选择 1 项'), findsOneWidget);
    expect(find.bySemanticsLabel('所选项目操作'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('所选项目操作'));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('移动到…'), findsOneWidget);
    expect(find.text('分享所选项目'), findsOneWidget);
  });

  testWidgets('子文件夹使用长按拖拽且载荷可同时保留文档与目录多选', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final document = ReadingDocument(
      id: 'mixed-drag-document',
      title: '一起移动的文档',
      content: '# 正文',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
      folderId: 'mixed-drag-root',
      relativePath:
          'markdown/mixed-drag-root/.documents/mixed-drag-document/文档.md',
      logicalPath: '文档.md',
    );
    final source = LibraryFolder(
      id: 'mixed-drag-root',
      name: '混合移动',
      documents: [document],
      updatedAt: DateTime(2026),
      subfolderPaths: const ['待移动目录'],
    );
    final target = LibraryFolder(
      id: 'mixed-drag-target',
      name: '移动目标',
      documents: const [],
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(
          home: LibraryPage(
            documents: const [],
            folders: [source, target],
            loading: false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('混合移动'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('一起移动的文档'));
    await tester.pump();
    await tester.tap(find.text('待移动目录'));
    await tester.pump();

    final draggableFinder = find.ancestor(
      of: find.text('待移动目录'),
      matching: find.byWidgetPredicate(
        (widget) => widget is LongPressDraggable,
      ),
    );
    expect(draggableFinder, findsOneWidget);
    final dynamic draggable = tester.widget(draggableFinder);
    final dynamic payload = draggable.data;
    expect((payload.documents as List).map((item) => item.id), [document.id]);
    expect(payload.directories, ['待移动目录']);
  });

  testWidgets('文件夹文档开始拖动时始终提供阅读首页目标', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final folder = LibraryFolder(
      id: 'drag-source',
      name: '拖动来源',
      updatedAt: DateTime(2026),
      documents: [
        ReadingDocument(
          id: 'drag-inside',
          title: '拖出文档',
          content: '# 正文',
          kind: DocumentKind.markdown,
          updatedAt: DateTime(2026),
          folderId: 'drag-source',
          relativePath: 'markdown/drag-source/inside.md',
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
    await tester.tap(find.text('拖动来源'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('拖出文档')),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();

    expect(find.text('阅读首页'), findsOneWidget);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('文件夹目标过多时拖到更多会展开两列 Material 目标面板', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final source = LibraryFolder(
      id: 'overflow-source',
      name: '来源',
      updatedAt: DateTime(2026),
      documents: [
        ReadingDocument(
          id: 'overflow-doc',
          title: '待移动文档',
          content: '# 正文',
          kind: DocumentKind.markdown,
          updatedAt: DateTime(2026),
          folderId: 'overflow-source',
          relativePath: 'markdown/overflow-source/doc.md',
        ),
      ],
    );
    final folders = [
      source,
      for (var index = 0; index < 20; index++)
        LibraryFolder(
          id: 'destination-$index',
          name: '目标文件夹 $index',
          documents: const [],
          updatedAt: DateTime(2026),
        ),
    ];
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(
          home: LibraryPage(
            documents: const [],
            folders: folders,
            loading: false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('来源'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('待移动文档')),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveTo(tester.getCenter(find.text('更多文件夹')));
    await tester.pump(const Duration(milliseconds: 380));
    // 上一帧触发延时展开；再推进一段时间让从底部展开的动画完成。
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('拖到目标文件夹'), findsOneWidget);
    expect(find.text('目标文件夹 0'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(GlassContainer),
      ),
      findsNothing,
    );
    final targetList = find.byKey(
      const ValueKey('expanded-folder-target-grid'),
    );
    final grid = tester.widget<GridView>(targetList);
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    final sheet = find.byType(BottomSheet);
    final sheetSlide = find.ancestor(
      of: sheet,
      matching: find.byType(SlideTransition),
    );
    expect(sheetSlide, findsWidgets);
    expect(
      tester.widget<SlideTransition>(sheetSlide.first).position.value.dy,
      closeTo(0, 0.001),
    );
    expect(
      find.ancestor(of: sheet, matching: find.byType(SizeTransition)),
      findsNothing,
    );
    final homeTarget = find
        .descendant(of: sheet, matching: find.text('阅读首页'))
        .first;
    final firstFolderTarget = find
        .descendant(of: sheet, matching: find.text('目标文件夹 0'))
        .first;
    expect(
      tester.getCenter(homeTarget).dy,
      closeTo(tester.getCenter(firstFolderTarget).dy, 1),
    );
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: targetList, matching: find.byType(Scrollable)).first,
    );
    expect(scrollable.position.pixels, 0);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await gesture.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('expanded-folder-auto-scroll-target')),
      ),
    );
    await gesture.moveBy(const Offset(0, -1));
    await tester.pump(const Duration(milliseconds: 260));
    expect(scrollable.position.pixels, greaterThan(0));

    // 拖出“更多文件夹”面板后先经过短暂的边缘缓冲，再播放反向收起动画。
    await gesture.moveTo(const Offset(24, 24));
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    final exitingSlide = find.ancestor(
      of: find.byType(BottomSheet),
      matching: find.byType(SlideTransition),
    );
    final exitOffset = tester
        .widget<SlideTransition>(exitingSlide.first)
        .position
        .value
        .dy;
    expect(exitOffset, greaterThan(0));
    expect(exitOffset, lessThan(1));
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(BottomSheet),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.byType(BottomSheet), findsNothing);

    // 拖拽仍在继续时可以再次悬停展开，不会被上一次的收起计时器干扰。
    await gesture.moveTo(tester.getCenter(find.text('更多文件夹')));
    await tester.pump(const Duration(milliseconds: 380));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('拖到目标文件夹'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    await gesture.up();
    await tester.pump();
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
    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.padding.bottom, lessThan(120));
    final initialBodyTop = tester.getTopLeft(find.text('正文内容')).dy;
    expect(initialBodyTop, greaterThanOrEqualTo(72));
    expect(find.bySemanticsLabel('返回'), findsOneWidget);
    expect(find.bySemanticsLabel('编辑 Markdown'), findsOneWidget);
    expect(
      tester.getCenter(find.bySemanticsLabel('返回')).dy,
      lessThanOrEqualTo(80),
    );
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
    // 标题胶囊同样必须走 premium 折射管线，而不是 standard 高斯模糊。
    final pillQualities = tester
        .widgetList<GlassContainer>(
          find.descendant(
            of: find.byType(FloatingDocumentHeader),
            matching: find.byType(GlassContainer),
          ),
        )
        .map((container) => container.quality);
    expect(pillQualities, everyElement(GlassQuality.premium));
    expect(find.text('墨模式'), findsNothing);
    expect(find.byIcon(Icons.water_drop_outlined), findsNothing);
    expect(
      tester.getCenter(find.byIcon(Icons.format_list_bulleted_rounded)).dy,
      greaterThan(820),
    );
  });

  testWidgets('WebView 浮动标题栏可按页面背景切换前景色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FloatingDocumentHeader(
            title: '白色网页',
            onBack: () {},
            actionIcon: Icons.edit_outlined,
            actionLabel: '编辑',
            onAction: null,
            foregroundColor: Colors.black,
          ),
        ),
      ),
    );

    expect(
      tester.widget<ScrollingTitle>(find.byType(ScrollingTitle)).style?.color,
      Colors.black,
    );
    for (final button in tester.widgetList<MoyueGlassIconButton>(
      find.byType(MoyueGlassIconButton),
    )) {
      expect(button.foregroundColor, Colors.black);
    }
  });

  testWidgets('HTML 阅读器会按设置切换到 WebView 路径', (tester) async {
    final display = MoyueDisplayPreferences()..setHtmlWebViewEnabled(true);
    addTearDown(display.dispose);
    final document = ReadingDocument(
      id: 'webview-html',
      title: '网页阅读',
      content: '<h1>网页正文</h1>',
      kind: DocumentKind.html,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(home: ReaderDetailPage(document: document)),
      ),
    );
    await tester.pump();

    expect(find.byType(WebViewHtmlView), findsOneWidget);
    expect(find.byType(NativeHtmlView), findsNothing);
    expect(find.byIcon(Icons.text_decrease_rounded), findsNothing);
    expect(find.byIcon(Icons.text_increase_rounded), findsNothing);
    final glassButtons = tester.widgetList<GlassButton>(
      find.byType(GlassButton),
    );
    expect(glassButtons, isNotEmpty);
    expect(
      glassButtons.map((button) => button.platformViewBackdrop),
      everyElement(isFalse),
    );
    expect(
      glassButtons.map((button) => button.quality),
      everyElement(GlassQuality.premium),
    );
    final titleGlass = tester.widgetList<GlassContainer>(
      find.descendant(
        of: find.byType(FloatingDocumentHeader),
        matching: find.byType(GlassContainer),
      ),
    );
    expect(titleGlass.map((glass) => glass.platformViewBackdrop), [isFalse]);
    expect(titleGlass.map((glass) => glass.quality), [GlassQuality.premium]);
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

  testWidgets('文档显示修改时间并提供拖动到文件夹的交互', (tester) async {
    final document = ReadingDocument(
      id: 'drag-doc',
      title: '可移动文档',
      content: '# 内容',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026, 8, 23, 18, 30),
      folderId: 'source-folder',
      relativePath: 'markdown/source/note.md',
      logicalPath: 'note.md',
    );
    final target = LibraryFolder(
      id: 'target-folder',
      name: '目标文件夹',
      documents: const [],
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryPage(
            documents: [document],
            folders: [target],
            loading: false,
          ),
        ),
      ),
    );

    final title = find.text('可移动文档');
    final kind = find.text('Markdown');
    final modified = find.text('2026-08-23 18:30');
    expect(modified, findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.textContaining('修改于'), findsNothing);
    expect(kind, findsOneWidget);
    expect(
      (tester.getCenter(title).dy - tester.getCenter(kind).dy).abs(),
      lessThan(2),
    );
    expect(
      tester.getCenter(modified).dy,
      greaterThan(tester.getCenter(title).dy),
    );
    expect(
      find.ancestor(
        of: title,
        matching: find.byWidgetPredicate(
          (widget) => widget is LongPressDraggable,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('目标文件夹'),
        matching: find.byWidgetPredicate((widget) => widget is DragTarget),
      ),
      findsOneWidget,
    );
  });

  testWidgets('阅读器目录使用与新增入口一致的 Material 底部弹层', (tester) async {
    final document = ReadingDocument(
      id: 'toc-doc',
      title: '目录测试',
      content: '# 第一章\n\n正文\n\n## 第二节',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderDetailPage(document: document)),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('目录'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('第一章'), findsWidgets);
    expect(find.textContaining('第二节'), findsWidgets);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag,
      isFalse,
    );
    expect(find.byType(ListTile), findsAtLeastNWidgets(2));
    for (final button in tester.widgetList<MoyueGlassIconButton>(
      find.byType(MoyueGlassIconButton),
    )) {
      expect(button.useOwnLayer, isTrue);
    }
  });

  testWidgets('阅读器无目录提示点击消息以外的区域关闭', (tester) async {
    final document = ReadingDocument(
      id: 'no-headings',
      title: '无目录测试',
      content: '只有正文，没有任何标题。',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderDetailPage(document: document)),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('目录'));
    await tester.pumpAndSettle();
    expect(find.text('当前文档没有标题目录'), findsOneWidget);
    final messageRect = tester.getRect(
      find.byKey(const ValueKey('moyue-message-content')),
    );
    expect(messageRect.width, lessThanOrEqualTo(280));
    expect(messageRect.height, lessThan(48));

    await tester.tap(find.byKey(const ValueKey('moyue-message-content')));
    await tester.pump();
    expect(find.text('当前文档没有标题目录'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('moyue-message-outside-area')));
    await tester.pumpAndSettle();
    expect(find.text('当前文档没有标题目录'), findsNothing);
  });

  testWidgets('Markdown 分享会先询问文件、文字或图片', (tester) async {
    final document = ReadingDocument(
      id: 'share-doc',
      title: '分享测试.md',
      content: '# 分享测试\n\n正文',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderDetailPage(document: document)),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('分享文档'));
    await tester.pumpAndSettle();

    expect(find.text('分享 Markdown'), findsOneWidget);
    expect(find.text('分享 Markdown 文件'), findsOneWidget);
    expect(find.text('分享为纯文字'), findsOneWidget);
    expect(find.text('分享整篇排版图片'), findsOneWidget);
    expect(find.bySemanticsLabel('分享文档'), findsNothing);
  });

  testWidgets('Markdown 整页图片在完成绘制后再调用系统分享', (tester) async {
    ShareParams? sharedParams;
    final shared = Completer<void>();
    SystemShareService.debugShareOverride = (params) async {
      sharedParams = params;
      if (!shared.isCompleted) shared.complete();
      return const ShareResult('moyue-test-share', ShareResultStatus.success);
    };
    addTearDown(() => SystemShareService.debugShareOverride = null);
    final document = ReadingDocument(
      id: 'share-image-doc',
      title: '整页图片.md',
      content: '# 整页图片\n\n${List.filled(24, '这是用于验证长文档完整绘制的段落。').join('\n\n')}',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderDetailPage(document: document)),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('分享文档'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分享整篇排版图片'));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 30 && !shared.isCompleted; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }

    expect(find.textContaining('分享文档失败'), findsNothing);
    expect(sharedParams, isNotNull);
    expect(sharedParams?.fileNameOverrides, <String>['整页图片.png']);
    expect(sharedParams?.files?.single.mimeType, 'image/png');
    final imageBytes = await sharedParams!.files!.single.readAsBytes();
    expect(imageBytes.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置页墨模式开关可开启并弹出重启确认', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(Card).first,
        matching: find.byType(Divider),
      ),
      findsNWidgets(4),
    );

    final inkSwitch = tester.widget<GlassSwitch>(
      find.byType(GlassSwitch).first,
    );
    expect(inkSwitch.value, isFalse);
    expect(inkSwitch.width, 58);
    expect(inkSwitch.height, 26);
    expect(inkSwitch.quality, GlassQuality.premium);
    expect(inkSwitch.settings, isNotNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('墨模式-switch-touch-area'))),
      const Size(104, 56),
    );
    final switchTouchRect = tester.getRect(
      find.byKey(const ValueKey('墨模式-switch-touch-area')),
    );
    final visibleSwitchRect = tester.getRect(find.byType(GlassSwitch).first);
    expect(
      (switchTouchRect.right - visibleSwitchRect.right).abs(),
      lessThanOrEqualTo(0.5),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('墨模式-switch-row-touch-area')))
          .height,
      80,
    );
    final switchPointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(GlassSwitch).first,
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    // 墨模式已开放：开关不再被禁用。
    expect(switchPointer.ignoring, isFalse);
    expect(find.text('已关闭'), findsOneWidget);
    final inkTitle = tester.widget<Text>(find.text('墨模式'));
    expect(
      inkTitle.style?.fontSize,
      lessThan(
        Theme.of(tester.element(find.text('墨模式')))
            .textTheme
            .titleMedium!
            .fontSize!,
      ),
    );
    final inkWell = find
        .ancestor(of: find.text('墨模式'), matching: find.byType(InkWell))
        .first;
    final inkBounds = tester.getRect(inkWell);
    final titleBounds = tester.getRect(find.text('墨模式'));
    expect(titleBounds.left - inkBounds.left, greaterThanOrEqualTo(8));
    expect(titleBounds.top - inkBounds.top, greaterThanOrEqualTo(6));
    await tester.tap(find.text('墨模式'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('墨模式-setting-detail')), findsOneWidget);
    expect(find.textContaining('16级灰阶'), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('墨模式-detail-switch-touch-area')),
      ),
      const Size(104, 56),
    );
    Navigator.of(
      tester.element(find.byKey(const ValueKey('墨模式-setting-detail'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(find.text('需要重启墨阅'), findsNothing);
    expect(display.isInkMode, isFalse);

    // 开关可开启：点按后先弹出重启确认，取消则保持纸张模式。
    await tester.tap(find.byKey(const ValueKey('墨模式-switch-touch-area')));
    await tester.pumpAndSettle();
    expect(find.text('需要重启墨阅'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(display.isInkMode, isFalse);

    // 确认后只落盘偏好并触发重启：运行时状态保持不变（需重启生效）。
    // Mock 系统通道让重启立即成功返回，避免 fake-async 下挂起。
    const systemChannel = MethodChannel('com.moyue.application/system');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(systemChannel, (call) async => true);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(systemChannel, null),
    );
    await tester.tap(find.byKey(const ValueKey('墨模式-switch-touch-area')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用并重启'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(display.isInkMode, isFalse);
    expect(find.byType(AlertDialog), findsNothing);

    await _scrollSettingsUntilVisible(tester, find.text('Web 阅读器'));
    expect(find.text('Web 阅读器'), findsOneWidget);
    expect(display.htmlWebViewEnabled, isFalse);

    // 开关保持主页直控，并且不会误开详情。
    await tester.tap(find.byKey(const ValueKey('Web 阅读器-switch-touch-area')));
    await tester.pump();
    expect(display.htmlWebViewEnabled, isTrue);
    expect(find.byKey(const ValueKey('Web 阅读器-setting-detail')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('Web 阅读器-switch-touch-area')));
    await tester.pump();
    expect(display.htmlWebViewEnabled, isFalse);

    // 文字区域只负责打开长说明，不会同时切换开关。
    await tester.tap(find.text('Web 阅读器'));
    await tester.pumpAndSettle();
    expect(display.htmlWebViewEnabled, isFalse);
    expect(
      find.byKey(const ValueKey('Web 阅读器-setting-detail')),
      findsOneWidget,
    );
    expect(find.textContaining('CSS 与 JavaScript'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('Web 阅读器-detail-switch-touch-area')),
    );
    await tester.pump();
    expect(display.htmlWebViewEnabled, isTrue);
  });

  testWidgets('自定义应用颜色使用 HSV 调色轮而不是颜色代码输入', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final initial = display.customSeedArgb;
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    await tester.tap(find.text('应用配色'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('自定义颜色'));
    await tester.pumpAndSettle();

    final wheel = find.byKey(const ValueKey('custom-color-wheel'));
    expect(wheel, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('custom-color-value-slider')),
      findsOneWidget,
    );
    final wheelRect = tester.getRect(wheel);
    await tester.tapAt(wheelRect.centerRight - const Offset(8, 0));
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('应用')),
    );
    await tester.pumpAndSettle();
    expect(display.customSeedArgb, isNot(initial));
    expect(display.useDynamicColor, isFalse);
  });

  testWidgets('Markdown 与代码主题使用 WheelView 并立即应用', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    await _scrollSettingsUntilVisible(tester, find.text('Markdown 排版风格'));
    await tester.tap(find.text('Markdown 排版风格'));
    await tester.pumpAndSettle();
    var wheel = find.byKey(const ValueKey('markdown-theme-wheel'));
    expect(wheel, findsOneWidget);
    expect(
      find.descendant(of: wheel, matching: find.text('墨阅自适应')),
      findsOneWidget,
    );
    await tester.drag(wheel, const Offset(0, -56));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, '应用'),
      ),
    );
    await tester.pumpAndSettle();
    expect(display.markdownThemeId, 'paper-warm');

    await _scrollSettingsUntilVisible(tester, find.text('代码块外观'));
    await tester.tap(find.text('代码块外观'));
    await tester.pumpAndSettle();
    wheel = find.byKey(const ValueKey('code-highlight-theme-wheel'));
    expect(wheel, findsOneWidget);
    expect(
      find.descendant(of: wheel, matching: find.text('VS Code 自动')),
      findsOneWidget,
    );
    await tester.drag(wheel, const Offset(0, -112));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, '应用'),
      ),
    );
    await tester.pumpAndSettle();
    expect(display.codeThemeId, 'vscode-dark-plus');
  });

  testWidgets('Markdown 渲染模式可在性能优先与全文选择之间切换', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    await _scrollSettingsUntilVisible(tester, find.text('Markdown 渲染模式'));
    expect(find.text('分段渲染'), findsOneWidget);
    await tester.tap(find.text('Markdown 渲染模式'));
    await tester.pumpAndSettle();

    expect(find.text('分段渲染'), findsWidgets);
    expect(find.text('整体渲染'), findsOneWidget);
    expect(find.textContaining('长文滚动更流畅'), findsOneWidget);
    expect(find.textContaining('支持跨越未显示段落'), findsOneWidget);
    await tester.tap(find.text('整体渲染'));
    await tester.pumpAndSettle();

    expect(display.markdownRenderingMode, MarkdownRenderingMode.wholeDocument);
    expect(find.text('整体渲染'), findsOneWidget);
  });

  testWidgets('Markdown 阅读器应用独立的正文配色和代码高亮主题', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final display = MoyueDisplayPreferences()
      ..setMarkdownThemeId('github-dark')
      ..setCodeThemeId('monokai');
    addTearDown(display.dispose);
    final document = ReadingDocument(
      id: 'styled-markdown',
      title: '排版测试.md',
      content:
          '# 标题\n\n正文\n\n```dart\nvoid main() {}\n```\n\n```\nplain code\n```',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(home: ReaderDetailPage(document: document)),
      ),
    );
    await tester.pump();

    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.styleSheet?.blockSpacing, 16);
    expect(markdown.styleSheet?.p?.color, const Color(0xFFE6EDF3));
    final codeDecoration =
        markdown.styleSheet?.codeblockDecoration as BoxDecoration;
    expect(codeDecoration.color, Colors.transparent);
    final codeBlock = tester.widget<MoyueCodeBlock>(
      find.byType(MoyueCodeBlock).first,
    );
    expect(
      ThemeData.estimateBrightnessForColor(codeBlock.palette.background),
      Brightness.dark,
    );
    expect(codeBlock.palette.background, isNot(const Color(0xFF0D1117)));
    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('1 行'), findsNWidgets(2));
    expect(find.byTooltip('复制代码'), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.content_copy_rounded).first);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    final codeCard = tester.widget<Container>(
      find.byKey(const ValueKey('moyue-code-block')).first,
    );
    final cardDecoration = codeCard.decoration as BoxDecoration;
    expect(cardDecoration.gradient, isNotNull);
    expect(cardDecoration.borderRadius, BorderRadius.circular(16));
    expect(
      tester
          .widgetList<MoyueGlassIconButton>(find.byType(MoyueGlassIconButton))
          .map((button) => button.foregroundColor),
      everyElement(Colors.white),
    );
    expect(
      tester.widget<ScrollingTitle>(find.byType(ScrollingTitle)).style?.color,
      Colors.white,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('void main() {}'),
      ),
      findsOneWidget,
    );
    await tester.drag(find.byType(Markdown), const Offset(0, -260));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('plain code'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('清空数据与缓存位于存储区且危险操作使用警告对话框', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('清空全部数据'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.text('清空缓存'), findsOneWidget);
    await tester.tap(find.text('清空全部数据'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('不可撤销的危险操作'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('清空全部数据'),
      ),
      findsWidgets,
    );
  });

  testWidgets('清空缓存结果在没有 Material Scaffold 时仍可显示', (tester) async {
    const systemChannel = MethodChannel('com.moyue.application/system');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(systemChannel, (call) async {
      expect(call.method, 'clearCache');
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(systemChannel, null));
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );

    await _scrollSettingsUntilVisible(tester, find.text('清空缓存'));
    await tester.tap(find.text('清空缓存'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '清空缓存'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('缓存已清空'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('字体大小使用 WheelView 并在应用前提示重启', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await _scrollSettingsUntilVisible(tester, find.text('字体大小'));
    await tester.tap(find.text('字体大小'));
    await tester.pumpAndSettle();

    final wheel = find.byKey(const ValueKey('app-font-size-wheel'));
    expect(wheel, findsOneWidget);
    await tester.drag(wheel, const Offset(0, -56));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, '应用'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('需要重启墨阅'), findsOneWidget);
    expect(find.text('应用并重启'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('预见性返回开关会写入新建路由', (tester) async {
    final display = MoyueDisplayPreferences()..setPredictiveBackEnabled(false);
    addTearDown(display.dispose);
    late Route<void> route;
    final document = ReadingDocument(
      id: 'route-document',
      title: '返回测试',
      content: '# 正文',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              route = readerDetailRoute(context, document);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(route, isA<MoyueMaterialPageRoute<void>>());
    expect(
      (route as MoyueMaterialPageRoute<void>).predictiveBackEnabled,
      isFalse,
    );
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

Future<void> _scrollSettingsUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

class _ThrowingFilePicker extends FilePickerPlatform {
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) => throw StateError('private/storage/path/image.png');
}

class _SelectedFilePicker extends FilePickerPlatform {
  _SelectedFilePicker(this.file);

  final PlatformFile file;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => file;
}

base class _MemoryPlatformFile extends PlatformFile {
  _MemoryPlatformFile({required this.name, required this.bytes});

  @override
  final String name;
  final Uint8List bytes;

  @override
  Uri get uri => Uri.dataFromBytes(bytes);

  @override
  Never get xFile => throw UnsupportedError('Not needed by this test');

  @override
  Future<int> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

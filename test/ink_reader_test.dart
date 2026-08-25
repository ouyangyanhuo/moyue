import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/widgets/ink_refresh_overlay.dart';

void main() {
  testWidgets('墨模式 Markdown 使用整页切换并触发全刷', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final display = MoyueDisplayPreferences();
    await display.setMode(ReadingDisplayMode.ink);
    addTearDown(display.dispose);
    final content = List.generate(
      48,
      (index) =>
          '## 第${index + 1}节\n\n这是第${index + 1}节的正文，用来验证墨模式会按纸张页面重新排版，并保留完整的段落阅读节奏。',
    ).join('\n\n');
    final document = ReadingDocument(
      id: 'ink-pages',
      title: '分页测试',
      content: content,
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
      folderId: 'ink-folder',
      relativePath: 'markdown/ink-folder/分页测试.md',
    );

    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(
          theme: buildMoyueTheme(
            inkMode: true,
            brightness: Brightness.light,
            seedColor: Colors.green,
            fontFamily: MoyueFontFamily.ink,
          ),
          builder: (context, child) => InkRefreshOverlay(
            enabled: true,
            reduceMotion: false,
            child: child!,
          ),
          home: ReaderDetailPage(document: document),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    Finder pageFinder() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('ink-page-'),
    );

    expect(pageFinder(), findsOneWidget);
    expect(find.text('点按屏幕两侧或左右滑动翻页'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('ink-turn-guidance')),
          )
          .opacity,
      1,
    );
    final firstKey = tester.widget(pageFinder()).key;
    await tester.tapAt(const Offset(410, 430));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('ink-full-refresh-flash')),
      findsOneWidget,
    );
    expect(tester.widget(pageFinder()).key, isNot(firstKey));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('ink-turn-guidance')),
          )
          .opacity,
      0,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('ink-full-refresh-flash')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('ink-full-refresh-flash')), findsNothing);
  });

  testWidgets('280ms逐行刷新会合并连续请求', (tester) async {
    final key = GlobalKey<InkRefreshOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: InkRefreshOverlay(
          key: key,
          enabled: true,
          reduceMotion: false,
          child: const ColoredBox(color: Color(0xFFC4D29F)),
        ),
      ),
    );

    final first = key.currentState!.refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final duplicate = key.currentState!.refresh();
    expect(identical(first, duplicate), isTrue);
    expect(
      find.byKey(const ValueKey('ink-full-refresh-flash')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 179));
    expect(
      find.byKey(const ValueKey('ink-full-refresh-flash')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 2));
    await first;
    expect(find.byKey(const ValueKey('ink-full-refresh-flash')), findsNothing);
  });

  testWidgets('减少动态效果时完全关闭逐行刷新', (tester) async {
    final key = GlobalKey<InkRefreshOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: InkRefreshOverlay(
          key: key,
          enabled: true,
          reduceMotion: true,
          child: const ColoredBox(color: Color(0xFFC4D29F)),
        ),
      ),
    );

    await key.currentState!.refresh();
    await tester.pump();
    expect(find.byKey(const ValueKey('ink-full-refresh-flash')), findsNothing);
  });
}

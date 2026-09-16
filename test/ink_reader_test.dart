import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/reading_document.dart';

void main() {
  ReadingDocument longDocument() => ReadingDocument(
    id: 'ink-scroll',
    title: '滚动测试',
    content: List.generate(
      48,
      (index) =>
          '## 第${index + 1}节\n\n这是第${index + 1}节的正文，用来验证墨模式与纸张模式共用同一套滚动排版，内容可以连续向下浏览。',
    ).join('\n\n'),
    kind: DocumentKind.markdown,
    updatedAt: DateTime(2026),
    folderId: 'ink-folder',
    relativePath: 'markdown/ink-folder/滚动测试.md',
  );

  Widget wrap(Widget child, {bool dark = false}) {
    final display = MoyueDisplayPreferences();
    display.setMode(ReadingDisplayMode.ink);
    return DisplayPreferencesScope(
      controller: display,
      child: MaterialApp(
        theme: buildMoyueTheme(
          inkMode: true,
          brightness: dark ? Brightness.dark : Brightness.light,
          seedColor: Colors.green,
          fontFamily: MoyueFontFamily.ink,
        ),
        home: child,
      ),
    );
  }

  testWidgets('墨模式阅读器使用滚动排版且不再显示翻页提示', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(ReaderDetailPage(document: longDocument())));
    await tester.pumpAndSettle();

    // 不再有翻页引导文案。
    expect(find.text('点按屏幕两侧或左右滑动翻页'), findsNothing);
    expect(find.text('第1节'), findsOneWidget);
    expect(find.text('第40节'), findsNothing);

    // 内容可以连续滚动到深处（Markdown 列表按视口懒构建）。
    await tester.drag(find.text('第1节'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('第5节'), findsOneWidget);
  });

  test('墨模式接管减少动态效果与预见性返回', () async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    expect(display.effectiveReduceMotion, isFalse);
    expect(display.effectivePredictiveBackEnabled, isTrue);

    await display.setMode(ReadingDisplayMode.ink);
    expect(display.isInkMode, isTrue);
    // 接管：减少动态效果强制开启，预见性返回强制关闭。
    expect(display.effectiveReduceMotion, isTrue);
    expect(display.effectivePredictiveBackEnabled, isFalse);

    // 回到纸张模式后恢复用户各自的偏好值。
    await display.setMode(ReadingDisplayMode.paper);
    expect(display.effectiveReduceMotion, isFalse);
    expect(display.effectivePredictiveBackEnabled, isTrue);
  });

  test('墨模式配色为中性暖灰纸墨，无绿色偏色', () {
    final light = buildMoyueTheme(
      inkMode: true,
      brightness: Brightness.light,
      seedColor: Colors.green,
      fontFamily: MoyueFontFamily.ink,
    );
    final dark = buildMoyueTheme(
      inkMode: true,
      brightness: Brightness.dark,
      seedColor: Colors.green,
      fontFamily: MoyueFontFamily.ink,
    );

    // 纸面为暖灰纸白，墨色接近纯黑。
    expect(light.colorScheme.surface, const Color(0xFFDFE0D1));
    expect(light.colorScheme.onSurface, const Color(0xFF1E201C));
    expect(dark.colorScheme.surface, const Color(0xFF272925));
    expect(dark.colorScheme.onSurface, const Color(0xFFCECFBE));

    final grayRamp = light.extension<MoyueInkTheme>()!.grayRamp;
    expect(grayRamp.length, 16);
    int channel(Color color, int index) => switch (index) {
      0 => (color.r * 255).round(),
      1 => (color.g * 255).round(),
      _ => (color.b * 255).round(),
    };
    for (final color in grayRamp) {
      // 中性化：红绿差极小；绿略高于蓝，保留一丝苔绿底色（≤18/255）。
      expect(
        (channel(color, 1) - channel(color, 0)).abs(),
        lessThanOrEqualTo(4),
      );
      expect(channel(color, 1) - channel(color, 2), inInclusiveRange(0, 18));
    }
  });
}

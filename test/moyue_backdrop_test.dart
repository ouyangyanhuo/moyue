import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('普通模式${brightness.name}背景使用静态纸纤维与平滑渐变', (tester) async {
      final display = MoyueDisplayPreferences();
      addTearDown(display.dispose);
      final theme = buildMoyueTheme(
        inkMode: false,
        brightness: brightness,
        seedColor: const Color(0xFFC3C6B8),
        fontFamily: MoyueFontFamily.system,
      );
      await tester.pumpWidget(
        DisplayPreferencesScope(
          controller: display,
          child: MaterialApp(theme: theme, home: const MoyueBackdrop()),
        ),
      );

      final backdrop = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('moyue-normal-backdrop')),
      );
      final decoration = backdrop.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      final grain = decoration.image!;
      expect(grain.image, isA<AssetImage>());
      expect(grain.repeat, ImageRepeat.repeat);
      expect(grain.fit, BoxFit.none);
      expect(grain.scale, 2);
      expect(grain.opacity, brightness == Brightness.dark ? 0.10 : 0.16);
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.colors, hasLength(3));
      expect(gradient.colors, everyElement(isNot(equals(Colors.white))));
      if (brightness == Brightness.light) {
        expect(theme.scaffoldBackgroundColor, MoyuePalette.paper);
        expect(<Color>[
          theme.colorScheme.surface,
          theme.colorScheme.surfaceBright,
          theme.colorScheme.surfaceContainerLowest,
          theme.colorScheme.surfaceContainerLow,
          theme.colorScheme.surfaceContainer,
          theme.colorScheme.surfaceContainerHigh,
          theme.colorScheme.surfaceContainerHighest,
        ], everyElement(isNot(equals(Colors.white))));
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('moyue-normal-backdrop')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('纸纹位于内容下方且不拦截点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MoyuePaperSurface(
          color: const Color(0xfff0eee5),
          child: Center(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('正文按钮'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('正文按钮'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byType(IgnorePointer), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

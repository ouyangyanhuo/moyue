import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('普通模式${brightness.name}背景使用无圆形装饰的平滑渐变', (tester) async {
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
          child: MaterialApp(
            theme: theme,
            home: const MoyueBackdrop(),
          ),
        ),
      );

      final backdrop = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('moyue-normal-backdrop')),
      );
      final decoration = backdrop.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.colors, hasLength(3));
      expect(gradient.colors, everyElement(isNot(equals(Colors.white))));
      if (brightness == Brightness.light) {
        expect(theme.scaffoldBackgroundColor, MoyuePalette.paper);
        expect(
          <Color>[
            theme.colorScheme.surface,
            theme.colorScheme.surfaceBright,
            theme.colorScheme.surfaceContainerLowest,
            theme.colorScheme.surfaceContainerLow,
            theme.colorScheme.surfaceContainer,
            theme.colorScheme.surfaceContainerHigh,
            theme.colorScheme.surfaceContainerHighest,
          ],
          everyElement(isNot(equals(Colors.white))),
        );
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
    });
  }
}

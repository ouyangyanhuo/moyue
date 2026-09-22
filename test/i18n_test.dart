import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/l10n/app_localizations.dart';

void main() {
  testWidgets('设置页优先支持英语界面', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SettingsPage()),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Accent color'), findsOneWidget);
    expect(find.text('Night mode'), findsOneWidget);
    expect(find.text('Font style'), findsOneWidget);
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('设置页支持简体中文界面', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SettingsPage()),
        ),
      ),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('主题颜色'), findsOneWidget);
    expect(find.text('夜间模式'), findsOneWidget);
    expect(find.text('字体风格'), findsOneWidget);
  });
}

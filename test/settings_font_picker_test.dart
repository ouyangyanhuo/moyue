import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/services/app_restart_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('字体大小使用带 Material 选中态的 WheelView', (tester) async {
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
    expect(find.byType(ListWheelScrollView), findsOneWidget);
    expect(
      find.descendant(of: wheel, matching: find.text('100%')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: wheel,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: wheel, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('应用新字号会保存设置并请求原生重启', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final calls = <MethodCall>[];
    const channel = MethodChannel('com.moyue.application/system');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

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
    await tester.drag(wheel, const Offset(0, -56));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, '应用'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用并重启'));
    await tester.pumpAndSettle();

    expect(display.appFontScale, isNot(1));
    expect(calls, hasLength(1));
    expect(calls.single.method, 'restartApp');
  });

  testWidgets('字体风格使用与夜间模式一致的选项组件并可切换衬线体', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    await _scrollSettingsUntilVisible(tester, find.text('字体风格'));
    await tester.tap(find.text('字体风格'));
    await tester.pumpAndSettle();

    expect(find.byType(ListWheelScrollView), findsNothing);
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('系统字体')),
      findsOneWidget,
    );
    expect(find.text('更富有灵动与美感的衬线书面字体'), findsOneWidget);
    final serifOption = find.descendant(
      of: sheet,
      matching: find.widgetWithText(ListTile, '衬线体'),
    );
    await tester.tap(serifOption);
    await tester.pumpAndSettle();

    expect(display.appFontFamily, MoyueFontFamily.claude);
  });

  testWidgets('原生重启通道不可用时会安全返回 false', (tester) async {
    const channel = MethodChannel('com.moyue.application/system');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(await AppRestartService.restart(), isFalse);
  });
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

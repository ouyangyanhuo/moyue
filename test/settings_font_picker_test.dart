import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/services/app_restart_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('字号 WheelView 使用明确的 Material 选中态', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);

    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.ensureVisible(find.text('软件字体大小'));
    await tester.tap(find.text('软件字体大小'));
    await tester.pumpAndSettle();

    final wheel = find.byKey(const ValueKey('app-font-size-wheel'));
    final selected = find.byKey(
      const ValueKey('app-font-size-selected-option'),
    );
    expect(wheel, findsOneWidget);
    expect(selected, findsOneWidget);
    expect(
      find.descendant(of: wheel, matching: find.byType(GlassContainer)),
      findsNothing,
    );

    final selectedMaterial = tester.widget<Material>(selected);
    expect(
      selectedMaterial.color,
      Theme.of(tester.element(selected)).colorScheme.secondaryContainer,
    );
    expect(
      find.descendant(of: selected, matching: find.byIcon(Icons.check_rounded)),
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
    await tester.ensureVisible(find.text('软件字体大小'));
    await tester.tap(find.text('软件字体大小'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('app-font-size-wheel')),
      const Offset(0, -70),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用并重启'));
    await tester.pumpAndSettle();

    expect(display.appFontScale, isNot(1));
    expect(calls, hasLength(1));
    expect(calls.single.method, 'restartApp');
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/app/moyue_app.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('冷启动直接以墨模式进入首页，不卡死且可切换标签', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 预置已保存的墨模式偏好，模拟用户开启墨模式后的下一次启动。
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'display.mode': 'ink',
        });
    final display = MoyueDisplayPreferences();
    await display.load();
    addTearDown(display.dispose);
    expect(display.isInkMode, isTrue);

    await tester.pumpWidget(const MoyueApp());
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('阅读'), findsWidgets);
    expect(find.text('本地文档，安静阅读'), findsOneWidget);

    // 墨模式下玻璃 Dock 降级为 standard。
    final context = tester.element(find.byType(MaterialApp));
    final theme = Theme.of(context);
    final ink = theme.extension<MoyueInkTheme>();
    expect(ink?.enabled, isTrue);

    // 标签仍可正常切换（排除事件循环被占死的可能）。
    await tester.tap(find.byIcon(Icons.tune_outlined).last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('设置'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

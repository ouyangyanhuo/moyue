import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HTML WebView 开关会持久化并在下次启动恢复', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = MoyueDisplayPreferences();
    first.setHtmlWebViewEnabled(true);
    await Future<void>.delayed(Duration.zero);

    final restored = MoyueDisplayPreferences();
    await restored.load();

    expect(restored.htmlWebViewEnabled, isTrue);
    first.dispose();
    restored.dispose();
  });

  test('字体大小与预见性返回开关会持久化', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = MoyueDisplayPreferences();
    await first.setAppFontScale(1.2);
    first.setPredictiveBackEnabled(false);
    await Future<void>.delayed(Duration.zero);

    final restored = MoyueDisplayPreferences();
    await restored.load();

    expect(restored.appFontScale, 1.2);
    expect(restored.predictiveBackEnabled, isFalse);
    first.dispose();
    restored.dispose();
  });

  test('减少动态效果会持久化并让应用页面路由立即切换', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = MoyueDisplayPreferences()..setReduceMotion(true);
    await Future<void>.delayed(Duration.zero);

    final restored = MoyueDisplayPreferences();
    await restored.load();
    final route = MoyueMaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
      predictiveBackEnabled: true,
      reduceMotion: restored.reduceMotion,
    );

    expect(restored.reduceMotion, isTrue);
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    first.dispose();
    restored.dispose();
  });

  test('主题、语言、界面字体和自定义颜色会持久化', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = MoyueDisplayPreferences();
    first
      ..setThemePreference(MoyueThemePreference.dark)
      ..setLocalePreference(MoyueLocalePreference.english)
      ..setAppFontFamily(MoyueFontFamily.claude)
      ..setCustomSeedArgb(0xFF356A91);
    await Future<void>.delayed(Duration.zero);

    final restored = MoyueDisplayPreferences();
    await restored.load();

    expect(restored.themePreference, MoyueThemePreference.dark);
    expect(restored.localePreference, MoyueLocalePreference.english);
    expect(restored.locale, const Locale('en'));
    expect(restored.appFontFamily, MoyueFontFamily.claude);
    expect(restored.useDynamicColor, isFalse);
    expect(restored.customSeedArgb, 0xFF356A91);
    expect(restored.effectiveSeedArgb, 0xFF356A91);
    first.dispose();
    restored.dispose();
  });

  test('莫奈取色默认关闭，用户开启后使用系统种子色', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('com.moyue.application/system');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'systemAppearance');
      return <String, Object?>{
        'dynamicColorSupported': true,
        'seedArgb': 0xFF765A9B,
        'accentArgb': 0xFF112233,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final display = MoyueDisplayPreferences();
    await display.load();

    expect(display.dynamicColorSupported, isTrue);
    expect(display.useDynamicColor, isFalse);
    expect(display.effectiveSeedArgb, display.customSeedArgb);
    display.setUseDynamicColor(true);
    expect(display.useDynamicColor, isTrue);
    expect(display.effectiveSeedArgb, 0xFF765A9B);
    display.dispose();
  });
}

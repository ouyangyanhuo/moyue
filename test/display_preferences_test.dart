import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_code_theme_registry.dart';
import 'package:moyue_application/core/display/moyue_markdown_theme_registry.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认高亮色使用低饱和灰绿色', () {
    final display = MoyueDisplayPreferences();
    expect(display.customSeedArgb, 0xFFC3C6B8);
    expect(display.effectiveSeedArgb, 0xFFC3C6B8);
    display.dispose();
  });

  test('旧版默认高亮色会迁移为更柔和的新默认色', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'display.custom_seed_argb': 0xFFBBBEAE,
        });
    final display = MoyueDisplayPreferences();
    await display.load();

    expect(display.customSeedArgb, 0xFFC3C6B8);

    final restored = MoyueDisplayPreferences();
    await restored.load();
    expect(restored.customSeedArgb, 0xFFC3C6B8);
    display.dispose();
    restored.dispose();
  });

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

  test('saveModePreference 只落盘偏好，不改运行时状态', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final controller = MoyueDisplayPreferences();

    await controller.saveModePreference(ReadingDisplayMode.ink);

    // 运行时保持纸张模式（配合重启式切换，避免热切换卡死）。
    expect(controller.isInkMode, isFalse);

    final restored = MoyueDisplayPreferences();
    await restored.load();
    expect(restored.mode, ReadingDisplayMode.ink);
    controller.dispose();
    restored.dispose();
  });

  test('墨模式持久化并只覆盖有效显示值，不破坏原偏好', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = MoyueDisplayPreferences()
      ..setAppFontFamily(MoyueFontFamily.rounded)
      ..setMarkdownThemeId('github-dark')
      ..setCodeThemeId('dracula');
    await first.setAppFontScale(1.3);
    await first.setMode(ReadingDisplayMode.ink);

    expect(first.isInkMode, isTrue);
    expect(first.appFontFamily, MoyueFontFamily.rounded);
    expect(first.appFontScale, 1.3);
    expect(first.markdownThemeId, 'github-dark');
    expect(first.codeThemeId, 'dracula');
    expect(first.effectiveAppFontFamily, MoyueFontFamily.ink);
    expect(first.effectiveAppFontScale, 1);
    expect(first.effectiveMarkdownThemeId, 'moyue-ink');
    expect(first.effectiveCodeThemeId, 'moyue-ink');

    final restored = MoyueDisplayPreferences();
    await restored.load();
    expect(restored.mode, ReadingDisplayMode.ink);
    await restored.setMode(ReadingDisplayMode.paper);
    expect(restored.effectiveAppFontFamily, MoyueFontFamily.rounded);
    expect(restored.effectiveAppFontScale, 1.3);
    expect(restored.effectiveMarkdownThemeId, 'github-dark');
    expect(restored.effectiveCodeThemeId, 'dracula');
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
      inkMode: false,
    );

    expect(restored.reduceMotion, isTrue);
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    first.dispose();
    restored.dispose();
  });

  test('主题、语言、字体风格、Markdown 外观和自定义颜色会持久化', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = MoyueDisplayPreferences();
    first
      ..setThemePreference(MoyueThemePreference.dark)
      ..setLocalePreference(MoyueLocalePreference.english)
      ..setAppFontFamily(MoyueFontFamily.claude)
      ..setMarkdownThemeId('paper-warm')
      ..setCodeThemeId('monokai')
      ..setCustomSeedArgb(0xFF356A91);
    await Future<void>.delayed(Duration.zero);

    final restored = MoyueDisplayPreferences();
    await restored.load();

    expect(restored.themePreference, MoyueThemePreference.dark);
    expect(restored.localePreference, MoyueLocalePreference.english);
    expect(restored.locale, const Locale('en'));
    expect(restored.appFontFamily, MoyueFontFamily.claude);
    expect(restored.markdownThemeId, 'paper-warm');
    expect(restored.codeThemeId, 'monokai');
    expect(restored.useDynamicColor, isFalse);
    expect(restored.customSeedArgb, 0xFF356A91);
    expect(restored.effectiveSeedArgb, 0xFF356A91);
    first.dispose();
    restored.dispose();
  });

  test('Markdown 与代码主题注册表允许独立侧载扩展', () {
    const markdownId = 'test-reader-palette';
    const codeId = 'test-token-palette';
    addTearDown(() {
      MoyueMarkdownThemeRegistry.unregister(markdownId);
      MoyueCodeThemeRegistry.unregister(codeId);
    });

    MoyueMarkdownThemeRegistry.register(
      MoyueMarkdownThemeDefinition(
        id: markdownId,
        labelBuilder: (_) => 'Reader palette',
        descriptionBuilder: (_) => 'Sideloaded reader palette',
        paletteBuilder: (_) => const MoyueMarkdownPalette(
          surface: Colors.white,
          foreground: Colors.black,
          mutedForeground: Colors.black54,
          heading: Colors.black,
          link: Colors.blue,
          accent: Colors.blue,
          blockquoteSurface: Color(0xFFF5F5F5),
          inlineCodeSurface: Color(0xFFF0F0F0),
          tableHeaderSurface: Color(0xFFF5F5F5),
          outline: Colors.black26,
        ),
      ),
    );
    MoyueCodeThemeRegistry.register(
      MoyueCodeThemeDefinition(
        id: codeId,
        labelBuilder: (_) => 'Token palette',
        descriptionBuilder: (_) => 'Sideloaded token palette',
        paletteBuilder: (_) => const {
          'root': TextStyle(color: Colors.white, backgroundColor: Colors.black),
        },
      ),
    );

    expect(MoyueMarkdownThemeRegistry.resolve(markdownId).id, markdownId);
    expect(MoyueCodeThemeRegistry.resolve(codeId).id, codeId);
    expect(
      MoyueMarkdownThemeRegistry.resolve('missing').id,
      MoyueMarkdownThemeRegistry.defaultThemeId,
    );
    expect(
      MoyueCodeThemeRegistry.resolve('missing').id,
      MoyueCodeThemeRegistry.defaultThemeId,
    );
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

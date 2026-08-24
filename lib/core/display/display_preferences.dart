import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:moyue_application/services/system_appearance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingDisplayMode { paper, ink }

enum MoyueThemePreference { system, light, dark }

enum MoyueLocalePreference { system, chinese, english }

enum MoyueFontFamily { system, claude, rounded }

/// A small boundary that can later be backed by platform e-ink controls.
abstract interface class DisplayModeController implements Listenable {
  ReadingDisplayMode get mode;
  double get contrast;
  bool get reduceMotion;
  double get glassOpacity;
  bool get htmlWebViewEnabled;
  double get appFontScale;
  bool get predictiveBackEnabled;
  MoyueThemePreference get themePreference;
  MoyueLocalePreference get localePreference;
  MoyueFontFamily get appFontFamily;
  bool get dynamicColorSupported;
  bool get useDynamicColor;
  int get effectiveSeedArgb;
  int get customSeedArgb;

  void setMode(ReadingDisplayMode mode);
  void setContrast(double value);
  void setReduceMotion(bool value);
  void setHtmlWebViewEnabled(bool value);
  Future<void> setAppFontScale(double value);
  void setPredictiveBackEnabled(bool value);
  void setThemePreference(MoyueThemePreference value);
  void setLocalePreference(MoyueLocalePreference value);
  void setAppFontFamily(MoyueFontFamily value);
  void setUseDynamicColor(bool value);
  void setCustomSeedArgb(int value);
}

class MoyueDisplayPreferences extends ChangeNotifier
    implements DisplayModeController {
  ReadingDisplayMode _mode = ReadingDisplayMode.paper;
  double _contrast = 0.58;
  bool _reduceMotion = false;
  bool _htmlWebViewEnabled = false;
  double _appFontScale = 1;
  bool _predictiveBackEnabled = true;
  MoyueThemePreference _themePreference = MoyueThemePreference.system;
  MoyueLocalePreference _localePreference = MoyueLocalePreference.system;
  MoyueFontFamily _appFontFamily = MoyueFontFamily.system;
  bool _dynamicColorSupported = false;
  bool _useDynamicColor = false;
  int? _dynamicSeedArgb;
  int _customSeedArgb = 0xFF6D7967;

  static const _htmlWebViewKey = 'reader.html_webview_enabled';
  static const _reduceMotionKey = 'display.reduce_motion';
  static const _appFontScaleKey = 'display.app_font_scale';
  static const _predictiveBackKey = 'navigation.predictive_back_enabled';
  static const _themePreferenceKey = 'display.theme_preference';
  static const _localePreferenceKey = 'i18n.locale_preference';
  static const _fontFamilyKey = 'display.app_font_family';
  static const _useDynamicColorKey = 'display.use_dynamic_color';
  static const _customSeedArgbKey = 'display.custom_seed_argb';

  @override
  ReadingDisplayMode get mode => _mode;
  @override
  double get contrast => _contrast;
  @override
  bool get reduceMotion => _reduceMotion;
  @override
  double get glassOpacity => 0;
  @override
  bool get htmlWebViewEnabled => _htmlWebViewEnabled;
  @override
  double get appFontScale => _appFontScale;
  @override
  bool get predictiveBackEnabled => _predictiveBackEnabled;
  @override
  MoyueThemePreference get themePreference => _themePreference;
  @override
  MoyueLocalePreference get localePreference => _localePreference;
  @override
  MoyueFontFamily get appFontFamily => _appFontFamily;
  @override
  bool get dynamicColorSupported => _dynamicColorSupported;
  @override
  bool get useDynamicColor => _useDynamicColor;
  @override
  int get customSeedArgb => _customSeedArgb;
  @override
  int get effectiveSeedArgb => _useDynamicColor && _dynamicSeedArgb != null
      ? _dynamicSeedArgb!
      : _customSeedArgb;
  bool get isInkMode => _mode == ReadingDisplayMode.ink;

  Locale? get locale => switch (_localePreference) {
    MoyueLocalePreference.system => null,
    MoyueLocalePreference.chinese => const Locale('zh'),
    MoyueLocalePreference.english => const Locale('en'),
  };

  Future<void> load() async {
    try {
      final preferences = SharedPreferencesAsync();
      final htmlValue = await preferences.getBool(_htmlWebViewKey) ?? false;
      final reduceMotionValue =
          await preferences.getBool(_reduceMotionKey) ?? false;
      final fontValue = await preferences.getDouble(_appFontScaleKey) ?? 1.0;
      final predictiveValue =
          await preferences.getBool(_predictiveBackKey) ?? true;
      final themeValue = _enumByName(
        MoyueThemePreference.values,
        await preferences.getString(_themePreferenceKey),
        MoyueThemePreference.system,
      );
      final localeValue = _enumByName(
        MoyueLocalePreference.values,
        await preferences.getString(_localePreferenceKey),
        MoyueLocalePreference.system,
      );
      final familyValue = _enumByName(
        MoyueFontFamily.values,
        await preferences.getString(_fontFamilyKey),
        MoyueFontFamily.system,
      );
      final useDynamicValue =
          await preferences.getBool(_useDynamicColorKey) ?? false;
      final customSeedValue =
          await preferences.getInt(_customSeedArgbKey) ?? _customSeedArgb;
      final appearance = await SystemAppearanceService.load();
      final nextFont = fontValue.clamp(0.8, 1.4);
      final changed =
          _htmlWebViewEnabled != htmlValue ||
          _reduceMotion != reduceMotionValue ||
          _appFontScale != nextFont ||
          _predictiveBackEnabled != predictiveValue ||
          _themePreference != themeValue ||
          _localePreference != localeValue ||
          _appFontFamily != familyValue ||
          _useDynamicColor != useDynamicValue ||
          _customSeedArgb != customSeedValue ||
          _dynamicColorSupported != appearance.dynamicColorSupported ||
          _dynamicSeedArgb != appearance.seedArgb;
      _htmlWebViewEnabled = htmlValue;
      _reduceMotion = reduceMotionValue;
      _appFontScale = nextFont;
      _predictiveBackEnabled = predictiveValue;
      _themePreference = themeValue;
      _localePreference = localeValue;
      _appFontFamily = familyValue;
      _useDynamicColor = useDynamicValue;
      _customSeedArgb = customSeedValue;
      _dynamicColorSupported = appearance.dynamicColorSupported;
      _dynamicSeedArgb = appearance.seedArgb;
      if (changed) notifyListeners();
    } on Object {
      // 测试环境或平台存储暂不可用时保留安全的原生 HTML 默认值。
    }
  }

  @override
  void setMode(ReadingDisplayMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  @override
  void setContrast(double value) {
    final next = value.clamp(0.0, 1.0);
    if (_contrast == next) return;
    _contrast = next;
    notifyListeners();
  }

  @override
  void setReduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
    unawaited(_saveBool(_reduceMotionKey, value));
  }

  @override
  void setHtmlWebViewEnabled(bool value) {
    if (_htmlWebViewEnabled == value) return;
    _htmlWebViewEnabled = value;
    notifyListeners();
    unawaited(_saveHtmlWebViewEnabled(value));
  }

  @override
  Future<void> setAppFontScale(double value) async {
    final next = value.clamp(0.8, 1.4);
    if (_appFontScale == next) return;
    _appFontScale = next;
    notifyListeners();
    try {
      await SharedPreferencesAsync().setDouble(_appFontScaleKey, next);
    } on Object {
      // 当前进程仍可预览新字号；用户下次可再次应用。
    }
  }

  @override
  void setPredictiveBackEnabled(bool value) {
    if (_predictiveBackEnabled == value) return;
    _predictiveBackEnabled = value;
    notifyListeners();
    unawaited(_savePredictiveBackEnabled(value));
  }

  @override
  void setThemePreference(MoyueThemePreference value) {
    if (_themePreference == value) return;
    _themePreference = value;
    notifyListeners();
    unawaited(_saveString(_themePreferenceKey, value.name));
  }

  @override
  void setLocalePreference(MoyueLocalePreference value) {
    if (_localePreference == value) return;
    _localePreference = value;
    notifyListeners();
    unawaited(_saveString(_localePreferenceKey, value.name));
  }

  @override
  void setAppFontFamily(MoyueFontFamily value) {
    if (_appFontFamily == value) return;
    _appFontFamily = value;
    notifyListeners();
    unawaited(_saveString(_fontFamilyKey, value.name));
  }

  @override
  void setUseDynamicColor(bool value) {
    if (_useDynamicColor == value) return;
    _useDynamicColor = value;
    notifyListeners();
    unawaited(_saveBool(_useDynamicColorKey, value));
  }

  @override
  void setCustomSeedArgb(int value) {
    final next = value | 0xFF000000;
    if (_customSeedArgb == next && !_useDynamicColor) return;
    _customSeedArgb = next;
    _useDynamicColor = false;
    notifyListeners();
    unawaited(_saveInt(_customSeedArgbKey, next));
    unawaited(_saveBool(_useDynamicColorKey, false));
  }

  Future<void> _saveHtmlWebViewEnabled(bool value) async {
    try {
      await SharedPreferencesAsync().setBool(_htmlWebViewKey, value);
    } on Object {
      // 运行时状态仍然有效；平台持久化失败不应打断设置交互。
    }
  }

  Future<void> _savePredictiveBackEnabled(bool value) async {
    try {
      await SharedPreferencesAsync().setBool(_predictiveBackKey, value);
    } on Object {
      // 运行时开关仍然有效。
    }
  }

  Future<void> _saveString(String key, String value) async {
    try {
      await SharedPreferencesAsync().setString(key, value);
    } on Object {
      // 当前进程状态仍保持有效。
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      await SharedPreferencesAsync().setBool(key, value);
    } on Object {
      // 当前进程状态仍保持有效。
    }
  }

  Future<void> _saveInt(String key, int value) async {
    try {
      await SharedPreferencesAsync().setInt(key, value);
    } on Object {
      // 当前进程状态仍保持有效。
    }
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

/// Returns a zero duration when Moyue's reduce-motion preference is enabled.
/// Custom animations use this in addition to Flutter's global
/// `MediaQuery.disableAnimations` accessibility signal.
Duration moyueMotionDuration(BuildContext context, Duration normal) =>
    (DisplayPreferencesScope.maybeOf(context)?.reduceMotion ?? false)
    ? Duration.zero
    : normal;

class DisplayPreferencesScope extends InheritedNotifier<DisplayModeController> {
  const DisplayPreferencesScope({
    required DisplayModeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static DisplayModeController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DisplayPreferencesScope>();
    assert(scope != null, 'DisplayPreferencesScope is missing.');
    return scope!.notifier!;
  }

  static DisplayModeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DisplayPreferencesScope>()
      ?.notifier;
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingDisplayMode { paper, ink }

/// A small boundary that can later be backed by platform e-ink controls.
abstract interface class DisplayModeController implements Listenable {
  ReadingDisplayMode get mode;
  double get contrast;
  bool get reduceMotion;
  double get glassOpacity;
  bool get htmlWebViewEnabled;

  void setMode(ReadingDisplayMode mode);
  void setContrast(double value);
  void setReduceMotion(bool value);
  void setHtmlWebViewEnabled(bool value);
}

class MoyueDisplayPreferences extends ChangeNotifier
    implements DisplayModeController {
  ReadingDisplayMode _mode = ReadingDisplayMode.paper;
  double _contrast = 0.58;
  bool _reduceMotion = false;
  bool _htmlWebViewEnabled = false;

  static const _htmlWebViewKey = 'reader.html_webview_enabled';

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
  bool get isInkMode => _mode == ReadingDisplayMode.ink;

  Future<void> load() async {
    try {
      final value =
          await SharedPreferencesAsync().getBool(_htmlWebViewKey) ?? false;
      if (_htmlWebViewEnabled == value) return;
      _htmlWebViewEnabled = value;
      notifyListeners();
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
  }

  @override
  void setHtmlWebViewEnabled(bool value) {
    if (_htmlWebViewEnabled == value) return;
    _htmlWebViewEnabled = value;
    notifyListeners();
    unawaited(_saveHtmlWebViewEnabled(value));
  }

  Future<void> _saveHtmlWebViewEnabled(bool value) async {
    try {
      await SharedPreferencesAsync().setBool(_htmlWebViewKey, value);
    } on Object {
      // 运行时状态仍然有效；平台持久化失败不应打断设置交互。
    }
  }
}

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

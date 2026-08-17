import 'package:flutter/widgets.dart';

enum ReadingDisplayMode { paper, ink }

/// A small boundary that can later be backed by platform e-ink controls.
abstract interface class DisplayModeController implements Listenable {
  ReadingDisplayMode get mode;
  double get contrast;
  bool get reduceMotion;

  void setMode(ReadingDisplayMode mode);
  void setContrast(double value);
  void setReduceMotion(bool value);
}

class MoyueDisplayPreferences extends ChangeNotifier
    implements DisplayModeController {
  ReadingDisplayMode _mode = ReadingDisplayMode.paper;
  double _contrast = 0.58;
  bool _reduceMotion = false;

  @override
  ReadingDisplayMode get mode => _mode;
  @override
  double get contrast => _contrast;
  @override
  bool get reduceMotion => _reduceMotion;
  bool get isInkMode => _mode == ReadingDisplayMode.ink;

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
}

import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android 11+ publishes only IME animation boundaries, never animation frames.
/// Other platforms use one trailing-edge update, without polling for stability.
class EditorKeyboardController extends ChangeNotifier
    with WidgetsBindingObserver {
  EditorKeyboardController(this.view) {
    unawaited(_connect());
  }

  final FlutterView view;
  StreamSubscription<dynamic>? _subscription;
  Timer? _settleTimer;
  bool _fallback = false;
  bool _disposed = false;
  bool _animating = false;
  double _inset = 0;

  bool get animating => _animating;
  double get inset => _inset;

  Future<void> _connect() async {
    var supported = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        supported =
            await const MethodChannel('com.moyue.application/system')
                .invokeMethod<bool>('editorKeyboardEventsSupported') ??
            false;
      } on MissingPluginException {
        // Older hosts and widget tests don't install the native observer.
      } on PlatformException {
        // Keep the editor usable if the host cannot establish the channel.
      }
    }
    if (_disposed) return;
    if (!supported) {
      _useFallback();
      return;
    }
    _subscription = const EventChannel('com.moyue.application/editor_keyboard')
        .receiveBroadcastStream()
        .listen(_nativeEvent, onError: _useFallback, onDone: _useFallback);
  }

  void _nativeEvent(dynamic event) {
    if (_disposed || event is! Map) return;
    if (event['phase'] == 'changing') {
      // Keep the last stable text padding while hiding only the floating dock.
      _update(_inset, true);
    } else if (event['phase'] == 'settled') {
      final pixels = event['bottom'];
      if (pixels is num) {
        _update(
          (pixels / view.devicePixelRatio).clamp(0, double.infinity),
          false,
        );
      }
    }
  }

  void _useFallback([Object? error, StackTrace? stack]) {
    if (_disposed || _fallback) return;
    _fallback = true;
    WidgetsBinding.instance.addObserver(this);
    didChangeMetrics();
  }

  @override
  void didChangeMetrics() {
    if (!_fallback || _disposed) return;
    _update(_inset, true);
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 80), () {
      _update(view.viewInsets.bottom / view.devicePixelRatio, false);
    });
  }

  void _update(double inset, bool animating) {
    if (_disposed || (_inset == inset && _animating == animating)) return;
    _inset = inset;
    _animating = animating;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_fallback) WidgetsBinding.instance.removeObserver(this);
    _settleTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

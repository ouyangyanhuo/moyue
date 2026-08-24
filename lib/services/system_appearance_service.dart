import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemAppearance {
  const SystemAppearance({required this.dynamicColorSupported, this.seedArgb});

  final bool dynamicColorSupported;
  final int? seedArgb;
}

/// Small platform boundary for Android 12+ Material You (Monet) colors.
class SystemAppearanceService {
  const SystemAppearanceService._();

  static const _channel = MethodChannel('com.moyue.application/system');

  static Future<SystemAppearance> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SystemAppearance(dynamicColorSupported: false);
    }
    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'systemAppearance',
      );
      final supported = value?['dynamicColorSupported'] == true;
      // `accentArgb` remains accepted for older Android hosts and tests from
      // builds created before wallpaper-derived seed support was added.
      final seed = value?['seedArgb'] ?? value?['accentArgb'];
      return SystemAppearance(
        dynamicColorSupported: supported,
        seedArgb: seed is int ? seed : null,
      );
    } on Object {
      return const SystemAppearance(dynamicColorSupported: false);
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform boundary for destructive storage maintenance operations.
///
/// Clearing application data is intentionally delegated to Android so the
/// OS removes preferences, databases, app-specific external files and cache
/// as one atomic operation, then terminates the process as users expect.
class AppStorageMaintenanceService {
  const AppStorageMaintenanceService._();

  static const _channel = MethodChannel('com.moyue.application/system');

  static Future<bool> clearCache() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('clearCache') ?? false;
    } on Object {
      return false;
    }
  }

  static Future<bool> clearApplicationData() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('clearApplicationData') ?? false;
    } on Object {
      return false;
    }
  }
}

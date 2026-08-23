import 'package:flutter/services.dart';

class AppRestartService {
  const AppRestartService._();

  static const MethodChannel _channel = MethodChannel(
    'com.moyue.application/system',
  );

  /// 让 Android Activity 原地重建；测试、Web 或未实现的平台返回 false。
  static Future<bool> restart() async {
    try {
      return await _channel.invokeMethod<bool>('restartApp') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

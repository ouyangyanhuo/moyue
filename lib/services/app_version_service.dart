import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  const AppVersionService._();

  /// 内部版本代号可在构建时覆盖，例如：
  /// `--dart-define=MOYUE_INTERNAL_VERSION=Banana`。
  static const internalVersion = String.fromEnvironment(
    'MOYUE_INTERNAL_VERSION',
    defaultValue: 'Apple',
  );

  static Future<String> displayVersion() async {
    final package = await PackageInfo.fromPlatform();
    return formatVersion(
      version: package.version,
      internalVersion: internalVersion,
    );
  }

  @visibleForTesting
  static String formatVersion({
    required String version,
    required String internalVersion,
  }) {
    final publicVersion = version.trim();
    final internal = internalVersion.trim();
    if (publicVersion.isEmpty) return internal;
    if (internal.isEmpty) return publicVersion;
    return '$publicVersion($internal)';
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:moyue_application/services/storage/package_file_store.dart';

/// 调试开关服务。
///
/// 当应用数据目录（Android 为 /Android/data/com.moyue.application/files）
/// 下存在 `debug/debug.lock` 且文件内容包含一行 `debug = true` 时，
/// 调试模式开启，设置页随之显示独立的「调试」选项区。
/// 应用启动与回到前台时各检查一次，随时可通过增删该文件切换。
class DebugService extends ChangeNotifier {
  DebugService._();

  static final DebugService instance = DebugService._();

  /// debug 锁文件相对于应用数据目录的路径。
  static const String lockRelativePath = 'debug/debug.lock';

  bool _enabled = false;
  bool _fpsBadgeVisible = false;
  Future<void>? _pending;

  /// 调试模式当前是否启用。
  bool get enabled => _enabled;

  /// 是否在屏幕右上角显示实时帧率徽标。
  bool get fpsBadgeVisible => _fpsBadgeVisible;

  set fpsBadgeVisible(bool value) {
    if (_fpsBadgeVisible == value) return;
    _fpsBadgeVisible = value;
    notifyListeners();
  }

  /// 重新读取 debug.lock；文件缺失、无法读取或内容不符都视为未启用。
  Future<void> refresh() {
    // 合并并发调用，避免启动与回到前台同时触发重复 IO。
    return _pending ??= _read().whenComplete(() => _pending = null);
  }

  Future<void> _read() async {
    var enabled = false;
    try {
      final content = await createPackageFileStore().readText(lockRelativePath);
      enabled = parseLockContent(content);
    } on Object {
      enabled = false;
    }
    if (_enabled == enabled) return;
    _enabled = enabled;
    // 退出调试模式时一并收起帧率徽标。
    if (!enabled) _fpsBadgeVisible = false;
    notifyListeners();
  }

  /// 解析 debug.lock 文本：任一行匹配 `debug = true`
  /// （忽略大小写与首尾空白）即返回 true。
  @visibleForTesting
  static bool parseLockContent(String content) {
    final pattern = RegExp(
      r'^\s*debug\s*=\s*true\s*$',
      caseSensitive: false,
      multiLine: true,
    );
    return pattern.hasMatch(content);
  }
}

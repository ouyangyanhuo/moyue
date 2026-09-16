import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

/// 保留普通返回按钮/返回键，只按用户设置决定是否允许 Android 预见性
/// 返回手势启动。这样关闭动画不会改变业务页面的退出逻辑。
class MoyueMaterialPageRoute<T> extends MaterialPageRoute<T> {
  MoyueMaterialPageRoute({
    required super.builder,
    required this.predictiveBackEnabled,
    required this.reduceMotion,
    required this.inkMode,
    super.settings,
    super.allowSnapshotting,
    super.maintainState,
    super.fullscreenDialog,
  });

  final bool predictiveBackEnabled;
  final bool reduceMotion;
  final bool inkMode;

  @override
  Duration get transitionDuration => reduceMotion
      ? Duration.zero
      : inkMode
      ? super.transitionDuration + const Duration(milliseconds: 75)
      : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => reduceMotion
      ? Duration.zero
      : inkMode
      ? super.reverseTransitionDuration + const Duration(milliseconds: 75)
      : super.reverseTransitionDuration;

  @override
  bool get popGestureEnabled =>
      predictiveBackEnabled && super.popGestureEnabled;
}

MoyueMaterialPageRoute<T> moyuePageRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool allowSnapshotting = true,
}) => MoyueMaterialPageRoute<T>(
  builder: builder,
  allowSnapshotting: allowSnapshotting,
  predictiveBackEnabled:
      DisplayPreferencesScope.maybeOf(context)?.effectivePredictiveBackEnabled ??
      true,
  reduceMotion:
      DisplayPreferencesScope.maybeOf(context)?.effectiveReduceMotion ?? false,
  inkMode: DisplayPreferencesScope.maybeOf(context)?.isInkMode ?? false,
);

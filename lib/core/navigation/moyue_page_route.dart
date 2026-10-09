import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

/// A route remains mounted throughout its reverse animation. An old callback
/// must never pop the newly revealed route, or race a system back gesture.
void moyuePopCurrentRoute<T>(BuildContext context, [T? result]) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent || route.popGestureInProgress) return;
  Navigator.of(context).pop<T>(result);
}

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

  // One visible page transition at a time. Flutter otherwise drives a second
  // slide/fade on the revealed page via secondaryAnimation. Besides moving
  // both pages, that makes both pages' premium backdrops composite at once.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => false;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => RepaintBoundary(
    child: super.buildPage(context, animation, secondaryAnimation),
  );
}

MoyueMaterialPageRoute<T> moyuePageRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool allowSnapshotting = false,
}) => MoyueMaterialPageRoute<T>(
  builder: builder,
  allowSnapshotting: allowSnapshotting,
  predictiveBackEnabled:
      DisplayPreferencesScope.maybeOf(context)
          ?.effectivePredictiveBackEnabled ??
      true,
  reduceMotion:
      DisplayPreferencesScope.maybeOf(context)?.effectiveReduceMotion ?? false,
  inkMode: DisplayPreferencesScope.maybeOf(context)?.isInkMode ?? false,
);

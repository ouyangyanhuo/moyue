import 'dart:ui' show FontFeature, FramePhase, FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 屏幕右上角的实时帧率徽标（仅调试模式使用）。
///
/// 取相邻两帧 vsync 时间差的倒数作为瞬时帧率，再做指数平滑，
/// 让读数紧随滚动/动画实时变化；页面静止不产帧时保持最后读数，
/// 空闲超过 1 秒后的恢复首帧不计入，避免长间隔拉低均值。
/// 徽标不响应任何指针事件，不影响页面交互。
class DebugFpsOverlay extends StatefulWidget {
  const DebugFpsOverlay({super.key});

  @override
  State<DebugFpsOverlay> createState() => _DebugFpsOverlayState();
}

class _DebugFpsOverlayState extends State<DebugFpsOverlay> {
  /// 指数平滑系数：越大越灵敏，越小越稳。
  static const double _smoothing = 0.2;

  /// 相邻帧间隔超过该值视为空闲后的新序列，不参与统计。
  static const int _gapLimitMicros = 1000 * 1000;

  static const int _microsPerSecond = 1000 * 1000;

  int? _lastVsyncMicros;
  double _emaFps = 0;
  int _displayed = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final vsync = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      final last = _lastVsyncMicros;
      _lastVsyncMicros = vsync;
      if (last == null) continue;
      final delta = vsync - last;
      if (delta <= 0 || delta >= _gapLimitMicros) continue;
      final instantFps = _microsPerSecond / delta;
      _emaFps = _emaFps == 0
          ? instantFps
          : _emaFps + (instantFps - _emaFps) * _smoothing;
    }
    final fps = _emaFps.round();
    if (fps == _displayed) return;
    setState(() => _displayed = fps);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 20, 20, 20).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$_displayed FPS',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.2,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

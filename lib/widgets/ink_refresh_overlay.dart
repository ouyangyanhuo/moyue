import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class InkRefreshOverlay extends StatefulWidget {
  const InkRefreshOverlay({
    required this.enabled,
    required this.reduceMotion,
    required this.child,
    super.key,
  });

  final bool enabled;
  final bool reduceMotion;
  final Widget child;

  static const refreshDuration = Duration(milliseconds: 280);

  static InkRefreshOverlayState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InkRefreshScope>()?.state;

  @override
  State<InkRefreshOverlay> createState() => InkRefreshOverlayState();
}

class InkRefreshOverlayState extends State<InkRefreshOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: InkRefreshOverlay.refreshDuration,
  );
  Completer<void>? _activeRefresh;

  Future<void> refresh() {
    if (!widget.enabled || widget.reduceMotion) return Future<void>.value();
    final active = _activeRefresh;
    if (active != null) return active.future;
    final completer = Completer<void>();
    _activeRefresh = completer;
    _controller.forward(from: 0).whenComplete(() {
      if (!completer.isCompleted) completer.complete();
      if (identical(_activeRefresh, completer)) _activeRefresh = null;
    });
    return completer.future;
  }

  @override
  void dispose() {
    _controller.dispose();
    final active = _activeRefresh;
    if (active != null && !active.isCompleted) active.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _InkRefreshScope(
    state: this,
    child: AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final active = _controller.isAnimating;
        final theme = Theme.of(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            if (active)
              IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('ink-full-refresh-flash'),
                    painter: _InkLineRefreshPainter(
                      progress: _controller.value,
                      ink: theme.colorScheme.onSurface,
                      paper: theme.colorScheme.surface,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _InkLineRefreshPainter extends CustomPainter {
  const _InkLineRefreshPainter({
    required this.progress,
    required this.ink,
    required this.paper,
  });

  final double progress;
  final Color ink;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bandHeight = size.height * 0.08;
    final leading = progress * (size.height + bandHeight) - bandHeight;
    final bandTop = leading.clamp(-bandHeight, size.height);
    final bandBottom = (leading + bandHeight).clamp(0.0, size.height);

    if (bandBottom < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(0, bandBottom, size.width, size.height),
        Paint()..color = ink.withValues(alpha: 0.035),
      );
    }

    final trailTop = (bandTop - size.height * (40 / 280)).clamp(
      0.0,
      size.height,
    );
    if (bandTop > trailTop) {
      canvas.drawRect(
        Rect.fromLTRB(0, trailTop, size.width, bandTop),
        Paint()..color = paper.withValues(alpha: 0.08),
      );
    }

    if (bandBottom <= 0 || bandTop >= size.height) return;
    canvas.drawRect(
      Rect.fromLTRB(0, math.max(0, bandTop), size.width, bandBottom),
      Paint()..color = ink.withValues(alpha: 0.11),
    );
    final visibleHeight = math.max(1.0, bandBottom - math.max(0, bandTop));
    final linePaint = Paint()..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = math.max(0, bandTop) + visibleHeight * (index + 1) / 4;
      linePaint.color = ink.withValues(alpha: 0.2 - index * 0.045);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkLineRefreshPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ink != ink ||
      oldDelegate.paper != paper;
}

class _InkRefreshScope extends InheritedWidget {
  const _InkRefreshScope({required this.state, required super.child});

  final InkRefreshOverlayState state;

  @override
  bool updateShouldNotify(covariant _InkRefreshScope oldWidget) =>
      oldWidget.state != state;
}

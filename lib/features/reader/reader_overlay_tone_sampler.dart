import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ReaderOverlayTone {
  const ReaderOverlayTone({required this.top, required this.bottom});

  final Brightness top;
  final Brightness bottom;
}

Brightness readerSurfaceBrightness(double luminance, {Brightness? previous}) {
  final threshold = switch (previous) {
    Brightness.light => 0.43,
    Brightness.dark => 0.57,
    null => 0.5,
  };
  return luminance >= threshold ? Brightness.light : Brightness.dark;
}

/// Samples the already-painted native Flutter reader viewport at the floating
/// header and toolbar heights. Capturing at a very low pixel ratio keeps the
/// work bounded to a small image while still accounting for document colors,
/// CSS-backed native HTML blocks, and images passing below the glass controls.
class ReaderOverlayToneSampler extends StatefulWidget {
  const ReaderOverlayToneSampler({
    required this.backgroundColor,
    required this.topSampleY,
    required this.bottomSampleY,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final Color backgroundColor;
  final double topSampleY;
  final double bottomSampleY;
  final ValueChanged<ReaderOverlayTone> onChanged;
  final Widget child;

  @override
  State<ReaderOverlayToneSampler> createState() =>
      _ReaderOverlayToneSamplerState();
}

class _ReaderOverlayToneSamplerState extends State<ReaderOverlayToneSampler> {
  final GlobalKey _boundaryKey = GlobalKey();
  Timer? _timer;
  bool _sampling = false;
  bool _sampleAgain = false;
  Brightness? _topBrightness;
  Brightness? _bottomBrightness;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryAnimation;
  bool _tickersEnabled = true;

  // GPU readbacks compete with the route's glass/transition raster work.
  // Status listeners suspend sampling without adding a per-frame rebuild.
  bool get _canSample =>
      mounted &&
      _tickersEnabled &&
      (_routeAnimation == null ||
          _routeAnimation!.status == AnimationStatus.completed) &&
      (_secondaryAnimation == null ||
          _secondaryAnimation!.status == AnimationStatus.dismissed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_routeAnimation != route?.animation ||
        _secondaryAnimation != route?.secondaryAnimation) {
      _routeAnimation?.removeStatusListener(_routeStatusChanged);
      _secondaryAnimation?.removeStatusListener(_routeStatusChanged);
      _routeAnimation = route?.animation;
      _secondaryAnimation = route?.secondaryAnimation;
      _routeAnimation?.addStatusListener(_routeStatusChanged);
      _secondaryAnimation?.addStatusListener(_routeStatusChanged);
    }
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _routeStatusChanged(AnimationStatus.dismissed);
  }

  void _routeStatusChanged(AnimationStatus _) {
    if (_canSample) {
      _scheduleSample();
    } else {
      _timer?.cancel();
      _timer = null;
      _sampleAgain = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSample());
  }

  @override
  void didUpdateWidget(covariant ReaderOverlayToneSampler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.topSampleY != widget.topSampleY ||
        oldWidget.bottomSampleY != widget.bottomSampleY ||
        oldWidget.child != widget.child) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSample());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _routeAnimation?.removeStatusListener(_routeStatusChanged);
    _secondaryAnimation?.removeStatusListener(_routeStatusChanged);
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        notification is ScrollEndNotification) {
      _scheduleSample();
    }
    return false;
  }

  void _scheduleSample() {
    if (!_canSample) return;
    if (_sampling) {
      _sampleAgain = true;
      return;
    }
    if (_timer?.isActive ?? false) return;
    _timer = Timer(const Duration(milliseconds: 90), () {
      _timer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sample());
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  Future<void> _sample() async {
    if (!_canSample || _sampling) return;
    final renderObject = _boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary ||
        !renderObject.hasSize ||
        renderObject.debugNeedsPaint) {
      WidgetsBinding.instance.scheduleFrame();
      _scheduleSample();
      return;
    }
    _sampling = true;
    ui.Image? image;
    try {
      image = await renderObject.toImage(pixelRatio: 0.18);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!_canSample || data == null) return;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final logicalHeight = renderObject.size.height;
      final topLuminance = _medianLuminance(
        image,
        bytes,
        xRatios: const [0.34, 0.5, 0.66],
        yRatio: widget.topSampleY / logicalHeight,
      );
      final bottomLuminance = _medianLuminance(
        image,
        bytes,
        xRatios: const [0.1, 0.25, 0.4, 0.55],
        yRatio: widget.bottomSampleY / logicalHeight,
      );
      final top = readerSurfaceBrightness(
        topLuminance,
        previous: _topBrightness,
      );
      final bottom = readerSurfaceBrightness(
        bottomLuminance,
        previous: _bottomBrightness,
      );
      if (_topBrightness != top || _bottomBrightness != bottom) {
        _topBrightness = top;
        _bottomBrightness = bottom;
        widget.onChanged(ReaderOverlayTone(top: top, bottom: bottom));
      }
    } on Object {
      // A frame can become dirty between the check and capture. The next
      // scroll/frame schedules another bounded attempt without surfacing UI.
    } finally {
      image?.dispose();
      _sampling = false;
      if (_sampleAgain) {
        _sampleAgain = false;
        _scheduleSample();
      }
    }
  }

  double _medianLuminance(
    ui.Image image,
    Uint8List bytes, {
    required List<double> xRatios,
    required double yRatio,
  }) {
    final values = <double>[];
    for (final yOffset in const [-0.012, 0.0, 0.012]) {
      final y = ((yRatio + yOffset).clamp(0.0, 1.0) * (image.height - 1))
          .round();
      for (final ratio in xRatios) {
        final x = (ratio.clamp(0.0, 1.0) * (image.width - 1)).round();
        final offset = (y * image.width + x) * 4;
        if (offset + 3 >= bytes.length) continue;
        final alpha = bytes[offset + 3] / 255;
        final color = Color.fromARGB(
          255,
          (bytes[offset] * alpha + widget.backgroundColor.r * 255 * (1 - alpha))
              .round(),
          (bytes[offset + 1] * alpha +
                  widget.backgroundColor.g * 255 * (1 - alpha))
              .round(),
          (bytes[offset + 2] * alpha +
                  widget.backgroundColor.b * 255 * (1 - alpha))
              .round(),
        );
        values.add(color.computeLuminance());
      }
    }
    if (values.isEmpty) return widget.backgroundColor.computeLuminance();
    values.sort();
    return values[values.length ~/ 2];
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: RepaintBoundary(
          key: _boundaryKey,
          child: ColoredBox(color: widget.backgroundColor, child: widget.child),
        ),
      );
}

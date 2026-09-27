import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lightweight, stable-height placeholder until a section approaches the
/// viewport. A visited section stays mounted, preserving images and controls.
class LazyHtmlSection extends StatefulWidget {
  const LazyHtmlSection({
    required this.estimatedHeight,
    required this.builder,
    this.eager = false,
    super.key,
  });
  final double estimatedHeight;
  final WidgetBuilder builder;
  final bool eager;
  @override
  State<LazyHtmlSection> createState() => LazyHtmlSectionState();
}

class LazyHtmlSectionState extends State<LazyHtmlSection> {
  bool _loaded = false;
  bool _scheduled = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_checkLater);
      _position = position;
      if (!_loaded) _position?.addListener(_checkLater);
    }
    _checkLater();
  }

  void ensureLoaded() {
    if (!mounted || _loaded) return;
    _position?.removeListener(_checkLater);
    setState(() => _loaded = true);
  }

  void _checkLater() {
    if (_loaded || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _loaded) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      final position = _position;
      if (viewport == null ||
          position == null ||
          !position.hasContentDimensions) {
        ensureLoaded();
        return;
      }
      final start = viewport.getOffsetToReveal(box, 0).offset;
      final buffer = position.viewportDimension * 0.5;
      if (start <= position.pixels + position.viewportDimension + buffer &&
          start + box.size.height >= position.pixels - buffer) {
        ensureLoaded();
      }
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_checkLater);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.eager && !_loaded) {
      _loaded = true;
      _position?.removeListener(_checkLater);
    }
    return _loaded
        ? RepaintBoundary(child: widget.builder(context))
        : SizedBox(height: widget.estimatedHeight, width: double.infinity);
  }
}

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

/// Loads a reader image without letting its first decoded frame change layout.
///
/// The encoded dimensions are read first. Moyue then paints a placeholder with
/// the final image bounds for at least one frame, and only reveals the decoded
/// image after Flutter reports that its first frame is ready.
class StableReaderImage extends StatefulWidget {
  const StableReaderImage({
    required this.loader,
    required this.cacheKey,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.placeholderAspectRatio = 16 / 9,
    this.semanticLabel,
    this.onTap,
    this.errorBuilder,
    super.key,
  });

  final Future<Uint8List?> Function() loader;
  final Object cacheKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double placeholderAspectRatio;
  final String? semanticLabel;
  final ValueChanged<Uint8List>? onTap;
  final WidgetBuilder? errorBuilder;

  @override
  State<StableReaderImage> createState() => _StableReaderImageState();
}

class _StableReaderImageState extends State<StableReaderImage> {
  late Future<_ReaderImageData?> _future = _load();
  bool _reveal = false;
  bool _revealScheduled = false;

  @override
  void didUpdateWidget(covariant StableReaderImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) {
      _reveal = false;
      _revealScheduled = false;
      _future = _load();
    }
  }

  Future<_ReaderImageData?> _load() async {
    final bytes = await widget.loader();
    if (bytes == null || bytes.isEmpty) return null;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return _ReaderImageData(
        bytes: bytes,
        pixelWidth: descriptor.width,
        pixelHeight: descriptor.height,
      );
    } on Object {
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  void _scheduleReveal() {
    if (_reveal || _revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _reveal = true);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ReaderImageData?>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (snapshot.connectionState != ConnectionState.done) {
        return _initialPlaceholder(context);
      }
      if (data == null) {
        return widget.errorBuilder?.call(context) ??
            _initialPlaceholder(context, error: true);
      }
      // The encoded dimensions are now known, so the placeholder below is
      // already the image's final size. Reveal on the following frame; if the
      // decoder needs longer, the placeholder remains visible underneath.
      _scheduleReveal();
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = _displaySize(constraints, data);
          final image = Image.memory(
            data.bytes,
            width: size.width,
            height: size.height,
            fit: widget.fit,
            alignment: widget.alignment,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame != null || wasSynchronouslyLoaded) _scheduleReveal();
              return Stack(
                fit: StackFit.expand,
                children: [
                  _placeholder(context),
                  AnimatedOpacity(
                    key: const ValueKey('stable-reader-image-content'),
                    opacity: _reveal ? 1 : 0,
                    duration: moyueMotionDuration(
                      context,
                      const Duration(milliseconds: 120),
                    ),
                    child: child,
                  ),
                ],
              );
            },
          );
          final result = SizedBox(
            width: size.width,
            height: size.height,
            child: image,
          );
          if (widget.onTap == null) return result;
          return Semantics(
            button: true,
            image: true,
            label: widget.semanticLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTap!(data.bytes),
              child: result,
            ),
          );
        },
      );
    },
  );

  Size _displaySize(BoxConstraints constraints, _ReaderImageData data) {
    final ratio = data.pixelWidth / data.pixelHeight;
    var width = widget.width;
    var height = widget.height;
    if (width != null && !width.isFinite) width = null;
    if (height != null && !height.isFinite) height = null;

    final maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : data.pixelWidth.toDouble();
    if (width == null && height == null) {
      width = data.pixelWidth.toDouble().clamp(1, maxWidth);
      height = width / ratio;
    } else if (width == null) {
      width = height! * ratio;
      if (width > maxWidth) {
        width = maxWidth;
        height = width / ratio;
      }
    } else if (height == null) {
      width = width.clamp(1, maxWidth);
      height = width / ratio;
    }
    return constraints.constrain(Size(width, height));
  }

  Widget _initialPlaceholder(BuildContext context, {bool error = false}) {
    if (widget.width != null && widget.height != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: _placeholder(context, error: error),
      );
    }
    return AspectRatio(
      aspectRatio: widget.placeholderAspectRatio,
      child: _placeholder(context, error: error),
    );
  }

  Widget _placeholder(BuildContext context, {bool error = false}) => ColoredBox(
    key: const ValueKey('stable-reader-image-placeholder'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.62),
    child: Center(
      child: Icon(
        error ? Icons.broken_image_outlined : Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _ReaderImageData {
  const _ReaderImageData({
    required this.bytes,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final Uint8List bytes;
  final int pixelWidth;
  final int pixelHeight;
}

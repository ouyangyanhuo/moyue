import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/services/ink_image_processor.dart';
import 'package:moyue_application/widgets/missing_resource_placeholder.dart';

/// Keeps images that have already entered the viewport alive for the lifetime
/// of one reader page. The cache owns both encoded bytes and intrinsic size,
/// so a lazily rebuilt Markdown sliver can immediately reuse the same image.
class ReaderImageSessionCache {
  final Map<Object, _ReaderImageCacheEntry> _entries = {};

  _ReaderImageData? _dataFor(Object key) => _entries[key]?.data;
  Future<_ReaderImageData?>? _futureFor(Object key) => _entries[key]?.future;

  Future<_ReaderImageData?> _load(
    Object key,
    Future<_ReaderImageData?> Function() loader,
  ) {
    final existing = _entries[key];
    if (existing != null) return existing.future;
    late final _ReaderImageCacheEntry entry;
    final future = loader().then((data) {
      entry.data = data;
      return data;
    });
    entry = _ReaderImageCacheEntry(future);
    _entries[key] = entry;
    return future;
  }

  int get length => _entries.length;

  void clear() {
    for (final entry in _entries.values) {
      entry.data?.dispose();
    }
    _entries.clear();
  }
}

/// Loads a reader image without letting its first decoded frame change layout.
///
/// The encoded dimensions are read first. Moyue then paints a placeholder with
/// the final image bounds for at least one frame, and only reveals the decoded
/// image after Flutter reports that its first frame is ready.
class StableReaderImage extends StatefulWidget {
  const StableReaderImage({
    required this.loader,
    required this.cacheKey,
    this.sessionCache,
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
  final ReaderImageSessionCache? sessionCache;
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

class _StableReaderImageState extends State<StableReaderImage>
    with AutomaticKeepAliveClientMixin {
  Future<_ReaderImageData?>? _future;
  _ReaderImageData? _resolvedData;
  ScrollPosition? _scrollPosition;
  bool _hasEnteredViewport = false;
  bool _visibilityCheckScheduled = false;
  bool _reveal = false;
  bool _revealScheduled = false;

  @override
  bool get wantKeepAlive => _hasEnteredViewport;

  @override
  void initState() {
    super.initState();
    _restoreCachedImage();
    _scheduleVisibilityCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition != nextPosition) {
      _scrollPosition?.removeListener(_scheduleVisibilityCheck);
      _scrollPosition = nextPosition;
      _scrollPosition?.addListener(_scheduleVisibilityCheck);
    }
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant StableReaderImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.sessionCache != widget.sessionCache) {
      _future = null;
      _resolvedData = null;
      _hasEnteredViewport = false;
      _reveal = false;
      _revealScheduled = false;
      _restoreCachedImage();
      updateKeepAlive();
      _scheduleVisibilityCheck();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    if (widget.sessionCache == null) _resolvedData?.dispose();
    super.dispose();
  }

  void _restoreCachedImage() {
    final cache = widget.sessionCache;
    final cachedData = cache?._dataFor(widget.cacheKey);
    final cachedFuture = cache?._futureFor(widget.cacheKey);
    if (cachedData != null) {
      _resolvedData = cachedData;
      _hasEnteredViewport = true;
      _reveal = true;
      return;
    }
    if (cachedFuture != null) {
      _future = cachedFuture;
      _hasEnteredViewport = true;
    }
  }

  void _scheduleVisibilityCheck() {
    if (!mounted || _hasEnteredViewport || _visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (mounted) _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (_hasEnteredViewport) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _scheduleVisibilityCheck();
      return;
    }
    final position = _scrollPosition;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (position == null ||
        viewport == null ||
        !position.hasContentDimensions) {
      _beginLoad();
      return;
    }
    final first = viewport.getOffsetToReveal(renderObject, 0).offset;
    final last = viewport.getOffsetToReveal(renderObject, 1).offset;
    final leading = math.min(first, last);
    final trailing = math.max(first, last);
    final viewportLeading = position.pixels;
    final viewportTrailing = viewportLeading + position.viewportDimension;
    if (trailing >= viewportLeading && leading <= viewportTrailing) {
      _beginLoad();
    }
  }

  void _beginLoad() {
    if (_hasEnteredViewport) return;
    final cachedData = widget.sessionCache?._dataFor(widget.cacheKey);
    final cachedFuture = widget.sessionCache?._futureFor(widget.cacheKey);
    _hasEnteredViewport = true;
    if (cachedData != null) {
      _resolvedData = cachedData;
      _reveal = true;
    } else {
      _future =
          cachedFuture ??
          widget.sessionCache?._load(widget.cacheKey, _load) ??
          _load();
    }
    updateKeepAlive();
    if (mounted) setState(() {});
  }

  Future<_ReaderImageData?> _load() async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      final bytes = await widget.loader();
      if (bytes == null || bytes.isEmpty) return null;
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
  Widget build(BuildContext context) {
    super.build(context);
    final resolvedData = _resolvedData;
    if (resolvedData != null) return _buildResolved(context, resolvedData);
    if (!_hasEnteredViewport || _future == null) {
      return _initialPlaceholder(context);
    }
    return FutureBuilder<_ReaderImageData?>(
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
        return _buildResolved(context, data);
      },
    );
  }

  Widget _buildResolved(BuildContext context, _ReaderImageData data) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final size = _displaySize(constraints, data);
          final display = DisplayPreferencesScope.maybeOf(context);
          final inkMode = display?.isInkMode ?? false;
          final image = inkMode
              ? _buildInkImage(context, data, size)
              : Image.memory(
                  data.bytes,
                  width: size.width,
                  height: size.height,
                  fit: widget.fit,
                  alignment: widget.alignment,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      widget.errorBuilder?.call(context) ??
                      const MissingResourcePlaceholder(),
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame != null || wasSynchronouslyLoaded) {
                          _scheduleReveal();
                        }
                        return _revealStack(context, child);
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

  Widget _buildInkImage(
    BuildContext context,
    _ReaderImageData data,
    Size size,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    int bucket(double logical) =>
        (((logical * pixelRatio).ceil() + 63) ~/ 64 * 64).clamp(64, 1280);
    return FutureBuilder<ui.Image?>(
      future: data.inkImage(
        dark: dark,
        targetPixelWidth: bucket(size.width),
        targetPixelHeight: bucket(size.height),
      ),
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) {
          return _placeholder(
            context,
            error: snapshot.connectionState == ConnectionState.done,
          );
        }
        _scheduleReveal();
        return _revealStack(
          context,
          RawImage(
            image: image,
            width: size.width,
            height: size.height,
            fit: widget.fit,
            alignment: widget.alignment,
            filterQuality: FilterQuality.medium,
          ),
        );
      },
    );
  }

  Widget _revealStack(BuildContext context, Widget child) => Stack(
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
    child: error
        ? const MissingResourcePlaceholder()
        : Center(
            child: Icon(
              error ? Icons.broken_image_outlined : Icons.image_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
  );
}

class _ReaderImageData {
  _ReaderImageData({
    required this.bytes,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final Uint8List bytes;
  final int pixelWidth;
  final int pixelHeight;
  final Map<String, Future<ui.Image?>> _inkImages = {};
  final Set<ui.Image> _resolvedInkImages = {};
  bool _disposed = false;

  Future<ui.Image?> inkImage({
    required bool dark,
    required int targetPixelWidth,
    required int targetPixelHeight,
  }) {
    final key = '$dark:$targetPixelWidth:$targetPixelHeight';
    final existing = _inkImages[key];
    if (existing != null) return existing;
    final future =
        InkImageProcessor.process(
          bytes,
          dark: dark,
          targetPixelWidth: targetPixelWidth,
          targetPixelHeight: targetPixelHeight,
        ).then((image) {
          if (_disposed) {
            image?.dispose();
            return null;
          }
          if (image != null) _resolvedInkImages.add(image);
          return image;
        });
    _inkImages[key] = future;
    return future;
  }

  void dispose() {
    _disposed = true;
    for (final image in _resolvedInkImages) {
      image.dispose();
    }
    _resolvedInkImages.clear();
    _inkImages.clear();
  }
}

class _ReaderImageCacheEntry {
  _ReaderImageCacheEntry(this.future);

  final Future<_ReaderImageData?> future;
  _ReaderImageData? data;
}

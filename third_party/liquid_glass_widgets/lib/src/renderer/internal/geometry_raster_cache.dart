import 'package:flutter/rendering.dart';

/// Tracks only local geometry, never backdrop pixels or global page position.
/// Exact comparisons preserve subpixel deformation and full-DPR rendering.
class GeometryRasterCache {
  List<(Object, Object, Matrix4)> _entries = const [];
  Rect? _bounds;
  double? _pixelRatio;

  bool matches(
    List<(Object, Object, Matrix4)> entries,
    Rect bounds,
    double pixelRatio,
  ) {
    if (_bounds != bounds ||
        _pixelRatio != pixelRatio ||
        entries.length != _entries.length) {
      return false;
    }
    for (var i = 0; i < entries.length; i++) {
      final old = _entries[i];
      final next = entries[i];
      if (!identical(old.$1, next.$1) || !identical(old.$2, next.$2)) {
        return false;
      }
      for (var j = 0; j < 16; j++) {
        if (old.$3.storage[j] != next.$3.storage[j]) return false;
      }
    }
    return true;
  }

  void record(
      List<(Object, Object, Matrix4)> entries, Rect bounds, double pixelRatio) {
    _entries = [for (final e in entries) (e.$1, e.$2, Matrix4.copy(e.$3))];
    _bounds = bounds;
    _pixelRatio = pixelRatio;
  }

  void clear() {
    _entries = const [];
    _bounds = null;
    _pixelRatio = null;
  }
}

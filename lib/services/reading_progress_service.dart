import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only reading history. No document content, title or path is stored.
class ReadingProgress {
  const ReadingProgress({
    required this.offset,
    required this.extent,
    required this.layout,
    required this.textScale,
  });

  final double offset;
  final double extent;
  final String layout;
  final double textScale;

  double get fraction => extent > 0 ? (offset / extent).clamp(0, 1) : 0;

  double target(double currentExtent, String currentLayout) =>
      (layout == currentLayout ? offset : fraction * currentExtent).clamp(
        0,
        currentExtent,
      );

  String encode() => jsonEncode({
    'version': 1,
    'offset': offset,
    'extent': extent,
    'layout': layout,
    'textScale': textScale,
    'savedAt': DateTime.now().toUtc().toIso8601String(),
  });

  static ReadingProgress? decode(String? source) {
    if (source == null) return null;
    try {
      final data = jsonDecode(source);
      if (data is! Map || data['version'] != 1 || data['layout'] is! String) {
        return null;
      }
      final offset = data['offset'];
      final extent = data['extent'];
      final scale = data['textScale'];
      if (offset is! num ||
          extent is! num ||
          scale is! num ||
          !offset.isFinite ||
          !extent.isFinite ||
          !scale.isFinite ||
          offset < 0 ||
          extent < 0 ||
          scale < 0.8 ||
          scale > 1.4) {
        return null;
      }
      return ReadingProgress(
        offset: offset.toDouble().clamp(0, extent.toDouble()),
        extent: extent.toDouble(),
        layout: data['layout'] as String,
        textScale: scale.toDouble(),
      );
    } on Object {
      return null;
    }
  }
}

class ReadingProgressService {
  static final instance = ReadingProgressService();
  SharedPreferencesAsync get _store => SharedPreferencesAsync();
  Future<void>? _writes;

  static String keyFor(String documentId) =>
      'reader.progress.v1.${Uri.encodeComponent(documentId)}';

  Future<ReadingProgress?> read(String documentId) async {
    // Opening immediately after closing must see the final pending write.
    await _writes;
    try {
      return ReadingProgress.decode(await _store.getString(keyFor(documentId)));
    } on Object {
      return null;
    }
  }

  Future<void> save(String documentId, ReadingProgress progress) {
    final value = progress.encode();
    final write = (_writes ?? Future<void>.value()).then((_) async {
      try {
        await _store.setString(keyFor(documentId), value);
      } on Object {
        // A temporarily unavailable preference store must not stop reading.
      }
    });
    _writes = write;
    return write.whenComplete(() {
      if (identical(_writes, write)) _writes = null;
    });
  }
}

/// Throttle continuous scrolling, then flush on scroll-end/background/exit.
class ReadingProgressSession {
  ReadingProgressSession(this.documentId, this.service);

  final String documentId;
  final ReadingProgressService service;
  ReadingProgress? _pending;
  Timer? _timer;

  void record(ReadingProgress value) {
    _pending = value;
    _timer ??= Timer(
      const Duration(milliseconds: 800),
      () => unawaited(flush()),
    );
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null) await service.save(documentId, pending);
  }

  void dispose() => unawaited(flush());
}

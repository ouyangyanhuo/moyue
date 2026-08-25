import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Converts the first frame of an image into a deterministic, 16-tone green
/// LCD/e-paper rendering. Decode stays on Flutter's image pipeline while all
/// pixel quantization is serialized through one long-lived worker isolate.
class InkImageProcessor {
  const InkImageProcessor._();

  static Future<ui.Image?> process(
    Uint8List encodedBytes, {
    required bool dark,
    int maximumDimension = 1280,
    int? targetPixelWidth,
    int? targetPixelHeight,
  }) async {
    ui.ImmutableBuffer? encodedBuffer;
    ui.ImageDescriptor? encodedDescriptor;
    ui.Codec? codec;
    ui.Image? source;
    try {
      encodedBuffer = await ui.ImmutableBuffer.fromUint8List(encodedBytes);
      encodedDescriptor = await ui.ImageDescriptor.encoded(encodedBuffer);
      final widthLimit = math.min(
        maximumDimension,
        targetPixelWidth ?? maximumDimension,
      );
      final heightLimit = math.min(
        maximumDimension,
        targetPixelHeight ?? maximumDimension,
      );
      final scale = math.min(
        1.0,
        math.min(
          widthLimit / encodedDescriptor.width,
          heightLimit / encodedDescriptor.height,
        ),
      );
      final targetWidth = (encodedDescriptor.width * scale).round().clamp(
        1,
        maximumDimension,
      );
      final targetHeight = (encodedDescriptor.height * scale).round().clamp(
        1,
        maximumDimension,
      );
      codec = await encodedDescriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      source = frame.image;
      final byteData = await source.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;
      final transformed = await _InkPixelWorker.instance.transform(
        pixels: TransferableTypedData.fromList([
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        ]),
        dark: dark,
        width: source.width,
      );
      final rawBuffer = await ui.ImmutableBuffer.fromUint8List(transformed);
      try {
        final descriptor = ui.ImageDescriptor.raw(
          rawBuffer,
          width: source.width,
          height: source.height,
          rowBytes: source.width * 4,
          pixelFormat: ui.PixelFormat.rgba8888,
        );
        try {
          final resultCodec = await descriptor.instantiateCodec();
          try {
            return (await resultCodec.getNextFrame()).image;
          } finally {
            resultCodec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        rawBuffer.dispose();
      }
    } on Object {
      return null;
    } finally {
      source?.dispose();
      codec?.dispose();
      encodedDescriptor?.dispose();
      encodedBuffer?.dispose();
    }
  }
}

class _InkPixelWorker {
  _InkPixelWorker._();

  static final instance = _InkPixelWorker._();

  final ReceivePort _receivePort = ReceivePort();
  final Map<int, Completer<Uint8List>> _requests = {};
  Future<void>? _startup;
  SendPort? _sendPort;
  int _nextRequest = 1;

  Future<Uint8List> transform({
    required TransferableTypedData pixels,
    required bool dark,
    required int width,
  }) async {
    await (_startup ??= _start());
    final id = _nextRequest++;
    final completer = Completer<Uint8List>();
    _requests[id] = completer;
    _sendPort!.send([id, pixels, dark, width]);
    return completer.future;
  }

  Future<void> _start() async {
    final ready = Completer<void>();
    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        if (!ready.isCompleted) ready.complete();
        return;
      }
      if (message is! List || message.length < 2) return;
      final id = message[0] as int;
      final completer = _requests.remove(id);
      if (completer == null) return;
      final result = message[1];
      if (result is TransferableTypedData) {
        completer.complete(result.materialize().asUint8List());
      } else {
        completer.completeError(StateError('Ink image worker failed'));
      }
    });
    await Isolate.spawn(_inkPixelWorkerMain, _receivePort.sendPort);
    await ready.future;
  }
}

void _inkPixelWorkerMain(SendPort output) {
  final input = ReceivePort();
  output.send(input.sendPort);
  input.listen((message) {
    if (message is! List || message.length != 4) return;
    final id = message[0] as int;
    try {
      final transformed = _quantizeInkPixels(
        _InkPixelPayload(
          pixels: message[1] as TransferableTypedData,
          dark: message[2] as bool,
          width: message[3] as int,
        ),
      );
      output.send([
        id,
        TransferableTypedData.fromList([transformed]),
      ]);
    } on Object {
      output.send([id, null]);
    }
  });
}

class _InkPixelPayload {
  const _InkPixelPayload({
    required this.pixels,
    required this.dark,
    required this.width,
  });

  final TransferableTypedData pixels;
  final bool dark;
  final int width;
}

Uint8List _quantizeInkPixels(_InkPixelPayload payload) {
  final pixels = payload.pixels.materialize().asUint8List();
  const bayer = <int>[0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
  const greenRamp = <int>[
    0xFF223020,
    0xFF2D3B28,
    0xFF384631,
    0xFF425039,
    0xFF4D5B42,
    0xFF58664A,
    0xFF637153,
    0xFF6E7C5B,
    0xFF788664,
    0xFF83916C,
    0xFF8E9C75,
    0xFF99A77D,
    0xFFA4B286,
    0xFFAEBC8E,
    0xFFB9C797,
    0xFFC4D29F,
  ];
  for (var offset = 0; offset + 3 < pixels.length; offset += 4) {
    final pixel = offset ~/ 4;
    final x = pixel % payload.width;
    final y = pixel ~/ payload.width;
    final luminance =
        pixels[offset] * 0.2126 +
        pixels[offset + 1] * 0.7152 +
        pixels[offset + 2] * 0.0722;
    final threshold = (bayer[(y & 3) * 4 + (x & 3)] - 7.5) / 16;
    var level = ((luminance / 255 * 15) + threshold).round().clamp(0, 15);
    if (payload.dark) level = 15 - level;
    final color = greenRamp[level];
    pixels[offset] = (color >> 16) & 0xFF;
    pixels[offset + 1] = (color >> 8) & 0xFF;
    pixels[offset + 2] = color & 0xFF;
  }
  return pixels;
}

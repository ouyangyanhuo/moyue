import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/services/ink_image_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('墨主题使用系统衬线字体和16级中性纸墨色阶', () {
    final theme = buildMoyueTheme(
      inkMode: true,
      brightness: Brightness.light,
      seedColor: Colors.green,
      fontFamily: MoyueFontFamily.ink,
    );
    final ink = theme.extension<MoyueInkTheme>();
    expect(theme.textTheme.bodyLarge?.fontFamily, isNot('Source Han Serif SC'));
    expect(ink?.enabled, isTrue);
    expect(ink?.grayRamp, hasLength(16));
    expect(ink?.grayRamp.first, const Color(0xFF1E201C));
    expect(ink?.grayRamp.last, const Color(0xFFDFE0D1));
    expect(theme.colorScheme.primary, isNot(Colors.green));
    expect(theme.splashFactory, NoSplash.splashFactory);
    final allowed = ink!.grayRamp.map((color) => color.toARGB32()).toSet();
    final scheme = theme.colorScheme;
    expect(
      <Color>[
        scheme.primary,
        scheme.onPrimary,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primaryFixed,
        scheme.primaryFixedDim,
        scheme.secondary,
        scheme.secondaryContainer,
        scheme.tertiary,
        scheme.tertiaryContainer,
        scheme.error,
        scheme.errorContainer,
        scheme.surface,
        scheme.onSurface,
        scheme.surfaceDim,
        scheme.surfaceBright,
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
        scheme.outline,
        scheme.outlineVariant,
        scheme.inverseSurface,
        scheme.inversePrimary,
        scheme.surfaceTint,
      ].map((color) => color.toARGB32()),
      everyElement(isIn(allowed)),
    );
  });

  test('墨模式不再打包字体且纸纹资源保持轻量', () {
    expect(File('assets/fonts/SourceHanSerifSC-VF.ttf').existsSync(), isFalse);
    final texture = File('assets/textures/ink_paper_fibers.png');
    expect(texture.existsSync(), isTrue);
    expect(texture.lengthSync(), lessThan(150 * 1024));
  });

  test('图片处理生成不超过16个墨色并保持原始字节', () async {
    final source = Uint8List(16 * 4);
    for (var index = 0; index < 16; index++) {
      final value = (index * 17).clamp(0, 255);
      source[index * 4] = value;
      source[index * 4 + 1] = value;
      source[index * 4 + 2] = value;
      source[index * 4 + 3] = 255;
    }
    final encoded = await _encodeRgba(source, width: 4, height: 4);
    final original = Uint8List.fromList(encoded);
    final processed = await InkImageProcessor.process(encoded, dark: false);
    expect(processed, isNotNull);
    final raw = await processed!.toByteData(format: ui.ImageByteFormat.rawRgba);
    final colors = <int>{};
    final allowed = moyueInkGrayRamp
        .map((color) => color.toARGB32() & 0xFFFFFF)
        .toSet();
    final pixels = raw!.buffer.asUint8List(
      raw.offsetInBytes,
      raw.lengthInBytes,
    );
    for (var offset = 0; offset < pixels.length; offset += 4) {
      colors.add(
        (pixels[offset] << 16) | (pixels[offset + 1] << 8) | pixels[offset + 2],
      );
    }
    expect(colors.length, lessThanOrEqualTo(16));
    expect(colors.difference(allowed), isEmpty);
    expect(encoded, orderedEquals(original));
    processed.dispose();
  });
}

Future<Uint8List> _encodeRgba(
  Uint8List rgba, {
  required int width,
  required int height,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  try {
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      rowBytes: width * 4,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    try {
      final codec = await descriptor.instantiateCodec();
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

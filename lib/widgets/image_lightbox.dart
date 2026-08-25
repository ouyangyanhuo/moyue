import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:moyue_application/services/ink_image_processor.dart';

/// 全屏图片灯箱：双指/双击缩放、拖拽平移，点按空白或关闭按钮退出。
class ImageLightbox extends StatefulWidget {
  const ImageLightbox({required this.bytes, super.key});

  final Uint8List bytes;

  /// 使用不透明标准路由，避免 Android 预见性返回时透明路由的两份图片
  /// 同时参与合成而闪烁。
  static Future<void> show(BuildContext context, Uint8List bytes) {
    return Navigator.of(context).push(
      moyuePageRoute<void>(
        context: context,
        allowSnapshotting: false,
        builder: (_) => ImageLightbox(bytes: bytes),
      ),
    );
  }

  @override
  State<ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<ImageLightbox> {
  static const double _maxScale = 5;

  final TransformationController _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;
  Future<ui.Image?>? _inkFuture;
  ui.Image? _inkImage;
  bool? _inkDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final display = DisplayPreferencesScope.maybeOf(context);
    if (!(display?.isInkMode ?? false)) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_inkFuture != null && _inkDark == dark) return;
    _inkImage?.dispose();
    _inkImage = null;
    _inkDark = dark;
    final size = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    _inkFuture =
        InkImageProcessor.process(
          widget.bytes,
          dark: dark,
          maximumDimension: 2048,
          targetPixelWidth: (size.width * pixelRatio).ceil().clamp(1, 2048),
          targetPixelHeight: (size.height * pixelRatio).ceil().clamp(1, 2048),
        ).then((image) {
          if (!mounted) {
            image?.dispose();
          } else {
            _inkImage = image;
          }
          return image;
        });
  }

  @override
  void dispose() {
    _transform.dispose();
    _inkImage?.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final targetScale = _maxScale * 0.6;
    if (_transform.value != Matrix4.identity()) {
      _transform.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition;
    if (position == null) {
      _transform.value = Matrix4.identity()
        ..scaleByDouble(targetScale, targetScale, 1, 1);
      return;
    }
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (targetScale - 1),
        -position.dy * (targetScale - 1),
        0,
        1,
      )
      ..scaleByDouble(targetScale, targetScale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final inkMode =
        DisplayPreferencesScope.maybeOf(context)?.isInkMode ?? false;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: inkMode ? colors.surface : Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transform,
                maxScale: _maxScale,
                child: Center(child: RepaintBoundary(child: _image(inkMode))),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: inkMode ? colors.onSurface : Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: context.l10n.close,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(bool inkMode) {
    if (!inkMode) {
      return Image.memory(
        widget.bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    return FutureBuilder<ui.Image?>(
      future: _inkFuture,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        return RawImage(image: image, fit: BoxFit.contain);
      },
    );
  }
}

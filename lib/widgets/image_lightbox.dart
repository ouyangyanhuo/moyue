import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 全屏图片灯箱：双指/双击缩放、拖拽平移，点按空白或关闭按钮退出。
class ImageLightbox extends StatefulWidget {
  const ImageLightbox({required this.bytes, super.key});

  final Uint8List bytes;

  /// 以淡入淡出的全屏路由打开灯箱。
  static Future<void> show(BuildContext context, Uint8List bytes) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: ImageLightbox(bytes: bytes),
        ),
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

  @override
  void dispose() {
    _transform.dispose();
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
    return Scaffold(
      backgroundColor: Colors.black,
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
                child: Center(
                  child: Image.memory(widget.bytes, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '关闭',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

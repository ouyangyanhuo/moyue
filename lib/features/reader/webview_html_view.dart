import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:moyue_application/features/reader/reader_overlay_tone_sampler.dart';
import 'package:moyue_application/services/webview_document_builder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Android must remain on Texture Layer Hybrid Composition so WebView pixels
/// participate in the same Flutter/Impeller scene sampled by premium glass.
@visibleForTesting
const bool moyueWebViewDisplayWithHybridComposition = false;

class WebViewHtmlView extends StatefulWidget {
  const WebViewHtmlView({
    required this.data,
    required this.resourceLoader,
    required this.topInset,
    required this.bottomInset,
    required this.textScale,
    required this.fallbackSurfaceColor,
    this.onOverlayBrightnessChanged,
    super.key,
  });

  final String data;
  final Future<Uint8List?> Function(String source) resourceLoader;
  final double topInset;
  final double bottomInset;
  final double textScale;
  final Color fallbackSurfaceColor;
  final ValueChanged<ReaderOverlayTone>? onOverlayBrightnessChanged;

  @override
  State<WebViewHtmlView> createState() => WebViewHtmlViewState();
}

class WebViewHtmlViewState extends State<WebViewHtmlView> {
  static const _surfaceToneChannel = 'MoyueSurfaceTone';

  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  Brightness? _topSurfaceBrightness;
  Brightness? _bottomSurfaceBrightness;

  bool get _supported =>
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant WebViewHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.topInset != widget.topInset ||
        oldWidget.bottomInset != widget.bottomInset) {
      unawaited(_load());
    } else if (oldWidget.textScale != widget.textScale) {
      unawaited(_applyTextScale());
    } else if (oldWidget.fallbackSurfaceColor != widget.fallbackSurfaceColor) {
      unawaited(_installSurfaceToneObserver());
    }
  }

  Future<bool> scrollToHeading(int index) async {
    final controller = _controller;
    if (controller == null) return false;
    await controller.runJavaScript('''
(() => {
  const heading = document.querySelectorAll('h1,h2,h3,h4,h5,h6')[$index];
  if (heading) heading.scrollIntoView({behavior: 'smooth', block: 'start'});
})();
''');
    return true;
  }

  Future<void> _load() async {
    if (!_supported) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.l10n.unsupportedWebViewPlatform;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final html = await WebViewDocumentBuilder.build(
        html: widget.data,
        resourceLoader: widget.resourceLoader,
        topInset: widget.topInset,
        bottomInset: widget.bottomInset,
      );
      if (!mounted) return;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          _surfaceToneChannel,
          onMessageReceived: _handleSurfaceTone,
        )
        ..setVerticalScrollBarEnabled(false)
        ..setHorizontalScrollBarEnabled(false)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (!mounted) return;
              unawaited(_applyTextScale());
              unawaited(_installSurfaceToneObserver());
              setState(() => _loading = false);
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame != true || !mounted) return;
              setState(() {
                _loading = false;
                _error = error.description;
              });
            },
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              if (uri == null ||
                  uri.scheme == 'data' ||
                  uri.scheme == 'about' ||
                  uri.scheme.isEmpty) {
                return NavigationDecision.navigate;
              }
              unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
              return NavigationDecision.prevent;
            },
          ),
        );
      _controller = controller;
      await controller.loadHtmlString(html);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _applyTextScale() async {
    final controller = _controller;
    if (controller == null) return;
    final percent = (widget.textScale * 100).round();
    try {
      await controller.runJavaScript(
        "document.documentElement.style.fontSize = '$percent%';",
      );
    } on Object {
      // 页面仍在创建时 onPageFinished 会再次应用。
    }
  }

  void _handleSurfaceTone(JavaScriptMessage message) {
    if (!mounted) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final topLuminance = (decoded['top'] as num?)?.toDouble();
    final bottomLuminance = (decoded['bottom'] as num?)?.toDouble();
    if (topLuminance == null ||
        bottomLuminance == null ||
        !topLuminance.isFinite ||
        !bottomLuminance.isFinite) {
      return;
    }
    final top = webViewSurfaceBrightness(
      topLuminance.clamp(0, 1),
      previous: _topSurfaceBrightness,
    );
    final bottom = webViewSurfaceBrightness(
      bottomLuminance.clamp(0, 1),
      previous: _bottomSurfaceBrightness,
    );
    if (_topSurfaceBrightness == top && _bottomSurfaceBrightness == bottom) {
      return;
    }
    _topSurfaceBrightness = top;
    _bottomSurfaceBrightness = bottom;
    widget.onOverlayBrightnessChanged?.call(
      ReaderOverlayTone(top: top, bottom: bottom),
    );
  }

  Future<void> _installSurfaceToneObserver() async {
    final controller = _controller;
    if (controller == null) return;
    final fallback = widget.fallbackSurfaceColor;
    final fallbackRed = (fallback.r * 255).round();
    final fallbackGreen = (fallback.g * 255).round();
    final fallbackBlue = (fallback.b * 255).round();
    final sampleY = (widget.topInset - 43).clamp(1, 10000).toStringAsFixed(1);
    final bottomOffset = (widget.bottomInset - 48)
        .clamp(1, 10000)
        .toStringAsFixed(1);
    try {
      await controller.runJavaScript('''
(() => {
  window.__moyueSurfaceToneCleanup?.();
  const channel = window.$_surfaceToneChannel;
  if (!channel || typeof channel.postMessage !== 'function') return;
  const fallback = [$fallbackRed, $fallbackGreen, $fallbackBlue, 1];
  let frame = 0;
  let lastTop = -1;
  let lastBottom = -1;

  const parseColor = (value) => {
    if (!value || value === 'transparent') return null;
    const match = value.match(
      /rgba?\\(\\s*([\\d.]+)[,\\s]+([\\d.]+)[,\\s]+([\\d.]+)(?:[,\\s\\/]+([\\d.]+))?\\s*\\)/i
    );
    if (!match) return null;
    return [
      Number(match[1]),
      Number(match[2]),
      Number(match[3]),
      match[4] == null ? 1 : Number(match[4]),
    ];
  };
  const over = (front, back) => {
    if (!front || front[3] <= 0) return back;
    const alpha = front[3] + back[3] * (1 - front[3]);
    if (alpha <= 0) return [0, 0, 0, 0];
    return [
      (front[0] * front[3] + back[0] * back[3] * (1 - front[3])) / alpha,
      (front[1] * front[3] + back[1] * back[3] * (1 - front[3])) / alpha,
      (front[2] * front[3] + back[2] * back[3] * (1 - front[3])) / alpha,
      alpha,
    ];
  };
  const gradientColor = (image) => {
    if (!image || image === 'none' || !image.includes('gradient')) return null;
    const matches = image.match(/rgba?\\([^)]*\\)/gi) || [];
    const colors = matches.map(parseColor).filter(Boolean);
    if (!colors.length) return null;
    return colors.reduce(
      (sum, color) => [
        sum[0] + color[0] / colors.length,
        sum[1] + color[1] / colors.length,
        sum[2] + color[2] / colors.length,
        sum[3] + color[3] / colors.length,
      ],
      [0, 0, 0, 0]
    );
  };
  const colorAt = (x, y) => {
    const layers = [];
    let element = document.elementFromPoint(x, y);
    while (element) {
      const style = getComputedStyle(element);
      const solid = parseColor(style.backgroundColor);
      const gradient = gradientColor(style.backgroundImage);
      if (gradient) layers.push(gradient);
      if (solid) layers.push(solid);
      element = element.parentElement;
    }
    let color = fallback;
    for (let index = layers.length - 1; index >= 0; index -= 1) {
      color = over(layers[index], color);
    }
    return color;
  };
  const linear = (value) => {
    value /= 255;
    return value <= 0.04045
      ? value / 12.92
      : Math.pow((value + 0.055) / 1.055, 2.4);
  };
  const luminanceAt = (y, ratios) => {
    const colors = ratios.map((ratio) =>
      colorAt(innerWidth * ratio, y)
    );
    return colors.reduce(
      (sum, color) =>
        sum +
        0.2126 * linear(color[0]) +
        0.7152 * linear(color[1]) +
        0.0722 * linear(color[2]),
      0
    ) / colors.length;
  };
  const report = () => {
    frame = 0;
    const topY = Math.max(1, Math.min(innerHeight - 1, $sampleY));
    const bottomY = Math.max(
      1,
      Math.min(innerHeight - 1, innerHeight - $bottomOffset)
    );
    const top = luminanceAt(topY, [0.34, 0.5, 0.66]);
    const bottom = luminanceAt(bottomY, [0.1, 0.25, 0.4, 0.55]);
    if (
      lastTop < 0 ||
      Math.abs(top - lastTop) >= 0.025 ||
      Math.abs(bottom - lastBottom) >= 0.025
    ) {
      lastTop = top;
      lastBottom = bottom;
      channel.postMessage(JSON.stringify({top, bottom}));
    }
  };
  const schedule = () => {
    if (!frame) frame = requestAnimationFrame(report);
  };
  addEventListener('scroll', schedule, {passive: true, capture: true});
  addEventListener('resize', schedule, {passive: true});
  const observer = new MutationObserver(schedule);
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class', 'style'],
    childList: true,
    subtree: true,
  });
  window.__moyueSurfaceToneCleanup = () => {
    removeEventListener('scroll', schedule, true);
    removeEventListener('resize', schedule);
    observer.disconnect();
    if (frame) cancelAnimationFrame(frame);
  };
  schedule();
  setTimeout(schedule, 120);
})();
''');
    } on Object {
      // 页面脚本仍在初始化时，后续滚动或重新加载会再次安装。
    }
  }

  Widget _buildWebView(WebViewController controller) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform,
          // Keep WebView pixels inside Flutter's texture composition. Enabling
          // legacy Hybrid Composition (or the app-wide HCPP opt-in) moves them
          // to a separate native surface that premium glass cannot sample.
          displayWithHybridComposition:
              moyueWebViewDisplayWithHybridComposition,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null) _buildWebView(controller),
        if (_error case final error?)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(error, textAlign: TextAlign.center),
              ),
            ),
          )
        else if (_loading)
          const Center(child: CircularProgressIndicator.adaptive()),
      ],
    );
  }
}

@visibleForTesting
Brightness webViewSurfaceBrightness(double luminance, {Brightness? previous}) =>
    readerSurfaceBrightness(luminance, previous: previous);

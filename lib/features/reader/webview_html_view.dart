import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moyue_application/services/webview_document_builder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewHtmlView extends StatefulWidget {
  const WebViewHtmlView({
    required this.data,
    required this.resourceLoader,
    required this.topInset,
    required this.bottomInset,
    required this.textScale,
    super.key,
  });

  final String data;
  final Future<Uint8List?> Function(String source) resourceLoader;
  final double topInset;
  final double bottomInset;
  final double textScale;

  @override
  State<WebViewHtmlView> createState() => WebViewHtmlViewState();
}

class WebViewHtmlViewState extends State<WebViewHtmlView> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

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
          _error = '当前平台不支持系统 WebView，请关闭设置中的 WebView 阅读器。';
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
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (!mounted) return;
              unawaited(_applyTextScale());
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null) WebViewWidget(controller: controller),
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

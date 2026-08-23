import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:moyue_application/services/text_decoder.dart';
import 'package:path/path.dart' as p;

/// 为 WebView 构造一个自包含 HTML 页面。
///
/// 导入包仍存放在应用数据目录；这里把包内 CSS、JS、图片和视频转换为
/// data URI，使系统 WebView 在 SAF/应用私有目录规则下也能得到与源包一致
/// 的相对资源，并保留原始 JavaScript 行为。
class WebViewDocumentBuilder {
  const WebViewDocumentBuilder._();

  static Future<String> build({
    required String html,
    required Future<Uint8List?> Function(String source) resourceLoader,
    required double topInset,
    required double bottomInset,
  }) async {
    final document = html_parser.parse(html);
    final existingHead = document.head;
    final head = existingHead ?? Element.tag('head');
    if (existingHead == null) {
      document.documentElement?.insertBefore(head, document.body);
    }

    if (document.querySelector('meta[name="viewport"]') == null) {
      head.append(
        Element.tag('meta')
          ..attributes['name'] = 'viewport'
          ..attributes['content'] =
              'width=device-width, initial-scale=1, viewport-fit=cover',
      );
    }
    head.append(
      Element.tag('style')
        ..text =
            '''
html { background: transparent; }
body {
  box-sizing: border-box;
  padding-top: ${topInset.toStringAsFixed(1)}px !important;
  padding-bottom: ${bottomInset.toStringAsFixed(1)}px !important;
}
img, video { max-width: 100%; }
''',
    );

    for (final link in document.querySelectorAll('link[href]').toList()) {
      final rel = link.attributes['rel']?.toLowerCase() ?? '';
      if (!rel.split(RegExp(r'\s+')).contains('stylesheet')) continue;
      final source = link.attributes['href']!;
      if (!_isLocal(source)) continue;
      final bytes = await resourceLoader(source);
      if (bytes == null) continue;
      final css = await _rewriteCssUrls(
        decodeImportedText(bytes),
        basePath: source,
        resourceLoader: resourceLoader,
      );
      link.attributes['href'] = _dataUri(
        Uint8List.fromList(utf8.encode(css)),
        'text/css',
      );
    }

    for (final script in document.querySelectorAll('script[src]').toList()) {
      final source = script.attributes['src']!;
      if (!_isLocal(source)) continue;
      final bytes = await resourceLoader(source);
      if (bytes != null) {
        script.attributes['src'] = _dataUri(bytes, 'text/javascript');
      }
    }

    for (final style in document.querySelectorAll('style')) {
      style.text = await _rewriteCssUrls(
        style.text,
        basePath: '',
        resourceLoader: resourceLoader,
      );
    }
    for (final element in document.querySelectorAll('[style]')) {
      element.attributes['style'] = await _rewriteCssUrls(
        element.attributes['style']!,
        basePath: '',
        resourceLoader: resourceLoader,
      );
    }

    for (final element in document.querySelectorAll('[src], [poster]')) {
      for (final attribute in const ['src', 'poster']) {
        final source = element.attributes[attribute];
        if (source == null || !_isLocal(source)) continue;
        final bytes = await resourceLoader(source);
        if (bytes != null) {
          element.attributes[attribute] = _dataUri(bytes, _mimeType(source));
        }
      }
    }
    return document.outerHtml;
  }

  static Future<String> _rewriteCssUrls(
    String css, {
    required String basePath,
    required Future<Uint8List?> Function(String source) resourceLoader,
  }) async {
    final expression = RegExp(
      r'''url\(\s*(["']?)([^"')]+)\1\s*\)''',
      caseSensitive: false,
    );
    final matches = expression.allMatches(css).toList(growable: false);
    if (matches.isEmpty) return css;
    final buffer = StringBuffer();
    var offset = 0;
    for (final match in matches) {
      buffer.write(css.substring(offset, match.start));
      final raw = match.group(2)!.trim();
      if (!_isLocal(raw)) {
        buffer.write(match.group(0));
      } else {
        final resolved = basePath.isEmpty
            ? raw
            : p.posix.normalize(p.posix.join(p.posix.dirname(basePath), raw));
        final bytes = await resourceLoader(resolved);
        if (bytes == null) {
          buffer.write(match.group(0));
        } else {
          buffer.write('url("${_dataUri(bytes, _mimeType(resolved))}")');
        }
      }
      offset = match.end;
    }
    buffer.write(css.substring(offset));
    return buffer.toString();
  }

  static bool _isLocal(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('#') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('/')) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    return uri != null && !uri.hasScheme;
  }

  static String _dataUri(Uint8List bytes, String mimeType) =>
      'data:$mimeType;base64,${base64Encode(bytes)}';

  static String _mimeType(String source) {
    final extension = p
        .extension(Uri.tryParse(source)?.path ?? source)
        .toLowerCase();
    return switch (extension) {
      '.css' => 'text/css',
      '.js' => 'text/javascript',
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.svg' => 'image/svg+xml',
      '.avif' => 'image/avif',
      '.bmp' => 'image/bmp',
      '.ico' => 'image/x-icon',
      '.mp4' => 'video/mp4',
      '.webm' => 'video/webm',
      '.mov' => 'video/quicktime',
      '.m4v' => 'video/x-m4v',
      '.ogv' => 'video/ogg',
      _ => 'application/octet-stream',
    };
  }
}

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
    String missingResourceLabel = '引用的资源不存在',
  }) async {
    final resourceCache = <String, Future<Uint8List?>>{};
    Future<Uint8List?> loadResource(String source) =>
        resourceCache.putIfAbsent(source, () async {
          try {
            final bytes = await resourceLoader(source);
            return bytes == null || bytes.isEmpty ? null : bytes;
          } on Object {
            return null;
          }
        });
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
html {
  background: transparent;
  scrollbar-width: none;
  -ms-overflow-style: none;
}
html::-webkit-scrollbar,
body::-webkit-scrollbar {
  width: 0 !important;
  height: 0 !important;
  display: none !important;
}
body {
  box-sizing: border-box;
  padding-top: ${topInset.toStringAsFixed(1)}px !important;
  padding-bottom: ${bottomInset.toStringAsFixed(1)}px !important;
}
img, video { max-width: 100%; }
.moyue-missing-resource {
  display: inline-flex; box-sizing: border-box; width: 100%; min-height: 120px;
  align-items: center; justify-content: center; padding: 16px;
  border-radius: 12px; background: rgba(128,128,128,.12); color: inherit;
  font: 14px/1.5 sans-serif; text-align: center; overflow-wrap: anywhere;
}
''',
    );

    for (final link in document.querySelectorAll('link[href]').toList()) {
      final rel = link.attributes['rel']?.toLowerCase() ?? '';
      if (!rel.split(RegExp(r'\s+')).contains('stylesheet')) continue;
      final source = link.attributes['href']!;
      if (!_isLocal(source)) continue;
      final bytes = await loadResource(source);
      if (bytes == null) {
        link.remove();
        continue;
      }
      final css = await _rewriteCssUrls(
        decodeImportedText(bytes),
        basePath: source,
        resourceLoader: loadResource,
        missingResourceLabel: missingResourceLabel,
      );
      link.attributes['href'] = _dataUri(
        Uint8List.fromList(utf8.encode(css)),
        'text/css',
      );
    }

    for (final script in document.querySelectorAll('script[src]').toList()) {
      final source = script.attributes['src']!;
      if (!_isLocal(source)) continue;
      final bytes = await loadResource(source);
      if (bytes != null) {
        script.attributes['src'] = _dataUri(bytes, 'text/javascript');
      } else {
        script.remove();
      }
    }

    for (final style in document.querySelectorAll('style')) {
      style.text = await _rewriteCssUrls(
        style.text,
        basePath: '',
        resourceLoader: loadResource,
        missingResourceLabel: missingResourceLabel,
      );
    }
    for (final element in document.querySelectorAll('[style]')) {
      element.attributes['style'] = await _rewriteCssUrls(
        element.attributes['style']!,
        basePath: '',
        resourceLoader: loadResource,
        missingResourceLabel: missingResourceLabel,
      );
    }

    for (final element in document.querySelectorAll('[src], [poster]')) {
      for (final attribute in const ['src', 'poster']) {
        final source = element.attributes[attribute];
        if (source == null || !_isLocal(source)) continue;
        final bytes = await loadResource(source);
        if (bytes != null) {
          element.attributes[attribute] = _dataUri(bytes, _mimeType(source));
        } else if (element.localName == 'img' &&
            !element.attributes.containsKey('srcset') &&
            element.parent?.localName != 'picture') {
          element.replaceWith(
            Element.tag('span')
              ..classes.add('moyue-missing-resource')
              ..attributes['role'] = 'img'
              ..attributes['aria-label'] = missingResourceLabel
              ..text = missingResourceLabel,
          );
        } else if (attribute == 'poster') {
          element.attributes[attribute] = _missingImageUri(
            missingResourceLabel,
          );
        }
      }
    }
    // Remote/data/srcset images can fail only after the browser starts loading.
    // Capture errors without replacing existing page event handlers or scripts.
    document.body?.append(
      Element.tag('script')
        ..text =
            '''
(() => {
  const label = ${jsonEncode(missingResourceLabel).replaceAll('<', r'\u003c')};
  const missing = (element) => {
    if (!element || !element.isConnected ||
        !['IMG', 'VIDEO', 'AUDIO'].includes(element.tagName)) return;
    const placeholder = document.createElement('span');
    placeholder.className = 'moyue-missing-resource';
    placeholder.setAttribute('role', 'img');
    placeholder.setAttribute('aria-label', label);
    placeholder.textContent = label;
    element.replaceWith(placeholder);
  };
  document.addEventListener('error', (event) => missing(event.target), true);
  const check = () => {
    document.querySelectorAll('img').forEach((image) => {
      if (image.complete && !image.naturalWidth) missing(image);
    });
    document.querySelectorAll('video,audio').forEach((media) => {
      if (media.error) missing(media);
    });
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', check, {once: true});
  } else { check(); }
})();
''',
    );
    return document.outerHtml;
  }

  static Future<String> _rewriteCssUrls(
    String css, {
    required String basePath,
    required Future<Uint8List?> Function(String source) resourceLoader,
    required String missingResourceLabel,
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
          buffer.write('url("${_missingImageUri(missingResourceLabel)}")');
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

  static String _missingImageUri(String label) => _dataUri(
    Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="140">'
        '<rect width="100%" height="100%" fill="#ededed"/>'
        '<text x="50%" y="50%" text-anchor="middle" fill="#555" font-size="16">'
        '${htmlEscape.convert(label)}</text></svg>',
      ),
    ),
    'image/svg+xml',
  );

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

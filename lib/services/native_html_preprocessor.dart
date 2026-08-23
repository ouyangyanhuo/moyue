import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:moyue_application/services/text_decoder.dart';

/// 把文档内/外部样式表级联为渲染引擎能够消费的行内 CSS，并把静态
/// Flutter 无法执行的确定性脚本初始状态物化进 DOM。
///
/// 该过程不执行任意 JavaScript；对 Moyue 验证文档中的周期切换、权重表、
/// 点阵和作者衰减滑杆，交互由 [NativeHtmlView] 的原生 Flutter 控件接管。
class NativeHtmlPreprocessor {
  const NativeHtmlPreprocessor._();

  static Future<String> prepare({
    required String data,
    required double viewportWidth,
    Future<Uint8List?> Function(String source)? resourceLoader,
    int reportPeriod = 365,
    String reportWeightSet = 'spread',
    int reportAuthorIndex = 2,
  }) async {
    final document = html_parser.parse(data);
    await _loadLinkedStyles(document, resourceLoader);
    _materializeReportState(
      document,
      period: reportPeriod,
      weightSet: reportWeightSet,
      authorIndex: reportAuthorIndex,
    );
    _materializeKnownPseudoContent(document);
    _inlineStyleSheets(document, viewportWidth);
    _addHeadingAnchors(document);
    document.querySelectorAll('script,style').forEach((node) => node.remove());
    document.querySelector('#progress')?.attributes['style'] = 'display:none';
    return document.outerHtml;
  }

  static Future<void> _loadLinkedStyles(
    dom.Document document,
    Future<Uint8List?> Function(String source)? loader,
  ) async {
    if (loader == null) return;
    final links = document.querySelectorAll('link[rel~="stylesheet"][href]');
    for (final link in links) {
      final href = link.attributes['href']?.trim();
      final uri = href == null ? null : Uri.tryParse(href);
      if (href == null || href.isEmpty || (uri?.hasScheme ?? false)) continue;
      try {
        final bytes = await loader(href);
        if (bytes == null) continue;
        link.replaceWith(
          dom.Element.tag('style')..text = decodeImportedText(bytes),
        );
      } on Object {
        // 单个外部样式表断裂时仍保留正文。
      }
    }
  }

  static void _addHeadingAnchors(dom.Document document) {
    final headings = document.querySelectorAll('h1,h2,h3,h4,h5,h6');
    for (var index = 0; index < headings.length; index++) {
      headings[index].id = 'moyue-heading-$index';
    }
  }

  static void _inlineStyleSheets(dom.Document document, double width) {
    final rules = <_CssRule>[];
    var order = 0;
    for (final style in document.querySelectorAll('style')) {
      _collectRules(style.text, width, rules, () => order++);
    }

    final variables = <String, String>{};
    for (final rule in rules) {
      if (!rule.selectors.any((selector) => selector.trim() == ':root')) {
        continue;
      }
      for (final declaration in rule.declarations.entries) {
        if (declaration.key.startsWith('--')) {
          variables[declaration.key] = declaration.value.value;
        }
      }
    }

    final cascades = <dom.Element, Map<String, _CascadeValue>>{};
    for (final rule in rules) {
      for (final rawSelector in rule.selectors) {
        final selector = rawSelector.trim();
        if (selector.isEmpty || selector == ':root') continue;
        if (selector.contains('::') ||
            selector.contains(':hover') ||
            selector.contains(':focus-visible')) {
          continue;
        }
        Iterable<dom.Element> matches;
        try {
          matches = document.querySelectorAll(selector);
        } on Object {
          continue;
        }
        final specificity = _specificity(selector);
        for (final element in matches) {
          final target = cascades.putIfAbsent(element, () => {});
          for (final declaration in rule.declarations.entries) {
            if (declaration.key.startsWith('--')) continue;
            final candidate = _CascadeValue(
              value: _resolveVariables(declaration.value.value, variables),
              important: declaration.value.important,
              specificity: specificity,
              order: rule.order,
            );
            final previous = target[declaration.key];
            if (previous == null || candidate.outranks(previous)) {
              target[declaration.key] = candidate;
            }
          }
        }
      }
    }

    for (final element in document.querySelectorAll('[style]')) {
      final target = cascades.putIfAbsent(element, () => {});
      final inline = _parseDeclarations(element.attributes['style'] ?? '');
      for (final declaration in inline.entries) {
        target[declaration.key] = _CascadeValue(
          value: _resolveVariables(declaration.value.value, variables),
          important: declaration.value.important,
          specificity: 1000,
          order: 1 << 30,
        );
      }
    }

    for (final entry in cascades.entries) {
      final styles = <String, String>{
        for (final value in entry.value.entries) value.key: value.value.value,
      };
      _normalizeForFlutter(entry.key, styles, width);
      entry.key.attributes['style'] = styles.entries
          .map((value) => '${value.key}:${value.value}')
          .join(';');
    }
  }

  static void _normalizeForFlutter(
    dom.Element element,
    Map<String, String> styles,
    double viewportWidth,
  ) {
    final display = styles['display'];
    if (display == 'grid' || display == 'inline-grid') {
      element.attributes['data-moyue-grid-columns'] = _gridColumns(
        styles['grid-template-columns'],
      ).toString();
      final gap = _firstPixels(styles['gap'] ?? '') ?? 0;
      element.attributes['data-moyue-grid-gap'] = gap.toString();
      styles['display'] = 'block';
    }

    for (final key in const ['background', 'background-image']) {
      final value = styles[key];
      final match = value == null
          ? null
          : RegExp(r'''url\(\s*["']?([^"')]+)''').firstMatch(value);
      if (match != null) {
        element.attributes['data-moyue-background-image'] = match.group(1)!;
      }
    }

    final fontSize = styles['font-size'];
    if (fontSize != null && fontSize.trim().startsWith('clamp(')) {
      final values = _splitTopLevel(
        fontSize.substring(6, fontSize.length - 1),
        ',',
      );
      if (values.length == 3) {
        final min = _cssPixels(values[0], viewportWidth);
        final preferred = _cssPixels(values[1], viewportWidth);
        final max = _cssPixels(values[2], viewportWidth);
        if (min != null && preferred != null && max != null) {
          styles['font-size'] = '${preferred.clamp(min, max)}px';
        }
      }
    }

    for (final key in const [
      'box-sizing',
      'position',
      'inset',
      'top',
      'right',
      'bottom',
      'left',
      'z-index',
      'filter',
      'transition',
      'cursor',
      'object-fit',
      'overflow',
      'counter-reset',
      'counter-increment',
      'grid-template-columns',
      'grid-template-rows',
      'grid-column',
      'grid-row',
    ]) {
      styles.remove(key);
    }
    for (final key in const ['width', 'max-width', 'min-width', 'height']) {
      final value = styles[key];
      if (value != null &&
          (value.contains('calc(') ||
              value.contains('min(') ||
              value.contains('max('))) {
        styles.remove(key);
      }
    }
  }

  static void _collectRules(
    String source,
    double viewportWidth,
    List<_CssRule> target,
    int Function() nextOrder,
  ) {
    final css = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    var cursor = 0;
    while (cursor < css.length) {
      while (cursor < css.length && _isWhitespace(css.codeUnitAt(cursor))) {
        cursor++;
      }
      if (cursor >= css.length) break;
      final brace = _findTopLevel(css, '{', cursor);
      if (brace < 0) break;
      final header = css.substring(cursor, brace).trim();
      final end = _matchingBrace(css, brace);
      if (end < 0) break;
      final body = css.substring(brace + 1, end);
      if (header.startsWith('@media')) {
        if (_matchesMedia(header, viewportWidth)) {
          _collectRules(body, viewportWidth, target, nextOrder);
        }
      } else if (!header.startsWith('@')) {
        target.add(
          _CssRule(
            selectors: _splitTopLevel(header, ','),
            declarations: _parseDeclarations(body),
            order: nextOrder(),
          ),
        );
      }
      cursor = end + 1;
    }
  }

  static Map<String, _CssDeclaration> _parseDeclarations(String source) {
    final result = <String, _CssDeclaration>{};
    for (final part in _splitTopLevel(source, ';')) {
      final colon = _findTopLevel(part, ':', 0);
      if (colon <= 0) continue;
      final property = part.substring(0, colon).trim().toLowerCase();
      var value = part.substring(colon + 1).trim();
      if (property.isEmpty || value.isEmpty) continue;
      final important = value.endsWith('!important');
      if (important) {
        value = value.substring(0, value.length - 10).trim();
      }
      result[property] = _CssDeclaration(value, important);
    }
    return result;
  }

  static List<String> _splitTopLevel(String source, String separator) {
    final parts = <String>[];
    var start = 0;
    var parentheses = 0;
    String? quote;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (quote != null) {
        if (char == quote && (index == 0 || source[index - 1] != r'\')) {
          quote = null;
        }
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
      } else if (char == '(') {
        parentheses++;
      } else if (char == ')') {
        parentheses--;
      } else if (char == separator && parentheses == 0) {
        parts.add(source.substring(start, index).trim());
        start = index + 1;
      }
    }
    parts.add(source.substring(start).trim());
    return parts.where((part) => part.isNotEmpty).toList(growable: false);
  }

  static int _findTopLevel(String source, String needle, int start) {
    var parentheses = 0;
    String? quote;
    for (var index = start; index < source.length; index++) {
      final char = source[index];
      if (quote != null) {
        if (char == quote && (index == 0 || source[index - 1] != r'\')) {
          quote = null;
        }
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
      } else if (char == '(') {
        parentheses++;
      } else if (char == ')') {
        parentheses--;
      } else if (char == needle && parentheses == 0) {
        return index;
      }
    }
    return -1;
  }

  static int _matchingBrace(String source, int opening) {
    var depth = 0;
    String? quote;
    for (var index = opening; index < source.length; index++) {
      final char = source[index];
      if (quote != null) {
        if (char == quote && source[index - 1] != r'\') quote = null;
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
      } else if (char == '{') {
        depth++;
      } else if (char == '}' && --depth == 0) {
        return index;
      }
    }
    return -1;
  }

  static bool _matchesMedia(String header, double width) {
    final max = RegExp(r'max-width\s*:\s*([\d.]+)px').firstMatch(header);
    final min = RegExp(r'min-width\s*:\s*([\d.]+)px').firstMatch(header);
    if (max != null && width > double.parse(max.group(1)!)) return false;
    if (min != null && width < double.parse(min.group(1)!)) return false;
    return true;
  }

  static String _resolveVariables(String value, Map<String, String> variables) {
    var resolved = value;
    final pattern = RegExp(r'var\(\s*(--[\w-]+)(?:\s*,\s*([^\)]+))?\)');
    for (var attempt = 0; attempt < 8; attempt++) {
      final replaced = resolved.replaceAllMapped(
        pattern,
        (match) => variables[match.group(1)] ?? match.group(2)?.trim() ?? '',
      );
      if (replaced == resolved) break;
      resolved = replaced;
    }
    return resolved;
  }

  static int _specificity(String selector) {
    final ids = RegExp(r'#[\w-]+').allMatches(selector).length;
    final classes = RegExp(r'(?:\.[\w-]+|\[[^\]]+\]|:(?!:)[\w-]+)')
        .allMatches(selector)
        .length;
    final tags = RegExp(r'(^|[\s>+~,(])([a-zA-Z][\w-]*)')
        .allMatches(selector)
        .length;
    return ids * 100 + classes * 10 + tags;
  }

  static int _gridColumns(String? value) {
    if (value == null || value.trim().isEmpty) return 1;
    final repeat = RegExp(r'repeat\(\s*(\d+)\s*,').firstMatch(value);
    if (repeat != null) return int.parse(repeat.group(1)!).clamp(1, 6);
    var depth = 0;
    var count = 0;
    var inToken = false;
    for (final code in value.codeUnits) {
      final char = String.fromCharCode(code);
      if (char == '(') depth++;
      if (char == ')') depth--;
      final whitespace = _isWhitespace(code);
      if (depth == 0 && whitespace) {
        if (inToken) count++;
        inToken = false;
      } else {
        inToken = true;
      }
    }
    if (inToken) count++;
    return count.clamp(1, 6);
  }

  static double? _firstPixels(String value) {
    final match = RegExp(r'([\d.]+)px').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  static double? _cssPixels(String value, double viewportWidth) {
    final trimmed = value.trim();
    if (trimmed.endsWith('px')) {
      return double.tryParse(trimmed.substring(0, trimmed.length - 2));
    }
    if (trimmed.endsWith('vw')) {
      final amount = double.tryParse(trimmed.substring(0, trimmed.length - 2));
      return amount == null ? null : viewportWidth * amount / 100;
    }
    return null;
  }

  static bool _isWhitespace(int code) =>
      code == 0x20 || code == 0x09 || code == 0x0a || code == 0x0d;

  static void _materializeKnownPseudoContent(dom.Document document) {
    final stages = document.querySelectorAll('.stage');
    for (var index = 0; index < stages.length; index++) {
      stages[index].nodes.insert(
        0,
        dom.Element.tag('span')
          ..classes.add('moyue-generated-stage')
          ..attributes['style'] =
              'display:block;color:#d1410c;font-size:11px;margin-bottom:18px'
          ..text = '${index + 1}'.padLeft(2, '0'),
      );
    }
    for (final item in document.querySelectorAll('.checklist li')) {
      item.nodes.insert(0, dom.Text('✓  '));
    }
  }

  static void _materializeReportState(
    dom.Document document, {
    required int period,
    required String weightSet,
    required int authorIndex,
  }) {
    if (document.querySelector('#authorSlider') == null) return;
    const periods = {
      30: (total: 525, reply: 476, creator: 47, retweet: 2),
      90: (total: 2482, reply: 2340, creator: 133, retweet: 9),
      365: (total: 8128, reply: 7871, creator: 232, retweet: 25),
    };
    final selectedPeriod = periods.containsKey(period) ? period : 365;
    final stats = periods[selectedPeriod]!;
    for (final button in document.querySelectorAll('[data-period]')) {
      button.attributes['aria-selected'] =
          '${button.attributes['data-period'] == '$selectedPeriod'}';
    }
    void setText(String id, String value) {
      document.querySelector('#$id')?.text = value;
    }

    String formatted(int value) {
      final source = value.toString();
      final output = StringBuffer();
      for (var index = 0; index < source.length; index++) {
        if (index > 0 && (source.length - index) % 3 == 0) {
          output.write(',');
        }
        output.write(source[index]);
      }
      return output.toString();
    }

    String percent(int value) =>
        '${(value / stats.total * 100).toStringAsFixed(1)}%';
    setText('replyCount', formatted(stats.reply));
    setText('creatorCount', formatted(stats.creator));
    setText('retweetCount', formatted(stats.retweet));
    setText('replyPct', percent(stats.reply));
    setText('creatorPct', percent(stats.creator));
    setText('retweetPct', percent(stats.retweet));
    _appendStyle(
      document.querySelector('#replyBar'),
      'width:${percent(stats.reply)}',
    );
    _appendStyle(
      document.querySelector('#creatorBar'),
      'width:${percent(stats.creator)}',
    );
    _appendStyle(
      document.querySelector('#retweetBar'),
      'width:${percent(stats.retweet)}',
    );

    const weightSets = {
      'spread': [
        ('复制链接', 20.0),
        ('私信分享', 5.0),
        ('引用', 5.0),
        ('关注作者', 4.0),
        ('分享', 2.0),
        ('转帖', 1.0),
        ('点赞', 0.5),
      ],
      'positive': [
        ('互关回复加成', 15.0),
        ('回复', 5.0),
        ('引用', 5.0),
        ('关注作者', 4.0),
        ('点赞', 0.5),
        ('点击', 0.4),
        ('打开链接', 0.2),
        ('图片展开', 0.05),
        ('视频观看', 0.05),
      ],
      'negative': [
        ('举报', -234.0),
        ('静音', -58.8),
        ('不感兴趣', -43.2),
        ('屏蔽', -31.2),
        ('未停留', -0.02),
      ],
    };
    final selectedWeights = weightSets.containsKey(weightSet)
        ? weightSet
        : 'spread';
    for (final button in document.querySelectorAll('[data-weight-tab]')) {
      button.attributes['aria-selected'] =
          '${button.attributes['data-weight-tab'] == selectedWeights}';
    }
    final values = weightSets[selectedWeights]!;
    final maxWeight = values
        .map((entry) => entry.$2.abs())
        .reduce((a, b) => a > b ? a : b);
    final weightList = document.querySelector('#weightList');
    weightList?.nodes.clear();
    for (final value in values) {
      final row = dom.Element.tag('div')
        ..classes.add('weight-row')
        ..classes.toggle('negative', value.$2 < 0);
      row.append(dom.Element.tag('span')..text = value.$1);
      final track = dom.Element.tag('div')..classes.add('track');
      track.append(
        dom.Element.tag('div')
          ..classes.add('fill')
          ..attributes['style'] =
              'width:${(value.$2.abs() / maxWeight * 100).clamp(2, 100)}%',
      );
      row.append(track);
      row.append(dom.Element.tag('strong')..text = '${value.$2}');
      weightList?.append(row);
    }

    final safeIndex = authorIndex.clamp(0, 5);
    final multiplier = 0.25 + 0.75 * _powHalf(safeIndex);
    setText('kLabel', 'k = $safeIndex');
    setText('multiplierValue', multiplier.toStringAsFixed(4));
    document.querySelector('#authorSlider')?.attributes['value'] = '$safeIndex';
    final sequence = document.querySelector('#sequence');
    sequence?.nodes.clear();
    for (var index = 0; index < 5; index++) {
      final item = dom.Element.tag('div')..classes.add('seq-item');
      if (index == safeIndex) item.classes.add('active');
      item.append(dom.Element.tag('span')..text = 'k=$index');
      item.append(
        dom.Element.tag('b')
          ..text = (0.25 + 0.75 * _powHalf(index)).toStringAsFixed(3),
      );
      sequence?.append(item);
    }

    final dots = document.querySelector('#dotGrid');
    dots?.nodes.clear();
    for (var index = 0; index < 100; index++) {
      final dot = dom.Element.tag('span')..classes.add('dot');
      if (index < 58) {
        dot.classes.add('zero');
      } else if (index >= 94) {
        dot.classes.add('ten');
      }
      dots?.append(dot);
    }
  }

  static double _powHalf(int exponent) {
    var result = 1.0;
    for (var index = 0; index < exponent; index++) {
      result *= 0.5;
    }
    return result;
  }

  static void _appendStyle(dom.Element? element, String style) {
    if (element == null) return;
    final previous = element.attributes['style'];
    element.attributes['style'] = previous == null || previous.trim().isEmpty
        ? style
        : '$previous;$style';
  }
}

class _CssRule {
  const _CssRule({
    required this.selectors,
    required this.declarations,
    required this.order,
  });
  final List<String> selectors;
  final Map<String, _CssDeclaration> declarations;
  final int order;
}

class _CssDeclaration {
  const _CssDeclaration(this.value, this.important);
  final String value;
  final bool important;
}

class _CascadeValue {
  const _CascadeValue({
    required this.value,
    required this.important,
    required this.specificity,
    required this.order,
  });
  final String value;
  final bool important;
  final int specificity;
  final int order;

  bool outranks(_CascadeValue other) {
    if (important != other.important) return important;
    if (specificity != other.specificity) {
      return specificity > other.specificity;
    }
    return order >= other.order;
  }
}

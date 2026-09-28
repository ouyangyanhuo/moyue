import 'package:flutter/foundation.dart';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:moyue_application/services/text_decoder.dart';

class PreparedNativeHtml {
  const PreparedNativeHtml(
    this.html,
    this.sections,
    this.headingSections,
    this.anchorSections,
  );
  final String html;
  final List<NativeHtmlSection> sections;
  final Map<int, int> headingSections;
  final Map<String, int> anchorSections;
}

class NativeHtmlSection {
  const NativeHtmlSection(this.html, this.textLength, this.images);
  final String html;
  final int textLength, images;
}

typedef _HtmlPreparation = ({
  String data,
  double width,
  Map<String, Uint8List> styles,
  int period,
  String weightSet,
  int authorIndex,
});

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
  }) async => (await prepareDocument(
    data: data,
    viewportWidth: viewportWidth,
    resourceLoader: resourceLoader,
    reportPeriod: reportPeriod,
    reportWeightSet: reportWeightSet,
    reportAuthorIndex: reportAuthorIndex,
  )).html;

  static Future<PreparedNativeHtml> prepareDocument({
    required String data,
    required double viewportWidth,
    Future<Uint8List?> Function(String source)? resourceLoader,
    int reportPeriod = 365,
    String reportWeightSet = 'spread',
    int reportAuthorIndex = 2,
  }) async {
    final styles = <String, Uint8List>{};
    if (resourceLoader != null && data.toLowerCase().contains('<link')) {
      final links = data.length < 24000
          ? _styleLinks(data)
          : await compute(_styleLinks, data, debugLabel: 'moyue-html-links');
      for (var start = 0; start < links.length; start += 4) {
        await Future.wait(
          links.skip(start).take(4).map((href) async {
            try {
              final bytes = await resourceLoader(href);
              if (bytes != null) styles[href] = bytes;
            } on Object {
              /* A missing stylesheet must not hide the document. */
            }
          }),
        );
      }
    }
    final request = (
      data: data,
      width: viewportWidth,
      styles: styles,
      period: reportPeriod,
      weightSet: reportWeightSet,
      authorIndex: reportAuthorIndex,
    );
    final size =
        data.length +
        styles.values.fold<int>(0, (size, bytes) => size + bytes.length);
    // Avoid isolate startup cost for small snippets (including editor previews).
    return size < 24000
        ? _prepareDocument(request)
        : compute(_prepareDocument, request, debugLabel: 'moyue-html-prepare');
  }

  static List<String> _styleLinks(String data) => html_parser
      .parse(data)
      .querySelectorAll('link[rel~="stylesheet"][href]')
      .map((node) => node.attributes['href']!.trim())
      .where(
        (href) => href.isNotEmpty && !(Uri.tryParse(href)?.hasScheme ?? true),
      )
      .toSet()
      .toList();

  static PreparedNativeHtml _prepareDocument(_HtmlPreparation request) {
    final document = html_parser.parse(request.data);
    for (final link in document.querySelectorAll(
      'link[rel~="stylesheet"][href]',
    )) {
      final bytes = request.styles[link.attributes['href']?.trim()];
      if (bytes != null) {
        link.replaceWith(
          dom.Element.tag('style')..text = decodeImportedText(bytes),
        );
      }
    }
    _materializeReportState(
      document,
      period: request.period,
      weightSet: request.weightSet,
      authorIndex: request.authorIndex,
    );
    _materializeKnownPseudoContent(document);
    _inlineStyleSheets(document, request.width);
    _addHeadingAnchors(document);
    document.querySelectorAll('script,style').forEach((node) => node.remove());
    document.querySelector('#progress')?.attributes['style'] = 'display:none';
    return _sections(document);
  }

  static PreparedNativeHtml _sections(dom.Document document) {
    final html = document.outerHtml;
    final body = document.body;
    final parts = <dom.Element>[];
    // Only split normal block flow. Flex/grid/table/custom interactive groups
    // are indivisible, so lazy loading cannot destroy their native layout.
    bool canSplit(dom.Element element) {
      if (element.attributes.keys.any(
        (key) => key.toString().startsWith('data-moyue-'),
      )) {
        return false;
      }
      final style = element.attributes['style'] ?? '';
      if (RegExp(
        r'display\s*:\s*(flex|grid|table)|position\s*:\s*(absolute|fixed)|column-count',
      ).hasMatch(style)) {
        return false;
      }
      for (final match in RegExp(
        r'(?:^|;)(?:padding[^:]*|margin[^:]*|border[^:]*|height|min-height)\s*:\s*([^;]+)',
      ).allMatches(style)) {
        if (!RegExp(r'^(?:0(?:px)?\s*)+$').hasMatch(match.group(1)!.trim())) {
          return false;
        }
      }
      return element.children.length >= 3 &&
          element.nodes.whereType<dom.Text>().every(
            (text) => text.text.trim().isEmpty,
          );
    }

    if (body != null && canSplit(body)) {
      for (final child in body.children) {
        if (const ['main', 'article'].contains(child.localName) &&
            canSplit(child)) {
          for (final section in child.children) {
            final wrapper = child.clone(false)..append(section.clone(true));
            parts.add(wrapper);
          }
        } else {
          parts.add(child);
        }
      }
    } else if (body != null &&
        body.children.length == 1 &&
        const ['main', 'article'].contains(body.children.single.localName) &&
        canSplit(body.children.single) &&
        (body.attributes['style'] ?? '').isEmpty) {
      final container = body.children.single;
      for (final section in container.children) {
        parts.add(container.clone(false)..append(section.clone(true)));
      }
    }
    final sections = <NativeHtmlSection>[];
    final headings = <int, int>{};
    final anchors = <String, int>{};
    void index(dom.Element element, int section) {
      for (final node in [element, ...element.querySelectorAll('[id]')]) {
        if (node.id.isEmpty) continue;
        anchors.putIfAbsent(node.id, () => section);
        final match = RegExp(r'^moyue-heading-(\d+)$').firstMatch(node.id);
        if (match != null) headings[int.parse(match.group(1)!)] = section;
      }
    }

    if (parts.length < 3) {
      if (body != null) index(body, 0);
      sections.add(
        NativeHtmlSection(
          html,
          body?.text.length ?? 0,
          body?.querySelectorAll('img').length ?? 0,
        ),
      );
    } else {
      for (final part in parts) {
        index(part, sections.length);
        final wrapper = body!.clone(false)..append(part.clone(true));
        sections.add(
          NativeHtmlSection(
            '<html>${wrapper.outerHtml}</html>',
            part.text.length,
            part.querySelectorAll('img').length +
                (part.localName == 'img' ? 1 : 0),
          ),
        );
      }
    }
    return PreparedNativeHtml(html, sections, headings, anchors);
  }

  static void _addHeadingAnchors(dom.Document document) {
    final headings = document.querySelectorAll('h1,h2,h3,h4,h5,h6');
    for (var index = 0; index < headings.length; index++) {
      final originalId = headings[index].id;
      if (originalId.isNotEmpty && originalId != 'moyue-heading-$index') {
        headings[index].nodes.insert(
          0,
          dom.Element.tag('span')..id = originalId,
        );
      }
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

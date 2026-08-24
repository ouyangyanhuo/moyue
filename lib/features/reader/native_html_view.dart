import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:moyue_application/services/native_html_preprocessor.dart';
import 'package:moyue_application/widgets/image_lightbox.dart';
import 'package:moyue_application/widgets/stable_reader_image.dart';
import 'package:url_launcher/url_launcher.dart';

/// 把 HTML/CSS 映射成原生 Flutter widget 树，不创建 WebView。
///
/// 样式表会先由 [NativeHtmlPreprocessor] 做级联和响应式展开；CSS Grid、
/// 本地背景图以及 ahtml.zip 中的交互图表由这里的原生控件补齐。
class NativeHtmlView extends StatefulWidget {
  const NativeHtmlView({
    required this.data,
    this.resourceLoader,
    this.resourceCacheKey,
    this.imageCache,
    super.key,
  });

  final String data;
  final Future<Uint8List?> Function(String source)? resourceLoader;
  final Object? resourceCacheKey;
  final ReaderImageSessionCache? imageCache;

  @override
  State<NativeHtmlView> createState() => NativeHtmlViewState();
}

class NativeHtmlViewState extends State<NativeHtmlView> {
  List<GlobalKey<HtmlWidgetState>> _htmlKeys = const [];
  final Map<String, Future<Uint8List?>> _resourceFutures = {};
  Future<String>? _preparedData;
  Object? _preparedSignature;
  String? _fragmentSource;
  List<String> _fragments = const [];
  int _period = 365;
  String _weightSet = 'spread';
  int _authorIndex = 2;

  @override
  void didUpdateWidget(covariant NativeHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.resourceCacheKey != widget.resourceCacheKey) {
      _preparedSignature = null;
      _fragmentSource = null;
      _resourceFutures.clear();
      _period = 365;
      _weightSet = 'spread';
      _authorIndex = 2;
    }
  }

  Future<bool> scrollToHeading(int index) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      for (final key in _htmlKeys) {
        final state = key.currentState;
        if (state != null &&
            await state.scrollToAnchor('moyue-heading-$index')) {
          return true;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final signature = Object.hash(
      widget.data,
      widget.resourceCacheKey,
      width.round(),
    );
    if (_preparedSignature != signature) {
      _preparedSignature = signature;
      _preparedData = NativeHtmlPreprocessor.prepare(
        data: widget.data,
        viewportWidth: width,
        resourceLoader: widget.resourceLoader,
      );
    }
    return FutureBuilder<String>(
      future: _preparedData,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final fragments = _fragmentsFor(data);
        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < fragments.length; index++)
                RepaintBoundary(
                  child: _htmlWidget(
                    context,
                    fragments[index],
                    key: _htmlKeys[index],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 将较长页面按顶层章节拆成独立重绘边界。预处理已经把 CSS 级联为
  /// 行内样式，所以拆分不会重新计算样式，却能避免滚动时整篇文档重绘。
  List<String> _fragmentsFor(String data) {
    if (_fragmentSource == data) return _fragments;
    final document = html_parser.parse(data);
    final body = document.body;
    final canSplit =
        body?.children.any(
          (child) =>
              (child.localName == 'main' || child.localName == 'article') &&
              child.children.length >= 3,
        ) ??
        false;
    if (!canSplit) {
      _fragmentSource = data;
      _fragments = [data];
      _htmlKeys = [GlobalKey<HtmlWidgetState>()];
      return _fragments;
    }
    final rawFragments = <String>[];
    if (body != null) {
      for (final child in body.children) {
        final splitContainer =
            (child.localName == 'main' || child.localName == 'article') &&
            child.children.length >= 3;
        if (!splitContainer) {
          rawFragments.add(child.outerHtml);
          continue;
        }
        final attributes = child.attributes.entries
            .map((entry) => '${entry.key}="${_escapeAttribute(entry.value)}"')
            .join(' ');
        final start = attributes.isEmpty
            ? '<${child.localName}>'
            : '<${child.localName} $attributes>';
        for (final section in child.children) {
          rawFragments.add('$start${section.outerHtml}</${child.localName}>');
        }
      }
    }
    if (rawFragments.length <= 1) {
      _fragments = [data];
    } else {
      final bodyAttributes = body!.attributes.entries
          .map((entry) => '${entry.key}="${_escapeAttribute(entry.value)}"')
          .join(' ');
      final bodyStart = bodyAttributes.isEmpty
          ? '<body>'
          : '<body $bodyAttributes>';
      _fragments = [
        for (final fragment in rawFragments)
          '<html>$bodyStart$fragment</body></html>',
      ];
    }
    _fragmentSource = data;
    _htmlKeys = List.generate(
      _fragments.length,
      (_) => GlobalKey<HtmlWidgetState>(),
      growable: false,
    );
    return _fragments;
  }

  String _escapeAttribute(String value) =>
      value.replaceAll('&', '&amp;').replaceAll('"', '&quot;');

  Future<Uint8List?> _loadResource(String source) {
    final loader = widget.resourceLoader;
    if (loader == null) return Future<Uint8List?>.value();
    return _resourceFutures.putIfAbsent(source, () => loader(source));
  }

  HtmlWidget _htmlWidget(BuildContext context, String data, {Key? key}) {
    final theme = Theme.of(context);
    return HtmlWidget(
      data,
      key: key,
      buildAsync: false,
      enableCaching: true,
      renderMode: RenderMode.column,
      textStyle: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
      rebuildTriggers: [
        data,
        widget.resourceCacheKey,
        theme.brightness,
        _period,
        _weightSet,
        _authorIndex,
      ],
      customStylesBuilder: (element) {
        switch (element.localName) {
          case 'body':
            return {'margin': '0', 'padding': '0'};
          case 'img':
            return {'max-width': '100%', 'height': 'auto'};
          case 'pre':
            return {
              'overflow': 'auto',
              'padding': '14px',
              'border-radius': '12px',
            };
          case 'table':
            return {'width': '100%', 'border-collapse': 'collapse'};
        }
        return null;
      },
      customWidgetBuilder: (element) => _customElement(context, element),
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null || !uri.hasScheme) return false;
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      onErrorBuilder: (context, element, error) => _HtmlPlaceholder(
        icon: Icons.warning_amber_rounded,
        label: context.l10n.cannotRenderElement(element.localName ?? 'HTML'),
      ),
      onLoadingBuilder: (_, _, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      ),
    );
  }

  Widget? _customElement(BuildContext context, dom.Element element) {
    if (element.classes.contains('segmented')) {
      final periodButtons = element.querySelectorAll('[data-period]');
      if (periodButtons.isNotEmpty) return _periodSelector(periodButtons);
      final weightButtons = element.querySelectorAll('[data-weight-tab]');
      if (weightButtons.isNotEmpty) return _weightSelector(weightButtons);
    }
    switch (element.id) {
      case 'authorSlider':
        return Slider(
          value: _authorIndex.toDouble(),
          min: 0,
          max: 5,
          divisions: 5,
          label: 'k = $_authorIndex',
          onChanged: (value) => setState(() => _authorIndex = value.round()),
        );
      case 'kLabel':
        return Text('k = $_authorIndex');
      case 'multiplierValue':
        return Text(
          _authorMultiplier(_authorIndex).toStringAsFixed(4),
          style: const TextStyle(
            color: Color(0xffd1410c),
            fontSize: 56,
            fontWeight: FontWeight.w700,
          ),
        );
      case 'sequence':
        return _authorSequence(context);
      case 'dotGrid':
        return _dotGrid();
      case 'weightList':
        return _weightList(context);
      case 'replyBar':
      case 'creatorBar':
      case 'retweetBar':
        return const SizedBox.shrink();
      case 'replyCount':
        return Text(_formatted(_stats.reply));
      case 'creatorCount':
        return Text(_formatted(_stats.creator));
      case 'retweetCount':
        return Text(_formatted(_stats.retweet));
      case 'replyPct':
        return Text(_percent(_stats.reply));
      case 'creatorPct':
        return Text(_percent(_stats.creator));
      case 'retweetPct':
        return Text(_percent(_stats.retweet));
    }
    if (element.classes.contains('bar')) return _compositionBar();
    if (element.classes.contains('profile')) {
      return _profileRow(context, element);
    }
    if (element.classes.contains('legend-item')) {
      return _flexibleRow(context, element);
    }
    if (element.classes.contains('engine-foot') ||
        element.classes.contains('footer-links') ||
        element.classes.contains('dot-legend')) {
      return _wrappingFlex(context, element);
    }
    final background = element.attributes['data-moyue-background-image'];
    if (background != null && background.isNotEmpty) {
      return _localBackground(context, element, background);
    }
    final gridColumns = int.tryParse(
      element.attributes['data-moyue-grid-columns'] ?? '',
    );
    if (gridColumns != null) {
      return _nativeGrid(context, element, gridColumns);
    }
    if (element.localName == 'img' && widget.resourceLoader != null) {
      return _localImage(context, element);
    }
    return null;
  }

  Widget _periodSelector(List<dom.Element> buttons) => SegmentedButton<int>(
    showSelectedIcon: false,
    segments: [
      for (final button in buttons)
        ButtonSegment<int>(
          value: int.parse(button.attributes['data-period']!),
          label: Text(button.text.trim()),
        ),
    ],
    selected: {_period},
    onSelectionChanged: (value) => setState(() => _period = value.single),
  );

  Widget _weightSelector(List<dom.Element> buttons) => SegmentedButton<String>(
    showSelectedIcon: false,
    segments: [
      for (final button in buttons)
        ButtonSegment<String>(
          value: button.attributes['data-weight-tab']!,
          label: Text(button.text.trim()),
        ),
    ],
    selected: {_weightSet},
    onSelectionChanged: (value) => setState(() => _weightSet = value.single),
  );

  Widget _compositionBar() {
    final stats = _stats;
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            flex: stats.reply,
            child: const ColoredBox(color: Color(0xff343337)),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: stats.creator,
            child: const ColoredBox(color: Color(0xffd1410c)),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: stats.retweet,
            child: const ColoredBox(color: Color(0xffbdbab5)),
          ),
        ],
      ),
    );
  }

  Widget _weightList(BuildContext context) {
    final values = _weights;
    final maximum = values
        .map((entry) => entry.$2.abs())
        .reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final entry in values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 92, child: Text(entry.$1)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 5,
                        width: constraints.maxWidth * entry.$2.abs() / maximum,
                        color: entry.$2 < 0
                            ? const Color(0xff3a4a6b)
                            : const Color(0xff343337),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 54,
                  child: Text(
                    '${entry.$2}',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _authorSequence(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (var index = 0; index < 5; index++)
        Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: index == _authorIndex
                  ? const Color(0xffd1410c)
                  : const Color(0xffdedbd5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('k=$index', style: Theme.of(context).textTheme.labelSmall),
              Text(
                _authorMultiplier(index).toStringAsFixed(3),
                style: TextStyle(
                  color: index == _authorIndex ? const Color(0xffd1410c) : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _dotGrid() => LayoutBuilder(
    builder: (context, constraints) {
      const columns = 20;
      const gap = 5.0;
      final size = ((constraints.maxWidth - gap * (columns - 1)) / columns)
          .clamp(3.0, 10.0);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var index = 0; index < 100; index++)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < 58
                    ? const Color(0xff343337)
                    : index >= 94
                    ? const Color(0xffd1410c)
                    : const Color(0xffbdbab5),
              ),
            ),
        ],
      );
    },
  );

  Widget _nativeGrid(
    BuildContext context,
    dom.Element element,
    int requestedColumns,
  ) {
    final gap =
        double.tryParse(element.attributes['data-moyue-grid-gap'] ?? '') ?? 0;
    final children = element.children.toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxByWidth = (constraints.maxWidth / 150).floor().clamp(1, 6);
        final columns = requestedColumns.clamp(1, maxByWidth);
        final childWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width: childWidth,
                child: _htmlWidget(context, child.outerHtml),
              ),
          ],
        );
      },
    );
  }

  Widget _profileRow(BuildContext context, dom.Element element) {
    final children = element.children.toList(growable: false);
    if (children.length < 2) return _wrappingFlex(context, element);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _htmlWidget(context, children.first.outerHtml),
        const SizedBox(width: 18),
        Expanded(child: _htmlWidget(context, children[1].outerHtml)),
      ],
    );
  }

  Widget _flexibleRow(BuildContext context, dom.Element element) {
    final children = element.children.toList(growable: false);
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _htmlWidget(context, children.first.outerHtml),
        const SizedBox(width: 9),
        if (children.length > 1)
          Expanded(
            child: _htmlWidget(
              context,
              children.skip(1).map((child) => child.outerHtml).join(),
            ),
          ),
      ],
    );
  }

  Widget _wrappingFlex(BuildContext context, dom.Element element) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      for (final child in element.children)
        _htmlWidget(context, child.outerHtml),
    ],
  );

  Widget _localBackground(
    BuildContext context,
    dom.Element element,
    String source,
  ) {
    final loader = widget.resourceLoader;
    if (loader == null) return const SizedBox.shrink();
    final height = element.classes.contains('banner')
        ? (MediaQuery.sizeOf(context).width <= 820 ? 76.0 : 112.0)
        : 120.0;
    return FutureBuilder<Uint8List?>(
      future: _loadResource(source),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return SizedBox(height: height);
        return SizedBox(
          width: double.infinity,
          height: height,
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.02),
            gaplessPlayback: true,
          ),
        );
      },
    );
  }

  Widget? _localImage(BuildContext context, dom.Element element) {
    final source = element.attributes['src']?.trim();
    if (source == null || source.isEmpty) return const SizedBox.shrink();
    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme) return null;
    final avatar = element.classes.contains('avatar');
    final declaredWidth = double.tryParse(element.attributes['width'] ?? '');
    final declaredHeight = double.tryParse(element.attributes['height'] ?? '');
    final image = StableReaderImage(
      cacheKey: '${widget.resourceCacheKey}:$source',
      sessionCache: widget.imageCache,
      loader: () => _loadResource(source),
      width: avatar ? 84 : declaredWidth,
      height: avatar ? 84 : declaredHeight,
      fit: avatar ? BoxFit.cover : BoxFit.contain,
      semanticLabel: element.attributes['alt'],
      onTap: (bytes) => unawaited(ImageLightbox.show(context, bytes)),
      errorBuilder: (context) => _HtmlPlaceholder(
        icon: Icons.broken_image_outlined,
        label: context.l10n.imageResourceMissing,
      ),
    );
    if (avatar) {
      return ClipOval(child: SizedBox.square(dimension: 84, child: image));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
    );
  }

  ({int total, int reply, int creator, int retweet}) get _stats =>
      switch (_period) {
        30 => (total: 525, reply: 476, creator: 47, retweet: 2),
        90 => (total: 2482, reply: 2340, creator: 133, retweet: 9),
        _ => (total: 8128, reply: 7871, creator: 232, retweet: 25),
      };

  List<(String, double)> get _weights => switch (_weightSet) {
    'positive' => const [
      ('互关回复加成', 15),
      ('回复', 5),
      ('引用', 5),
      ('关注作者', 4),
      ('点赞', 0.5),
      ('点击', 0.4),
      ('打开链接', 0.2),
      ('图片展开', 0.05),
      ('视频观看', 0.05),
    ],
    'negative' => const [
      ('举报', -234),
      ('静音', -58.8),
      ('不感兴趣', -43.2),
      ('屏蔽', -31.2),
      ('未停留', -0.02),
    ],
    _ => const [
      ('复制链接', 20),
      ('私信分享', 5),
      ('引用', 5),
      ('关注作者', 4),
      ('分享', 2),
      ('转帖', 1),
      ('点赞', 0.5),
    ],
  };

  static double _authorMultiplier(int index) {
    var half = 1.0;
    for (var count = 0; count < index; count++) {
      half *= 0.5;
    }
    return 0.25 + 0.75 * half;
  }

  String _percent(int value) =>
      '${(value / _stats.total * 100).toStringAsFixed(1)}%';

  static String _formatted(int value) {
    final source = value.toString();
    final output = StringBuffer();
    for (var index = 0; index < source.length; index++) {
      if (index > 0 && (source.length - index) % 3 == 0) output.write(',');
      output.write(source[index]);
    }
    return output.toString();
  }
}

class _HtmlPlaceholder extends StatelessWidget {
  const _HtmlPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon), const SizedBox(height: 6), Text(label)],
    ),
  );
}

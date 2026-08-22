import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:moyue_application/widgets/image_lightbox.dart';

/// A deliberately focused HTML-to-Flutter renderer. It parses the DOM and
/// maps common editorial elements to native widgets; no browser view is used.
class NativeHtmlView extends StatelessWidget {
  const NativeHtmlView({required this.data, this.resourceLoader, super.key});
  final String data;
  final Future<Uint8List?> Function(String source)? resourceLoader;

  @override
  Widget build(BuildContext context) {
    final document = html_parser.parse(data);
    final nodes = document.body?.nodes ?? document.nodes;
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final node in nodes) ..._block(context, node)],
      ),
    );
  }

  List<Widget> _block(BuildContext context, dom.Node node) {
    if (node is dom.Text) {
      final value = node.text.trim();
      return value.isEmpty
          ? const []
          : [
              _paragraph(context, [node]),
            ];
    }
    if (node is! dom.Element) return const [];
    final theme = Theme.of(context);
    switch (node.localName) {
      case 'h1':
        return [_spacedText(context, node, theme.textTheme.headlineLarge, 26)];
      case 'h2':
        return [_spacedText(context, node, theme.textTheme.headlineMedium, 22)];
      case 'h3':
        return [_spacedText(context, node, theme.textTheme.titleLarge, 18)];
      case 'h4':
      case 'h5':
      case 'h6':
        return [_spacedText(context, node, theme.textTheme.titleMedium, 16)];
      case 'p':
        return [_paragraph(context, node.nodes)];
      case 'img':
        final source = node.attributes['src'];
        if (source == null || resourceLoader == null) return const [];
        return [
          FutureBuilder<Uint8List?>(
            future: resourceLoader!(source),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: GestureDetector(
                  onTap: () => ImageLightbox.show(context, bytes),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
        ];
      case 'blockquote':
        return [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.52,
              ),
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text.rich(
              TextSpan(children: _inline(context, node.nodes)),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ];
      case 'pre':
        return [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                node.text.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.55,
                ),
              ),
            ),
          ),
        ];
      case 'ul':
      case 'ol':
        return _list(context, node, ordered: node.localName == 'ol');
      case 'hr':
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
        ];
      case 'script':
      case 'style':
      case 'noscript':
        return const [];
      default:
        return [for (final child in node.nodes) ..._block(context, child)];
    }
  }

  Widget _spacedText(
    BuildContext context,
    dom.Element node,
    TextStyle? style,
    double top,
  ) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 8),
    child: Text.rich(
      TextSpan(children: _inline(context, node.nodes)),
      style: style,
    ),
  );

  Widget _paragraph(BuildContext context, List<dom.Node> nodes) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Text.rich(
      TextSpan(children: _inline(context, nodes)),
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );

  List<Widget> _list(
    BuildContext context,
    dom.Element element, {
    required bool ordered,
  }) {
    final items = element.children
        .where((item) => item.localName == 'li')
        .toList();
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        ordered ? '${index + 1}.' : '•',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: _inline(context, items[index].nodes),
                        ),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<InlineSpan> _inline(BuildContext context, List<dom.Node> nodes) {
    final result = <InlineSpan>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        result.add(TextSpan(text: node.data));
        continue;
      }
      if (node is! dom.Element) continue;
      final base = DefaultTextStyle.of(context).style;
      TextStyle? style;
      switch (node.localName) {
        case 'strong':
        case 'b':
          style = base.copyWith(fontWeight: FontWeight.w700);
        case 'em':
        case 'i':
          style = base.copyWith(fontStyle: FontStyle.italic);
        case 'code':
          style = base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
          );
        case 'a':
          style = base.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          );
        case 'del':
        case 's':
          style = base.copyWith(decoration: TextDecoration.lineThrough);
        case 'br':
          result.add(const TextSpan(text: '\n'));
          continue;
      }
      result.add(
        TextSpan(style: style, children: _inline(context, node.nodes)),
      );
    }
    return result;
  }
}

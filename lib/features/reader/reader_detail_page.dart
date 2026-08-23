import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/reader/native_html_view.dart';
import 'package:moyue_application/features/reader/webview_html_view.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/services/system_share_service.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';
import 'package:moyue_application/widgets/image_lightbox.dart';
import 'package:moyue_application/widgets/moyue_action_menu.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';

class ReaderDetailPage extends StatefulWidget {
  const ReaderDetailPage({required this.document, super.key});
  final ReadingDocument document;

  @override
  State<ReaderDetailPage> createState() => _ReaderDetailPageState();
}

/// 禁用路由快照，让 Android 预见性返回始终移动包含 premium 玻璃层的
/// 实时阅读器子树，避免独立折射层与旧页面快照叠帧。
Route<void> readerDetailRoute(ReadingDocument document) =>
    MaterialPageRoute<void>(
      allowSnapshotting: false,
      builder: (_) => ReaderDetailPage(document: document),
    );

class _ReaderDetailPageState extends State<ReaderDetailPage> {
  double _textScale = 1;
  late ReadingDocument _document;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<NativeHtmlViewState> _htmlKey =
      GlobalKey<NativeHtmlViewState>();
  final GlobalKey<WebViewHtmlViewState> _webViewKey =
      GlobalKey<WebViewHtmlViewState>();
  final Map<int, GlobalKey> _markdownHeadingKeys = {};

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    MoyueStorageService.instance.addListener(_reloadDocument);
  }

  @override
  void dispose() {
    MoyueStorageService.instance.removeListener(_reloadDocument);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = DisplayPreferencesScope.maybeOf(context);
    final readerTopInset = MediaQuery.paddingOf(context).top + 72;
    final readerBottomInset = MediaQuery.paddingOf(context).bottom + 92;
    final useWebView =
        _document.kind == DocumentKind.html &&
        (display?.htmlWebViewEnabled ?? false);
    for (final heading in _headings) {
      _markdownHeadingKeys.putIfAbsent(heading.index, GlobalKey.new);
    }
    return RepaintBoundary(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(_textScale)),
                child: _document.kind == DocumentKind.markdown
                    ? _MarkdownDocument(
                        data: _document.content,
                        document: _document,
                        topInset: readerTopInset,
                        controller: _scrollController,
                        headingKeys: _markdownHeadingKeys,
                        bottomInset: readerBottomInset,
                      )
                    : useWebView
                    ? WebViewHtmlView(
                        key: _webViewKey,
                        data: _document.content,
                        resourceLoader: (source) => MoyueStorageService.instance
                            .readLinkedResource(_document, source),
                        topInset: readerTopInset,
                        bottomInset: readerBottomInset,
                        textScale: _textScale,
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          readerTopInset,
                          24,
                          readerBottomInset,
                        ),
                        child: NativeHtmlView(
                          key: _htmlKey,
                          data: _document.content,
                          resourceLoader: (source) => MoyueStorageService
                              .instance
                              .readLinkedResource(_document, source),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: FloatingDocumentHeader(
                    title: _document.title,
                    onBack: () => Navigator.of(context).pop(),
                    actionIcon: Icons.edit_outlined,
                    actionLabel: '编辑 Markdown',
                    onAction: _document.kind == DocumentKind.markdown
                        ? _editDocument
                        : null,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              height: 64,
              child: _ReaderToolbar(
                onTableOfContents: _showTableOfContents,
                onDecreaseText: () => setState(
                  () => _textScale = (_textScale - 0.1).clamp(0.8, 1.4),
                ),
                onIncreaseText: () => setState(
                  () => _textScale = (_textScale + 0.1).clamp(0.8, 1.4),
                ),
                onShare: _shareDocument,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editDocument() {
    Navigator.of(context).restorablePush<ReadingDocument?>(
      markdownEditorRoute,
      arguments: markdownEditorArguments(_document),
    );
  }

  Future<void> _reloadDocument() async {
    final documents = await MoyueStorageService.instance.loadDocuments();
    final folders = await MoyueStorageService.instance.loadFolders();
    final allDocuments = [
      ...documents,
      ...folders.expand((folder) => folder.documents),
    ];
    final matches = allDocuments.where(
      (item) => item.filePath == _document.filePath,
    );
    if (mounted && matches.isNotEmpty) {
      setState(() => _document = matches.first);
    }
  }

  List<_ReaderHeading> get _headings {
    if (_document.kind == DocumentKind.markdown) {
      final nodes = md.Document(extensionSet: md.ExtensionSet.gitHubWeb)
          .parseLines(_document.content.split('\n'));
      final headingElements = <md.Element>[];
      void collect(md.Node node) {
        if (node is! md.Element) return;
        if (RegExp(r'^h[1-6]$').hasMatch(node.tag)) {
          headingElements.add(node);
          return;
        }
        for (final child in node.children ?? const <md.Node>[]) {
          collect(child);
        }
      }

      for (final node in nodes) {
        collect(node);
      }
      var index = 0;
      var searchOffset = 0;
      return headingElements
          .map((element) {
            final title = element.textContent.trim();
            final offset = _document.content.indexOf(title, searchOffset);
            if (offset >= 0) searchOffset = offset + title.length;
            return _ReaderHeading(
              index: index++,
              level: int.parse(element.tag.substring(1)),
              title: title,
              offset: offset < 0 ? 0 : offset,
            );
          })
          .toList(growable: false);
    }
    final matches = RegExp(
      r'<h([1-6])(?:\s[^>]*)?>([\s\S]*?)</h\1>',
      caseSensitive: false,
    ).allMatches(_document.content);
    return matches.indexed
        .map(
          (entry) => _ReaderHeading(
            index: entry.$1,
            level: int.parse(entry.$2.group(1)!),
            title: entry.$2.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
            offset: entry.$2.start,
          ),
        )
        .where((heading) => heading.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _showTableOfContents() async {
    final headings = _headings;
    if (headings.isEmpty) {
      _message('当前文档没有标题目录');
      return;
    }
    final selected = await showMoyueActionMenu<_ReaderHeading>(
      context: context,
      title: '目录',
      message: '选择标题以跳转',
      actions: [
        for (final heading in headings)
          MoyueMenuAction(
            value: heading,
            label: heading.title,
            icon: heading.level <= 2
                ? Icons.segment_rounded
                : Icons.subdirectory_arrow_right_rounded,
            indentLevel: heading.level - 1,
          ),
      ],
    );
    if (selected != null && mounted) await _scrollToHeading(selected);
  }

  Future<void> _scrollToHeading(_ReaderHeading heading) async {
    if (_document.kind == DocumentKind.html) {
      if ((DisplayPreferencesScope.maybeOf(context)?.htmlWebViewEnabled ??
              false) &&
          await _webViewKey.currentState?.scrollToHeading(heading.index) ==
              true) {
        return;
      }
      if (await _htmlKey.currentState?.scrollToHeading(heading.index) == true) {
        return;
      }
    } else {
      final headingContext =
          _markdownHeadingKeys[heading.index]?.currentContext;
      if (headingContext != null) {
        await Scrollable.ensureVisible(
          headingContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.04,
        );
        return;
      }
    }
    if (!_scrollController.hasClients) return;
    final length = _document.content.length;
    final ratio = length == 0 ? 0.0 : heading.offset / length;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent * ratio,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _shareDocument() async {
    try {
      await SystemShareService.shareDocument(context, _document);
    } on Object catch (error) {
      if (mounted) _message('分享失败：$error');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReaderHeading {
  const _ReaderHeading({
    required this.index,
    required this.level,
    required this.title,
    required this.offset,
  });

  final int index;
  final int level;
  final String title;
  final int offset;
}

class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({
    required this.onTableOfContents,
    required this.onDecreaseText,
    required this.onIncreaseText,
    required this.onShare,
  });

  final VoidCallback onTableOfContents;
  final VoidCallback onDecreaseText;
  final VoidCallback onIncreaseText;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          context,
          icon: Icons.format_list_bulleted_rounded,
          label: '目录',
          onPressed: onTableOfContents,
        ),
        const SizedBox(width: 8),
        _button(
          context,
          icon: Icons.text_decrease_rounded,
          label: '缩小字体',
          onPressed: onDecreaseText,
        ),
        const SizedBox(width: 8),
        _button(
          context,
          icon: Icons.text_increase_rounded,
          label: '放大字体',
          onPressed: onIncreaseText,
        ),
        const SizedBox(width: 8),
        _button(
          context,
          icon: Icons.ios_share_rounded,
          label: '分享文档',
          onPressed: onShare,
        ),
      ],
    ),
  );

  Widget _button(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => MoyueGlassIconButton(
    icon: Icon(icon),
    onPressed: onPressed,
    semanticLabel: label,
    size: 48,
    useOwnLayer: true,
    settings: moyueGlassSettings(context),
  );
}

class _MarkdownDocument extends StatelessWidget {
  const _MarkdownDocument({
    required this.data,
    required this.document,
    required this.topInset,
    required this.controller,
    required this.headingKeys,
    required this.bottomInset,
  });
  final String data;
  final ReadingDocument document;
  final double topInset;
  final ScrollController controller;
  final Map<int, GlobalKey> headingKeys;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge!;
    final headingAllocator = _MarkdownHeadingAllocator(headingKeys);
    return Markdown(
      data: data,
      controller: controller,
      selectable: true,
      padding: EdgeInsets.fromLTRB(24, topInset, 24, bottomInset),
      builders: {
        for (final tag in const ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'])
          tag: _MarkdownHeadingBuilder(headingAllocator),
      },
      imageBuilder: (uri, title, alt) => FutureBuilder<Uint8List?>(
        future: MoyueStorageService.instance.readLinkedResource(
          document,
          uri.toString(),
        ),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const SizedBox(
              height: 80,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            );
          }
          return GestureDetector(
            onTap: () => unawaited(ImageLightbox.show(context, bytes)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          );
        },
      ),
      onTapLink: (_, href, _) async {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: body,
        h1: theme.textTheme.headlineLarge?.copyWith(height: 1.35),
        h2: theme.textTheme.headlineMedium?.copyWith(height: 1.4),
        h3: theme.textTheme.titleLarge?.copyWith(height: 1.4),
        h4: theme.textTheme.titleMedium,
        blockquote: body.copyWith(color: theme.colorScheme.onSurfaceVariant),
        blockquotePadding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.54,
          ),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockPadding: const EdgeInsets.all(16),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        listBullet: body.copyWith(color: theme.colorScheme.primary),
        a: body.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}

class _MarkdownHeadingAllocator {
  _MarkdownHeadingAllocator(this.keys);
  final Map<int, GlobalKey> keys;
  int _next = 0;
  GlobalKey? take() => keys[_next++];
}

class _MarkdownHeadingBuilder extends MarkdownElementBuilder {
  _MarkdownHeadingBuilder(this.allocator);
  final _MarkdownHeadingAllocator allocator;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Padding(
    key: allocator.take(),
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(element.textContent, style: preferredStyle),
  );
}

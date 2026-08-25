import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/core/display/moyue_markdown_style.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/reader/native_html_view.dart';
import 'package:moyue_application/features/reader/reader_overlay_tone_sampler.dart';
import 'package:moyue_application/features/reader/webview_html_view.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/services/ink_image_processor.dart';
import 'package:moyue_application/services/system_share_service.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';
import 'package:moyue_application/widgets/image_lightbox.dart';
import 'package:moyue_application/widgets/moyue_action_menu.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';
import 'package:moyue_application/widgets/moyue_transient_message.dart';
import 'package:moyue_application/widgets/stable_reader_image.dart';
import 'package:moyue_application/widgets/ink_refresh_overlay.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';
import 'package:url_launcher/url_launcher.dart';

class ReaderDetailPage extends StatefulWidget {
  const ReaderDetailPage({required this.document, super.key});
  final ReadingDocument document;

  @override
  State<ReaderDetailPage> createState() => _ReaderDetailPageState();
}

/// 禁用路由快照，让 Android 预见性返回始终移动包含 premium 玻璃层的
/// 实时阅读器子树，避免独立折射层与旧页面快照叠帧。
Route<void> readerDetailRoute(BuildContext context, ReadingDocument document) =>
    moyuePageRoute<void>(
      context: context,
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
  final ReaderImageSessionCache _imageCache = ReaderImageSessionCache();
  final GlobalKey<_InkPaginatedMarkdownState> _inkMarkdownKey = GlobalKey();
  final GlobalKey<_InkPaginatedHtmlState> _inkHtmlKey = GlobalKey();
  bool _readerMenuVisible = false;
  String? _readerMessage;
  Timer? _readerMessageTimer;
  Timer? _pageHintTimer;
  ReaderOverlayTone? _overlayTone;
  bool _showInkPageHint = false;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    MoyueStorageService.instance.addListener(_reloadDocument);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInkDocument());
  }

  @override
  void dispose() {
    MoyueStorageService.instance.removeListener(_reloadDocument);
    _readerMessageTimer?.cancel();
    _pageHintTimer?.cancel();
    _scrollController.dispose();
    _imageCache.clear();
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
    final inkPaginated = (display?.isInkMode ?? false) && !useWebView;
    final readerSurface = _document.kind == DocumentKind.markdown
        ? moyueMarkdownPaletteOf(context).surface
        : theme.colorScheme.surface;
    final fallbackBrightness = ThemeData.estimateBrightnessForColor(
      readerSurface,
    );
    final headerForeground = _overlayForeground(
      _overlayTone?.top ?? fallbackBrightness,
    );
    final toolbarForeground = _overlayForeground(
      _overlayTone?.bottom ?? fallbackBrightness,
    );
    final mediaQuery = MediaQuery.of(context);
    final readerContent = MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(_textScale)),
      child: _document.kind == DocumentKind.markdown
          ? inkPaginated
                ? _InkPaginatedMarkdown(
                    key: _inkMarkdownKey,
                    data: _document.content,
                    document: _document,
                    topInset: readerTopInset,
                    bottomInset: readerBottomInset,
                    imageCache: _imageCache,
                    showPageHint: _showInkPageHint,
                    onPageTurn: _dismissPageHint,
                  )
                : _MarkdownDocument(
                    data: _document.content,
                    document: _document,
                    topInset: readerTopInset,
                    controller: _scrollController,
                    headingKeys: _markdownHeadingKeys,
                    bottomInset: readerBottomInset,
                    imageCache: _imageCache,
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
              fallbackSurfaceColor: readerSurface,
              onOverlayBrightnessChanged: _updateOverlayTone,
            )
          : inkPaginated
          ? _InkPaginatedHtml(
              key: _inkHtmlKey,
              data: _document.content,
              document: _document,
              topInset: readerTopInset,
              bottomInset: readerBottomInset,
              imageCache: _imageCache,
              showPageHint: _showInkPageHint,
              onPageTurn: _dismissPageHint,
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
                resourceCacheKey: _document.id,
                imageCache: _imageCache,
                resourceLoader: (source) => MoyueStorageService.instance
                    .readLinkedResource(_document, source),
              ),
            ),
    );
    for (final heading in _headings) {
      _markdownHeadingKeys.putIfAbsent(heading.index, GlobalKey.new);
    }
    return RepaintBoundary(
      child: Scaffold(
        backgroundColor: readerSurface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: useWebView
                  ? ColoredBox(color: readerSurface, child: readerContent)
                  : ReaderOverlayToneSampler(
                      backgroundColor: readerSurface,
                      topSampleY: readerTopInset - 43,
                      bottomSampleY:
                          mediaQuery.size.height - readerBottomInset + 48,
                      onChanged: _updateOverlayTone,
                      child: readerContent,
                    ),
            ),
            if ((display?.isInkMode ?? false) && !useWebView)
              const Positioned.fill(child: MoyueInkPaperTexture()),
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
                    actionLabel: context.l10n.editMarkdown,
                    onAction: _document.kind == DocumentKind.markdown
                        ? _editDocument
                        : null,
                    foregroundColor: headerForeground,
                  ),
                ),
              ),
            ),
            if (!_readerMenuVisible)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                height: 64,
                child: _ReaderToolbar(
                  showTextControls: !useWebView,
                  textControlsEnabled: !(display?.isInkMode ?? false),
                  onTableOfContents: _showTableOfContents,
                  onDecreaseText: () => setState(
                    () => _textScale = (_textScale - 0.1).clamp(0.8, 1.4),
                  ),
                  onIncreaseText: () => setState(
                    () => _textScale = (_textScale + 0.1).clamp(0.8, 1.4),
                  ),
                  onShare: _shareDocument,
                  foregroundColor: toolbarForeground,
                ),
              ),
            Positioned.fill(
              child: MoyueTransientMessageOverlay(
                message: _readerMessage,
                bottomInset: MediaQuery.paddingOf(context).bottom + 88,
                onDismiss: _dismissMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInkDocument() async {
    if (!mounted) return;
    final display = DisplayPreferencesScope.maybeOf(context);
    final useWebView =
        _document.kind == DocumentKind.html &&
        (display?.htmlWebViewEnabled ?? false);
    await InkRefreshOverlay.maybeOf(context)?.refresh();
    if (!mounted || !(display?.isInkMode ?? false) || useWebView) return;
    setState(() => _showInkPageHint = true);
    _pageHintTimer?.cancel();
    _pageHintTimer = Timer(const Duration(seconds: 2), _dismissPageHint);
  }

  void _dismissPageHint() {
    _pageHintTimer?.cancel();
    if (mounted && _showInkPageHint) {
      setState(() => _showInkPageHint = false);
    }
  }

  Color _overlayForeground(Brightness background) {
    final ink = Theme.of(context).extension<MoyueInkTheme>();
    if (ink?.enabled ?? false) {
      return background == Brightness.dark
          ? ink!.grayRamp[14]
          : ink!.grayRamp[0];
    }
    return background == Brightness.dark ? Colors.white : Colors.black;
  }

  void _updateOverlayTone(ReaderOverlayTone tone) {
    if (!mounted ||
        (_overlayTone?.top == tone.top &&
            _overlayTone?.bottom == tone.bottom)) {
      return;
    }
    setState(() => _overlayTone = tone);
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
      final next = matches.first;
      if (next.content != _document.content ||
          next.updatedAt != _document.updatedAt) {
        _imageCache.clear();
      }
      setState(() => _document = next);
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
      _message(context.l10n.documentHasNoHeadings);
      return;
    }
    final selected = await _showReaderActionMenu<_ReaderHeading>(
      title: context.l10n.tableOfContents,
      message: context.l10n.chooseHeadingToJump,
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
    final reduceMotion =
        DisplayPreferencesScope.maybeOf(context)?.reduceMotion ?? false;
    final inkMode =
        DisplayPreferencesScope.maybeOf(context)?.isInkMode ?? false;
    if (inkMode && _document.kind == DocumentKind.markdown) {
      await _inkMarkdownKey.currentState?.jumpToSourceOffset(heading.offset);
      if (!mounted) return;
      await InkRefreshOverlay.maybeOf(context)?.refresh();
      return;
    }
    if (inkMode &&
        _document.kind == DocumentKind.html &&
        !(DisplayPreferencesScope.maybeOf(context)?.htmlWebViewEnabled ??
            false)) {
      await _inkHtmlKey.currentState?.jumpToSourceOffset(heading.offset);
      if (!mounted) return;
      await InkRefreshOverlay.maybeOf(context)?.refresh();
      return;
    }
    if (_document.kind == DocumentKind.html) {
      if ((DisplayPreferencesScope.maybeOf(context)?.htmlWebViewEnabled ??
              false) &&
          await _webViewKey.currentState?.scrollToHeading(heading.index) ==
              true) {
        if (mounted) await InkRefreshOverlay.maybeOf(context)?.refresh();
        return;
      }
      if (await _htmlKey.currentState?.scrollToHeading(heading.index) == true) {
        if (mounted) await InkRefreshOverlay.maybeOf(context)?.refresh();
        return;
      }
    } else {
      final headingContext =
          _markdownHeadingKeys[heading.index]?.currentContext;
      if (headingContext != null) {
        final duration = moyueMotionDuration(
          context,
          const Duration(milliseconds: 320),
        );
        await Scrollable.ensureVisible(
          headingContext,
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: 0.04,
        );
        return;
      }
    }
    if (!_scrollController.hasClients) return;
    final length = _document.content.length;
    final ratio = length == 0 ? 0.0 : heading.offset / length;
    final offset = _scrollController.position.maxScrollExtent * ratio;
    if (reduceMotion) {
      _scrollController.jumpTo(offset);
    } else {
      await _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _shareDocument() async {
    try {
      if (_document.kind == DocumentKind.html) {
        await SystemShareService.shareDocument(context, _document);
        return;
      }
      final option = await _showReaderActionMenu<_MarkdownShareOption>(
        title: context.l10n.shareMarkdown,
        message: context.l10n.chooseMarkdownShareFormat,
        actions: [
          MoyueMenuAction(
            value: _MarkdownShareOption.file,
            label: context.l10n.shareAsFile,
            icon: Icons.description_outlined,
          ),
          MoyueMenuAction(
            value: _MarkdownShareOption.text,
            label: context.l10n.shareAsText,
            icon: Icons.text_snippet_outlined,
          ),
          MoyueMenuAction(
            value: _MarkdownShareOption.image,
            label: context.l10n.shareAsImage,
            icon: Icons.image_outlined,
          ),
        ],
      );
      if (option == null || !mounted) return;
      switch (option) {
        case _MarkdownShareOption.file:
          await SystemShareService.shareDocument(context, _document);
          return;
        case _MarkdownShareOption.text:
          await SystemShareService.shareText(
            context,
            text: _document.content,
            subject: _document.title,
          );
          return;
        case _MarkdownShareOption.image:
          final bytes = await _captureEntireMarkdown();
          if (!mounted) return;
          await SystemShareService.shareMarkdownImage(
            context,
            bytes: bytes,
            title: _document.title,
          );
          return;
      }
    } on Object catch (error) {
      if (mounted) _message(context.l10n.shareDocumentFailed('$error'));
    }
  }

  Future<T?> _showReaderActionMenu<T>({
    required List<MoyueMenuAction<T>> actions,
    String? title,
    String? message,
  }) async {
    if (_readerMenuVisible) return null;
    setState(() => _readerMenuVisible = true);
    try {
      return await showMoyueActionMenu<T>(
        context: context,
        title: title,
        message: message,
        actions: actions,
      );
    } finally {
      if (mounted) setState(() => _readerMenuVisible = false);
    }
  }

  Future<Uint8List> _captureEntireMarkdown() async {
    final errorMessage = context.l10n.cannotCreateShareImage;
    final rootOverlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();
    final captureWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      320.0,
      680.0,
    );
    final deviceRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.5);
    final loadedImages = await _loadMarkdownShareImages();
    if (!mounted) {
      for (final image in loadedImages.values) {
        image.dispose();
      }
      throw StateError(errorMessage);
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            // RenderOpacity quantizes alpha to 8 bits. Keep it just above the
            // zero-alpha paint cutoff so the temporary boundary is genuinely
            // painted while remaining visually imperceptible.
            opacity: 1 / 255,
            child: SingleChildScrollView(
              clipBehavior: Clip.none,
              child: Align(
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(_textScale)),
                    child: Material(
                      color: moyueMarkdownPaletteOf(context).surface,
                      child: SizedBox(
                        width: captureWidth,
                        child: _MarkdownShareCanvas(
                          data: _document.content,
                          images: loadedImages,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    rootOverlay.insert(entry);
    ui.Image? image;
    try {
      final boundary = await _waitForPaintedBoundary(boundaryKey, errorMessage);
      final size = boundary.size;
      // Keep one complete image while respecting common GPU texture and
      // memory limits. Very long notes are proportionally downsampled rather
      // than truncated to the visible viewport.
      final dimensionRatio = 16000 / math.max(size.width, size.height);
      final areaRatio = math.sqrt(
        40000000 / math.max(1, size.width * size.height),
      );
      final pixelRatio = math.min(
        deviceRatio,
        math.min(dimensionRatio, areaRatio),
      );
      if (pixelRatio < 0.2) throw StateError(errorMessage);
      image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError(errorMessage);
      return data.buffer.asUint8List();
    } finally {
      image?.dispose();
      entry.remove();
      // Unmount the temporary canvas before disposing the static image frames
      // referenced by RawImage widgets inside it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final loadedImage in loadedImages.values) {
          loadedImage.dispose();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  Future<RenderRepaintBoundary> _waitForPaintedBoundary(
    GlobalKey boundaryKey,
    String errorMessage,
  ) async {
    // Markdown layout and image decoding can each request an additional frame.
    // Explicitly schedule fresh frames because awaiting endOfFrame twice can
    // otherwise observe the same already-completed frame.
    for (var attempt = 0; attempt < 8; attempt++) {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is RenderRepaintBoundary &&
          renderObject.hasSize &&
          !renderObject.debugNeedsLayout &&
          !renderObject.debugNeedsPaint) {
        return renderObject;
      }
    }
    throw StateError(errorMessage);
  }

  Future<Map<String, ui.Image>> _loadMarkdownShareImages() async {
    final sources = <String>{};
    final nodes = md.Document(extensionSet: md.ExtensionSet.gitHubWeb)
        .parseLines(_document.content.split('\n'));
    void collect(md.Node node) {
      if (node is! md.Element) return;
      if (node.tag == 'img') {
        final source = node.attributes['src'];
        if (source != null && source.isNotEmpty) sources.add(source);
      }
      for (final child in node.children ?? const <md.Node>[]) {
        collect(child);
      }
    }

    for (final node in nodes) {
      collect(node);
    }
    final result = <String, ui.Image>{};
    final display = DisplayPreferencesScope.maybeOf(context);
    final inkMode = display?.isInkMode ?? false;
    final inkDark = Theme.of(context).brightness == Brightness.dark;
    for (final source in sources) {
      final bytes = await MoyueStorageService.instance.readLinkedResource(
        _document,
        source,
      );
      if (bytes == null) continue;
      if (inkMode) {
        final image = await InkImageProcessor.process(
          bytes,
          dark: inkDark,
          maximumDimension: 2048,
        );
        if (image != null) result[source] = image;
        continue;
      }
      ui.Codec? codec;
      try {
        // Freeze animated GIF/WebP images at their first frame. Otherwise the
        // animation continuously dirties the RepaintBoundary during capture.
        codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        result[source] = frame.image;
      } on Object {
        // Broken images keep a stable placeholder in the shared layout.
      } finally {
        codec?.dispose();
      }
    }
    return result;
  }

  void _message(String message) {
    _readerMessageTimer?.cancel();
    setState(() => _readerMessage = message);
    _readerMessageTimer = Timer(const Duration(seconds: 4), _dismissMessage);
  }

  void _dismissMessage() {
    _readerMessageTimer?.cancel();
    _readerMessageTimer = null;
    if (!mounted || _readerMessage == null) return;
    setState(() => _readerMessage = null);
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

enum _MarkdownShareOption { file, text, image }

class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({
    required this.showTextControls,
    required this.textControlsEnabled,
    required this.onTableOfContents,
    required this.onDecreaseText,
    required this.onIncreaseText,
    required this.onShare,
    required this.foregroundColor,
  });

  final bool showTextControls;
  final bool textControlsEnabled;
  final VoidCallback onTableOfContents;
  final VoidCallback onDecreaseText;
  final VoidCallback onIncreaseText;
  final VoidCallback onShare;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(
            context,
            icon: Icons.format_list_bulleted_rounded,
            label: l10n.tableOfContents,
            onPressed: onTableOfContents,
            foregroundColor: foregroundColor,
          ),
          if (showTextControls) ...[
            const SizedBox(width: 8),
            _button(
              context,
              icon: Icons.text_decrease_rounded,
              label: l10n.decreaseFontSize,
              onPressed: textControlsEnabled ? onDecreaseText : null,
              foregroundColor: foregroundColor,
            ),
            const SizedBox(width: 8),
            _button(
              context,
              icon: Icons.text_increase_rounded,
              label: l10n.increaseFontSize,
              onPressed: textControlsEnabled ? onIncreaseText : null,
              foregroundColor: foregroundColor,
            ),
          ],
          const SizedBox(width: 8),
          _button(
            context,
            icon: Icons.ios_share_rounded,
            label: l10n.shareDocument,
            onPressed: onShare,
            foregroundColor: foregroundColor,
          ),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color foregroundColor,
  }) => MoyueGlassIconButton(
    icon: Icon(icon),
    onPressed: onPressed,
    semanticLabel: label,
    foregroundColor: foregroundColor,
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
    required this.imageCache,
  });
  final String data;
  final ReadingDocument document;
  final double topInset;
  final ScrollController controller;
  final Map<int, GlobalKey> headingKeys;
  final double bottomInset;
  final ReaderImageSessionCache imageCache;

  @override
  Widget build(BuildContext context) {
    final headingAllocator = _MarkdownHeadingAllocator(headingKeys);
    return Markdown(
      data: data,
      controller: controller,
      selectable: true,
      padding: EdgeInsets.fromLTRB(24, topInset, 24, bottomInset),
      builders: {
        'pre': buildMoyueCodeBlockBuilder(context),
        for (final tag in const ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'])
          tag: _MarkdownHeadingBuilder(headingAllocator),
      },
      imageBuilder: (uri, title, alt) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: StableReaderImage(
          cacheKey: '${document.id}:${uri.toString()}',
          sessionCache: imageCache,
          loader: () => MoyueStorageService.instance.readLinkedResource(
            document,
            uri.toString(),
          ),
          fit: BoxFit.contain,
          semanticLabel: alt,
          onTap: (bytes) => unawaited(ImageLightbox.show(context, bytes)),
        ),
      ),
      onTapLink: (_, href, _) async {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: buildMoyueMarkdownStyleSheet(context),
    );
  }
}

class _InkPaginatedMarkdown extends StatefulWidget {
  const _InkPaginatedMarkdown({
    required this.data,
    required this.document,
    required this.topInset,
    required this.bottomInset,
    required this.imageCache,
    required this.showPageHint,
    required this.onPageTurn,
    super.key,
  });

  final String data;
  final ReadingDocument document;
  final double topInset;
  final double bottomInset;
  final ReaderImageSessionCache imageCache;
  final bool showPageHint;
  final VoidCallback onPageTurn;

  @override
  State<_InkPaginatedMarkdown> createState() => _InkPaginatedMarkdownState();
}

class _InkPaginatedMarkdownState extends State<_InkPaginatedMarkdown> {
  static final Map<String, int> _sessionPages = <String, int>{};
  _InkPaginationRunner? _pagination;
  Object? _layoutSignature;
  int _page = 0;
  late int _desiredPage = _sessionPages[widget.document.id] ?? 0;
  int? _pendingPage;
  int? _pendingSourceOffset;
  Completer<void>? _pendingJump;

  @override
  void dispose() {
    _pagination?.dispose();
    _pendingJump?.complete();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _InkPaginatedMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.document.id != widget.document.id) {
      _layoutSignature = null;
      _pagination?.dispose();
      _pagination = null;
      _page = 0;
      _desiredPage = _sessionPages[widget.document.id] ?? 0;
      _pendingPage = null;
      _pendingSourceOffset = null;
      _pendingJump?.complete();
      _pendingJump = null;
    }
  }

  Future<void> jumpToSourceOffset(int offset) async {
    final pages = _pagination?.pages ?? const <_InkSourcePage>[];
    final index = pages.indexWhere(
      (page) => offset >= page.start && offset < page.end,
    );
    if (index >= 0) {
      _commitPage(index, refresh: false);
      return;
    }
    if (_pagination?.complete ?? true) return;
    _pendingSourceOffset = offset;
    _pendingJump?.complete();
    final completer = Completer<void>();
    _pendingJump = completer;
    _pagination?.boost();
    await completer.future;
  }

  void _setPage(int next, {bool refresh = true}) {
    final pagination = _pagination;
    if (pagination == null || pagination.pages.isEmpty) return;
    if (next >= pagination.pages.length && !pagination.complete) {
      _pendingPage = next;
      pagination.boost();
      return;
    }
    final target = next.clamp(0, pagination.pages.length - 1);
    if (target == _page) return;
    _commitPage(target, refresh: refresh);
  }

  void _commitPage(int target, {required bool refresh}) {
    if (target == _page && _pagination?.pages.isNotEmpty == true) return;
    setState(() => _page = target);
    _sessionPages[widget.document.id] = target;
    widget.onPageTurn();
    if (refresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(InkRefreshOverlay.maybeOf(context)?.refresh());
        }
      });
    }
  }

  void _onPaginationProgress() {
    if (!mounted) return;
    final pagination = _pagination;
    if (pagination == null) return;
    var rebuild = pagination.pages.length == 1 || pagination.complete;
    int? target;
    var refresh = false;
    final offset = _pendingSourceOffset;
    if (offset != null) {
      final index = pagination.pages.indexWhere(
        (page) => offset >= page.start && offset < page.end,
      );
      if (index >= 0 || pagination.complete) {
        target = index >= 0 ? index : _page;
        _pendingSourceOffset = null;
        final completer = _pendingJump;
        _pendingJump = null;
        if (completer != null && !completer.isCompleted) completer.complete();
      }
    } else if (_pendingPage != null &&
        _pendingPage! < pagination.pages.length) {
      target = _pendingPage;
      _pendingPage = null;
      refresh = true;
    } else if (_desiredPage > 0 && _desiredPage < pagination.pages.length) {
      target = _desiredPage;
      _desiredPage = 0;
    }
    if (target != null && target != _page) {
      _commitPage(target, refresh: refresh);
      return;
    }
    if (rebuild) setState(() {});
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(1.0, constraints.maxWidth - 48);
      final height = math.max(
        1.0,
        constraints.maxHeight - widget.topInset - widget.bottomInset,
      );
      final style = Theme.of(context).textTheme.bodyLarge!;
      final signature = Object.hash(
        widget.data,
        width.round(),
        height.round(),
        style.fontSize,
        style.fontFamily,
      );
      if (_layoutSignature != signature) {
        _layoutSignature = signature;
        _pagination?.dispose();
        _pagination = _InkPaginationRunner(
          pages: _paginateMarkdownPages(
            widget.data,
            width: width,
            height: height,
            style: style.copyWith(height: 1.9),
          ),
          onProgress: _onPaginationProgress,
        )..start();
        _page = 0;
      }
      final pagination = _pagination!;
      if (pagination.pages.isEmpty) {
        if (!pagination.complete) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        pagination.pages.add(
          _InkSourcePage(
            content: widget.data,
            start: 0,
            end: widget.data.length,
          ),
        );
      }
      _page = _page.clamp(0, pagination.pages.length - 1);
      final page = pagination.pages[_page];
      return _InkPageTurnRegion(
        page: _page,
        pageCount: pagination.complete ? pagination.pages.length : null,
        onPrevious: () => _setPage(_page - 1),
        onNext: () => _setPage(_page + 1),
        showHint: widget.showPageHint,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            widget.topInset,
            24,
            widget.bottomInset,
          ),
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: MarkdownBody(
                data: page.content,
                selectable: true,
                builders: {'pre': buildMoyueCodeBlockBuilder(context)},
                imageBuilder: (uri, title, alt) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: StableReaderImage(
                    cacheKey: '${widget.document.id}:${uri.toString()}',
                    sessionCache: widget.imageCache,
                    loader: () => MoyueStorageService.instance
                        .readLinkedResource(widget.document, uri.toString()),
                    fit: BoxFit.contain,
                    semanticLabel: alt,
                    onTap: (bytes) =>
                        unawaited(ImageLightbox.show(context, bytes)),
                  ),
                ),
                onTapLink: (_, href, _) async {
                  final uri = href == null ? null : Uri.tryParse(href);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                styleSheet: buildMoyueMarkdownStyleSheet(context),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _InkPaginatedHtml extends StatefulWidget {
  const _InkPaginatedHtml({
    required this.data,
    required this.document,
    required this.topInset,
    required this.bottomInset,
    required this.imageCache,
    required this.showPageHint,
    required this.onPageTurn,
    super.key,
  });

  final String data;
  final ReadingDocument document;
  final double topInset;
  final double bottomInset;
  final ReaderImageSessionCache imageCache;
  final bool showPageHint;
  final VoidCallback onPageTurn;

  @override
  State<_InkPaginatedHtml> createState() => _InkPaginatedHtmlState();
}

class _InkPaginatedHtmlState extends State<_InkPaginatedHtml> {
  static final Map<String, int> _sessionPages = <String, int>{};
  _InkPaginationRunner? _pagination;
  Object? _layoutSignature;
  int _page = 0;
  late int _desiredPage = _sessionPages[widget.document.id] ?? 0;
  int? _pendingPage;
  int? _pendingSourceOffset;
  Completer<void>? _pendingJump;

  @override
  void dispose() {
    _pagination?.dispose();
    _pendingJump?.complete();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _InkPaginatedHtml oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.document.id != widget.document.id) {
      _layoutSignature = null;
      _pagination?.dispose();
      _pagination = null;
      _page = 0;
      _desiredPage = _sessionPages[widget.document.id] ?? 0;
      _pendingPage = null;
      _pendingSourceOffset = null;
      _pendingJump?.complete();
      _pendingJump = null;
    }
  }

  Future<void> jumpToSourceOffset(int offset) async {
    final pages = _pagination?.pages ?? const <_InkSourcePage>[];
    final index = pages.indexWhere(
      (page) => offset >= page.start && offset < page.end,
    );
    if (index >= 0) {
      _commitPage(index, refresh: false);
      return;
    }
    if (_pagination?.complete ?? true) return;
    _pendingSourceOffset = offset;
    _pendingJump?.complete();
    final completer = Completer<void>();
    _pendingJump = completer;
    _pagination?.boost();
    await completer.future;
  }

  void _setPage(int next, {bool refresh = true}) {
    final pagination = _pagination;
    if (pagination == null || pagination.pages.isEmpty) return;
    if (next >= pagination.pages.length && !pagination.complete) {
      _pendingPage = next;
      pagination.boost();
      return;
    }
    final target = next.clamp(0, pagination.pages.length - 1);
    if (target == _page) return;
    _commitPage(target, refresh: refresh);
  }

  void _commitPage(int target, {required bool refresh}) {
    if (target == _page && _pagination?.pages.isNotEmpty == true) return;
    setState(() => _page = target);
    _sessionPages[widget.document.id] = target;
    widget.onPageTurn();
    if (refresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(InkRefreshOverlay.maybeOf(context)?.refresh());
        }
      });
    }
  }

  void _onPaginationProgress() {
    if (!mounted) return;
    final pagination = _pagination;
    if (pagination == null) return;
    final rebuild = pagination.pages.length == 1 || pagination.complete;
    int? target;
    var refresh = false;
    final offset = _pendingSourceOffset;
    if (offset != null) {
      final index = pagination.pages.indexWhere(
        (page) => offset >= page.start && offset < page.end,
      );
      if (index >= 0 || pagination.complete) {
        target = index >= 0 ? index : _page;
        _pendingSourceOffset = null;
        final completer = _pendingJump;
        _pendingJump = null;
        if (completer != null && !completer.isCompleted) completer.complete();
      }
    } else if (_pendingPage != null &&
        _pendingPage! < pagination.pages.length) {
      target = _pendingPage;
      _pendingPage = null;
      refresh = true;
    } else if (_desiredPage > 0 && _desiredPage < pagination.pages.length) {
      target = _desiredPage;
      _desiredPage = 0;
    }
    if (target != null && target != _page) {
      _commitPage(target, refresh: refresh);
      return;
    }
    if (rebuild) setState(() {});
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(1.0, constraints.maxWidth - 48);
      final height = math.max(
        1.0,
        constraints.maxHeight - widget.topInset - widget.bottomInset,
      );
      final signature = Object.hash(
        widget.data,
        width.round(),
        height.round(),
        Theme.of(context).textTheme.bodyLarge?.fontFamily,
      );
      if (_layoutSignature != signature) {
        _layoutSignature = signature;
        _pagination?.dispose();
        _pagination = _InkPaginationRunner(
          pages: _paginateHtmlPages(
            widget.data,
            width: width,
            height: height,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(height: 1.9),
          ),
          onProgress: _onPaginationProgress,
        )..start();
        _page = 0;
      }
      final pagination = _pagination!;
      if (pagination.pages.isEmpty) {
        if (!pagination.complete) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        pagination.pages.add(
          _InkSourcePage(
            content: widget.data,
            start: 0,
            end: widget.data.length,
          ),
        );
      }
      _page = _page.clamp(0, pagination.pages.length - 1);
      final page = pagination.pages[_page];
      return _InkPageTurnRegion(
        page: _page,
        pageCount: pagination.complete ? pagination.pages.length : null,
        onPrevious: () => _setPage(_page - 1),
        onNext: () => _setPage(_page + 1),
        showHint: widget.showPageHint,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            widget.topInset,
            24,
            widget.bottomInset,
          ),
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: NativeHtmlView(
                data: page.content,
                resourceCacheKey: '${widget.document.id}:ink:$_page',
                imageCache: widget.imageCache,
                resourceLoader: (source) => MoyueStorageService.instance
                    .readLinkedResource(widget.document, source),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _InkPageTurnRegion extends StatelessWidget {
  const _InkPageTurnRegion({
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.showHint,
    required this.child,
  });

  final int page;
  final int? pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool showHint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${page + 1} / ${pageCount ?? '…'}',
    child: GestureDetector(
      key: ValueKey('ink-page-${page + 1}-of-${pageCount ?? 'pending'}'),
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final width = MediaQuery.sizeOf(context).width;
        if (details.localPosition.dx <= width * 0.22) {
          onPrevious();
        } else if (details.localPosition.dx >= width * 0.78) {
          onNext();
        }
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 280) {
          onPrevious();
        } else if (velocity < -280) {
          onNext();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          _InkPageTurnHint(visible: showHint, page: page, pageCount: pageCount),
        ],
      ),
    ),
  );
}

class _InkPageTurnHint extends StatelessWidget {
  const _InkPageTurnHint({
    required this.visible,
    required this.page,
    required this.pageCount,
  });

  final bool visible;
  final int page;
  final int? pageCount;

  @override
  Widget build(BuildContext context) {
    final display = DisplayPreferencesScope.maybeOf(context);
    final colors = Theme.of(context).colorScheme;
    final duration = display?.reduceMotion ?? false
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return IgnorePointer(
      child: AnimatedOpacity(
        key: const ValueKey('ink-turn-guidance'),
        opacity: visible ? 1 : 0,
        duration: duration,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: colors.onSurface.withValues(alpha: 0.62),
                  size: 32,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurface.withValues(alpha: 0.62),
                  size: 32,
                ),
              ),
            ),
            Positioned(
              left: 48,
              right: 48,
              bottom: MediaQuery.paddingOf(context).bottom + 104,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.inkPageTurnHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${page + 1} / ${pageCount ?? '…'}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InkPaginationRunner {
  _InkPaginationRunner({
    required Iterable<_InkSourcePage> pages,
    required this.onProgress,
  }) : _iterator = pages.iterator;

  static const batchBudget = Duration(milliseconds: 4);

  final Iterator<_InkSourcePage> _iterator;
  final VoidCallback onProgress;
  final List<_InkSourcePage> pages = <_InkSourcePage>[];
  bool complete = false;
  bool _disposed = false;
  bool _scheduled = false;
  bool _boosted = false;
  Duration lastBatchElapsed = Duration.zero;

  void start() => _schedule();

  void boost() {
    _boosted = true;
    if (!_scheduled) _schedule();
  }

  void dispose() => _disposed = true;

  void _schedule() {
    if (_disposed || complete || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
    WidgetsBinding.instance.scheduleFrame();
  }

  void _pump() {
    _scheduled = false;
    if (_disposed || complete) return;
    final stopwatch = Stopwatch()..start();
    final pageLimit = pages.isEmpty || _boosted ? 2 : 1;
    var processed = 0;
    do {
      final hasPage = _iterator.moveNext();
      if (hasPage) {
        pages.add(_iterator.current);
        processed++;
      } else {
        complete = true;
      }
      if (complete ||
          processed >= pageLimit ||
          stopwatch.elapsed > batchBudget) {
        break;
      }
    } while (true);
    stopwatch.stop();
    lastBatchElapsed = stopwatch.elapsed;
    if (!_disposed) onProgress();
    if (_disposed || complete) return;
    _boosted = false;
    _schedule();
  }
}

class _InkSourcePage {
  const _InkSourcePage({
    required this.content,
    required this.start,
    required this.end,
  });

  final String content;
  final int start;
  final int end;
}

class _InkSourceBlock {
  const _InkSourceBlock({
    required this.content,
    required this.start,
    required this.end,
  });

  final String content;
  final int start;
  final int end;
}

Iterable<_InkSourcePage> _paginateMarkdownPages(
  String source, {
  required double width,
  required double height,
  required TextStyle style,
}) sync* {
  final blocks = _splitMarkdownBlocks(source);
  Iterable<_InkSourceBlock> expandedBlocks() sync* {
    for (final block in blocks) {
      yield* _splitOversizedMarkdownBlock(
        block,
        width: width,
        height: height,
        style: style,
      );
    }
  }

  final iterator = expandedBlocks().iterator;
  if (!iterator.moveNext()) return;
  final current = <_InkSourceBlock>[];
  var used = 0.0;

  _InkSourcePage pageFromCurrent() => _InkSourcePage(
    content: current
        .map((block) => _indentInkParagraph(block.content))
        .join('\n\n'),
    start: current.first.start,
    end: current.last.end,
  );

  var block = iterator.current;
  while (true) {
    final hasNext = iterator.moveNext();
    final nextBlock = hasNext ? iterator.current : null;
    final blockHeight = _estimateMarkdownHeight(block.content, width, style);
    final heading = RegExp(r'^#{1,6}\s').hasMatch(block.content.trimLeft());
    final nextHeight = nextBlock == null
        ? 0.0
        : _estimateMarkdownHeight(nextBlock.content, width, style);
    if (current.isNotEmpty &&
        (used + blockHeight > height ||
            (heading &&
                used + blockHeight + math.min(nextHeight, 96) > height))) {
      yield pageFromCurrent();
      current.clear();
      used = 0;
    }
    current.add(block);
    used += blockHeight;
    if (!hasNext) break;
    block = nextBlock!;
  }
  if (current.isNotEmpty) {
    yield pageFromCurrent();
  }
}

List<_InkSourceBlock> _splitMarkdownBlocks(String source) {
  final lines = source.split('\n');
  final result = <_InkSourceBlock>[];
  final buffer = StringBuffer();
  var offset = 0;
  var blockStart = 0;
  var fenced = false;

  void flush(int end) {
    final content = buffer.toString().trimRight();
    if (content.isNotEmpty) {
      result.add(
        _InkSourceBlock(content: content, start: blockStart, end: end),
      );
    }
    buffer.clear();
  }

  for (final line in lines) {
    final lineStart = offset;
    final lineEnd = lineStart + line.length;
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      fenced = !fenced;
    }
    if (!fenced && line.trim().isEmpty) {
      flush(lineStart);
      blockStart = lineEnd + 1;
    } else {
      if (buffer.isEmpty) blockStart = lineStart;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(line);
    }
    offset = lineEnd + 1;
  }
  flush(source.length);
  return result;
}

List<_InkSourceBlock> _splitOversizedMarkdownBlock(
  _InkSourceBlock block, {
  required double width,
  required double height,
  required TextStyle style,
}) {
  if (_estimateMarkdownHeight(block.content, width, style) <= height) {
    return [block];
  }
  final content = block.content;
  final lines = content.split('\n');
  final lineHeight = (style.fontSize ?? 17) * 1.9;
  final maximumLines = math.max(3, ((height - 64) / lineHeight).floor());
  if (content.trimLeft().startsWith('```') && lines.length > 3) {
    final fence = lines.first;
    final body = lines.sublist(
      1,
      lines.last.trim().startsWith('```') ? lines.length - 1 : lines.length,
    );
    final chunks = <_InkSourceBlock>[];
    for (var index = 0; index < body.length; index += maximumLines) {
      final slice = body.sublist(
        index,
        math.min(body.length, index + maximumLines),
      );
      chunks.add(
        _InkSourceBlock(
          content: '$fence\n${slice.join('\n')}\n```',
          start: block.start,
          end: block.end,
        ),
      );
    }
    return chunks;
  }
  if (!RegExp(r'[\[\]<>*_]').hasMatch(content)) {
    final approximateCharacters = math.max(
      80,
      ((width / ((style.fontSize ?? 17) * 0.94)) * maximumLines).floor(),
    );
    if (content.length > approximateCharacters) {
      final chunks = <_InkSourceBlock>[];
      var start = 0;
      while (start < content.length) {
        var end = math.min(content.length, start + approximateCharacters);
        if (end < content.length) {
          final punctuation = content.lastIndexOf(RegExp(r'[。！？.!?；;]'), end);
          if (punctuation > start + approximateCharacters * 0.55) {
            end = punctuation + 1;
          }
        }
        chunks.add(
          _InkSourceBlock(
            content: content.substring(start, end).trim(),
            start: block.start + start,
            end: block.start + end,
          ),
        );
        start = end;
      }
      return chunks;
    }
  }
  // Rich atomic blocks that cannot be split without breaking Markdown stay on
  // one dedicated page; the page permits local vertical inspection.
  return [block];
}

double _estimateMarkdownHeight(String source, double width, TextStyle style) {
  final trimmed = source.trim();
  if (RegExp(r'^!\[[^\]]*\]\(').hasMatch(trimmed)) return width * 0.64 + 22;
  if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
    return trimmed.split('\n').length * (style.fontSize ?? 17) * 1.52 + 58;
  }
  if (trimmed.startsWith('|') && trimmed.contains('\n|')) {
    return trimmed.split('\n').length * 42 + 20;
  }
  final heading = RegExp(r'^(#{1,6})\s+').firstMatch(trimmed);
  final multiplier = heading == null
      ? 1.0
      : 1.52 - heading.group(1)!.length * 0.08;
  final plain = trimmed
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' image ')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
      .replaceAll(RegExp(r'[`*_>#~-]'), ' ');
  final painter = TextPainter(
    text: TextSpan(
      text: plain,
      style: style.copyWith(fontSize: (style.fontSize ?? 17) * multiplier),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  return painter.height + (heading == null ? 18 : 34);
}

String _indentInkParagraph(String source) {
  final trimmed = source.trimLeft();
  if (trimmed.isEmpty ||
      RegExp(r'^(#{1,6}\s|[-+*]\s|\d+[.)]\s|>|```|~~~|\||!\[|<)')
          .hasMatch(trimmed)) {
    return source;
  }
  return '\u3000\u3000$source';
}

Iterable<_InkSourcePage> _paginateHtmlPages(
  String source, {
  required double width,
  required double height,
  required TextStyle style,
}) sync* {
  final document = html_parser.parse(source);
  final body = document.body;
  if (body == null || body.children.isEmpty) return;
  var elements = body.children.toList(growable: false);
  if (elements.length == 1 &&
      (elements.first.localName == 'main' ||
          elements.first.localName == 'article') &&
      elements.first.children.isNotEmpty) {
    elements = elements.first.children.toList(growable: false);
  }
  final head = document.head?.outerHtml ?? '<head></head>';
  final current = <String>[];
  var currentStart = 0;
  var currentEnd = 0;
  var used = 0.0;
  var searchOffset = 0;

  _InkSourcePage pageFromCurrent() => _InkSourcePage(
    content: '<html>$head<body>${current.join()}</body></html>',
    start: currentStart,
    end: currentEnd,
  );

  for (final element in elements) {
    final html = element.outerHtml;
    final found = source.indexOf(html, searchOffset);
    final start = found < 0 ? searchOffset : found;
    final end = math.min(source.length, start + html.length);
    searchOffset = end;
    final tag = element.localName ?? '';
    final text = element.text.trim();
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    var estimated = painter.height + 24;
    if (tag == 'img' || element.querySelector('img') != null) {
      estimated += width * 0.58;
    }
    if (tag == 'pre') estimated += 48;
    final isHeading = RegExp(r'^h[1-6]$').hasMatch(tag);
    if (current.isNotEmpty &&
        (used + estimated > height ||
            (isHeading && used + estimated + 80 > height))) {
      yield pageFromCurrent();
      current.clear();
      used = 0;
    }
    if (current.isEmpty) currentStart = start;
    current.add(html);
    currentEnd = end;
    used += estimated;
  }
  if (current.isNotEmpty) yield pageFromCurrent();
}

class _MarkdownShareCanvas extends StatelessWidget {
  const _MarkdownShareCanvas({required this.data, required this.images});

  final String data;
  final Map<String, ui.Image> images;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 34, 32, 38),
    child: MarkdownBody(
      data: data,
      selectable: false,
      builders: {'pre': buildMoyueCodeBlockBuilder(context)},
      styleSheet: buildMoyueMarkdownStyleSheet(context),
      imageBuilder: (uri, title, alt) {
        final image = images[uri.toString()];
        if (image == null) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.broken_image_outlined),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: RawImage(image: image, fit: BoxFit.contain),
        );
      },
    ),
  );
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
  ) => KeyedSubtree(
    key: allocator.take(),
    child: Text(element.textContent, style: preferredStyle),
  );
}

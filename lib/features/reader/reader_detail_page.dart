import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
  bool _readerMenuVisible = false;
  String? _readerMessage;
  Timer? _readerMessageTimer;
  ReaderOverlayTone? _overlayTone;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    MoyueStorageService.instance.addListener(_reloadDocument);
  }

  @override
  void dispose() {
    MoyueStorageService.instance.removeListener(_reloadDocument);
    _readerMessageTimer?.cancel();
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
    final inkMode = display?.isInkMode ?? false;
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
    // 墨模式与纸张模式共用同一套滚动排版：滚动是电子纸上最自然、
    // 性能最好的阅读方式，不做分页与逐行刷新模拟。
    final readerContent = MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(_textScale)),
      child: _document.kind == DocumentKind.markdown
          ? _MarkdownDocument(
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
    // 墨模式下前景色固定由纸墨灰阶决定，跳过逐帧采样以省电。
    return RepaintBoundary(
      child: Scaffold(
        backgroundColor: readerSurface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: useWebView || inkMode
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
        DisplayPreferencesScope.maybeOf(context)?.effectiveReduceMotion ??
        false;
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

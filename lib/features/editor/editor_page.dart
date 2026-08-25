import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/core/display/moyue_markdown_style.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';
import 'package:moyue_application/widgets/moyue_glass_title_pill.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';
import 'package:moyue_application/widgets/moyue_transient_message.dart';
import 'package:moyue_application/widgets/image_lightbox.dart';
import 'package:moyue_application/widgets/stable_reader_image.dart';

Route<ReadingDocument?> markdownEditorRoute(
  BuildContext context,
  Object? arguments,
) {
  final value = arguments as Map<Object?, Object?>?;
  final document = value == null
      ? null
      : ReadingDocument(
          id: value['id']! as String,
          title: value['title']! as String,
          content: value['content']! as String,
          kind: DocumentKind.markdown,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            value['updatedAt']! as int,
          ),
          filePath: value['filePath'] as String?,
          folderId: value['folderId'] as String?,
          relativePath: value['relativePath'] as String?,
          logicalPath: value['logicalPath'] as String?,
        );
  return moyuePageRoute<ReadingDocument?>(
    context: context,
    builder: (_) => MarkdownEditorPage(document: document),
  );
}

Map<String, Object?>? markdownEditorArguments(ReadingDocument? document) =>
    document == null
    ? null
    : {
        'id': document.id,
        'title': document.title,
        'content': document.content,
        'updatedAt': document.updatedAt.millisecondsSinceEpoch,
        'filePath': document.filePath,
        'folderId': document.folderId,
        'relativePath': document.relativePath,
        'logicalPath': document.logicalPath,
      };

class MarkdownEditorPage extends StatefulWidget {
  const MarkdownEditorPage({this.document, super.key});
  final ReadingDocument? document;

  @override
  State<MarkdownEditorPage> createState() => _MarkdownEditorPageState();
}

class _MarkdownEditorPageState extends State<MarkdownEditorPage>
    with RestorationMixin, WidgetsBindingObserver {
  late final RestorableTextEditingController _title;
  late final RestorableTextEditingController _body;
  final RestorableInt _mode = RestorableInt(0);
  final RestorableBool _dirty = RestorableBool(false);
  bool _saving = false;
  bool _listenersAttached = false;
  Timer? _autosaveTimer;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();
  final ScrollController _bodyScrollController = ScrollController();
  final ValueNotifier<double> _settledKeyboardInset = ValueNotifier(0);
  ReadingDocument? _currentDocument;
  bool _importingImage = false;
  String? _editorMessage;
  Timer? _editorMessageTimer;
  final ReaderImageSessionCache _previewImageCache = ReaderImageSessionCache();

  @override
  String? get restorationId =>
      'markdown_editor_${widget.document?.id.hashCode ?? 'new'}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentDocument = widget.document;
    _title = RestorableTextEditingController(
      text: widget.document?.title ?? '',
    );
    _body = RestorableTextEditingController(
      text: widget.document?.content ?? '',
    );
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_title, 'title');
    registerForRestoration(_body, 'body');
    registerForRestoration(_mode, 'mode');
    registerForRestoration(_dirty, 'dirty');
    if (!_listenersAttached) {
      _title.value.addListener(_changed);
      _body.value.addListener(_changed);
      _listenersAttached = true;
    }
  }

  void _changed() {
    if (!_dirty.value && mounted) setState(() => _dirty.value = true);
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(_persist(popAfter: false)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_persist(popAfter: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _editorMessageTimer?.cancel();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _bodyScrollController.dispose();
    _settledKeyboardInset.dispose();
    _previewImageCache.clear();
    _title.value.removeListener(_changed);
    _body.value.removeListener(_changed);
    _title.dispose();
    _body.dispose();
    _mode.dispose();
    _dirty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return PopScope<ReadingDocument?>(
      // 拦截系统返回：与「保存」一致，先落盘、再清理、最后退出，
      // 保证磁盘正文始终包含已插入的图片链接，避免清理误删。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_exitWithSave());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MoyueBackdrop()),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 66),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
                      child: Row(
                        children: [
                          Icon(
                            _dirty.value
                                ? Icons.cloud_upload_outlined
                                : Icons.cloud_done_outlined,
                            size: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _saving
                                ? l10n.saving
                                : _dirty.value
                                ? l10n.draftQueued
                                : l10n.autoSaved,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.characterCount(
                              _body.value.text.characters.length,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: moyueMotionDuration(
                          context,
                          const Duration(milliseconds: 220),
                        ),
                        child: _mode.value == 0
                            ? _EditorCanvas(
                                title: _title.value,
                                body: _body.value,
                                titleFocus: _titleFocus,
                                bodyFocus: _bodyFocus,
                                bodyScrollController: _bodyScrollController,
                                keyboardInset: _settledKeyboardInset,
                              )
                            : _PreviewCanvas(
                                body: _body.value.text,
                                document: _currentDocument,
                                imageCache: _previewImageCache,
                              ),
                      ),
                    ),
                  ],
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
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MoyueGlassIconButton(
                            icon: const Icon(
                              CupertinoIcons.chevron_back,
                              size: 21,
                            ),
                            onPressed: _exitWithSave,
                            semanticLabel: l10n.back,
                            size: 44,
                            useOwnLayer: true,
                            settings: moyueGlassSettings(context),
                          ),
                        ),
                        MoyueGlassTitlePill(
                          width: 150,
                          title: _title.value.text.trim().isEmpty
                              ? l10n.newMarkdown
                              : _title.value.text.trim(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MoyueGlassIconButton(
                                icon: Icon(
                                  _mode.value == 0
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.pencil,
                                  size: 20,
                                ),
                                onPressed: () => setState(() {
                                  _mode.value = _mode.value == 0 ? 1 : 0;
                                }),
                                semanticLabel: _mode.value == 0
                                    ? l10n.preview
                                    : l10n.continueEditing,
                                size: 44,
                                useOwnLayer: true,
                                settings: moyueGlassSettings(context),
                              ),
                              const SizedBox(width: 4),
                              MoyueGlassIconButton(
                                icon: _saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        CupertinoIcons.check_mark_circled,
                                        size: 21,
                                      ),
                                onPressed: _saving ? null : _save,
                                semanticLabel: l10n.save,
                                size: 44,
                                useOwnLayer: true,
                                settings: moyueGlassSettings(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _SettledKeyboardDock(
              enabled: _mode.value == 0,
              bodyFocus: _bodyFocus,
              keyboardInset: _settledKeyboardInset,
              child: _FormatBar(
                onFormat: _applyFormat,
                onInsertImage: _insertImage,
                importingImage: _importingImage,
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: _settledKeyboardInset,
              builder: (context, keyboardInset, _) => Positioned.fill(
                child: MoyueTransientMessageOverlay(
                  message: _editorMessage,
                  bottomInset: keyboardInset > 0
                      ? keyboardInset + 76
                      : MediaQuery.paddingOf(context).bottom + 20,
                  onDismiss: _dismissMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 统一退出流程（头部返回按钮与系统返回手势共用）：
  /// 先落盘保存，再基于最新正文清理未引用图片，最后退出页面。
  Future<void> _exitWithSave() async {
    await _persist(popAfter: false);
    final pending = mounted ? _body.value.text : null;
    unawaited(_cleanupImages(pendingContent: pending));
    if (mounted) Navigator.pop(context, _currentDocument);
  }

  Future<void> _save() => _persist(popAfter: true);

  /// 结束编辑（保存或退出）后清理 images/ 目录下未被引用的图片，
  /// 例如插入后又被删掉链接的图片。失败静默，不影响主流程。
  ///
  /// [pendingContent] 必须传入当前正文快照：若退出时未保存，磁盘正文
  /// 还不含刚插入的链接，缺少它会导致清理误删新图片。
  Future<void> _cleanupImages({String? pendingContent}) async {
    final document = _currentDocument;
    if (document == null || document.relativePath == null) return;
    try {
      await MoyueStorageService.instance.cleanupUnreferencedImages(
        document,
        pendingContent: pendingContent,
      );
    } on Object {
      // 忽略清理失败。
    }
  }

  Future<void> _insertImage() async {
    if (_importingImage) return;
    final insertionSelection = _normalizedBodySelection();
    setState(() => _importingImage = true);
    try {
      var document = _currentDocument;
      if (document == null ||
          document.relativePath == null ||
          document.folderId == null) {
        // 旧版根目录文档（无 folderId）也要进入新索引存储。
        // 即使正文没有改动，插图操作也会强制完成这次迁移。
        await _persist(popAfter: false, force: true);
        if (!mounted) return;
        document = _currentDocument;
      }
      if (document == null ||
          document.relativePath == null ||
          document.folderId == null) {
        _message(
          _title.value.text.trim().isEmpty
              ? context.l10n.insertImageNeedsTitle
              : context.l10n.imageImportFailed,
        );
        return;
      }
      final file = await FilePicker.pickFile(type: FileType.image);
      if (!mounted) return;
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 8 * 1024 * 1024) {
        _message(context.l10n.imageImportFailed);
        return;
      }
      final link = await MoyueStorageService.instance.saveDocumentImage(
        document: document,
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      if (link == null) {
        _message(context.l10n.imageImportFailed);
        return;
      }
      final controller = _body.value;
      final text = controller.text;
      final selection = _clampSelection(insertionSelection, text.length);
      final selectedText = selection.isCollapsed
          ? ''
          : text.substring(selection.start, selection.end).trim();
      final alt = _escapeImageAlt(
        selectedText.isEmpty ? file.name : selectedText,
      );
      final leadingNewline =
          selection.start > 0 && text[selection.start - 1] != '\n' ? '\n' : '';
      final trailingNewline =
          selection.end < text.length && text[selection.end] != '\n'
          ? '\n'
          : '';
      final snippet = '$leadingNewline![$alt]($link)$trailingNewline';
      controller.value = TextEditingValue(
        text: text.replaceRange(selection.start, selection.end, snippet),
        selection: TextSelection.collapsed(
          offset: selection.start + snippet.length,
        ),
      );
      _bodyFocus.requestFocus();
      _message(context.l10n.imageImportSucceeded);
    } on Object {
      if (mounted) _message(context.l10n.imageImportFailed);
    } finally {
      if (mounted) {
        _bodyFocus.requestFocus();
        setState(() => _importingImage = false);
      }
    }
  }

  TextSelection _normalizedBodySelection() =>
      _clampSelection(_body.value.selection, _body.value.text.length);

  TextSelection _clampSelection(TextSelection selection, int textLength) {
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: textLength);
    }
    return TextSelection(
      baseOffset: selection.baseOffset.clamp(0, textLength),
      extentOffset: selection.extentOffset.clamp(0, textLength),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  String _escapeImageAlt(String value) =>
      value.replaceAll('\\', r'\\').replaceAll(']', r'\]');

  void _message(String message) {
    _editorMessageTimer?.cancel();
    setState(() => _editorMessage = message);
    _editorMessageTimer = Timer(const Duration(seconds: 3), _dismissMessage);
  }

  void _dismissMessage() {
    _editorMessageTimer?.cancel();
    _editorMessageTimer = null;
    if (!mounted || _editorMessage == null) return;
    setState(() => _editorMessage = null);
  }

  Future<void> _persist({required bool popAfter, bool force = false}) async {
    _autosaveTimer?.cancel();
    if (_saving) return;
    if (!_dirty.value && !force) {
      if (popAfter && mounted) Navigator.pop(context, _currentDocument);
      return;
    }
    final title = _title.value.text.trim();
    if (title.isEmpty) {
      if (popAfter && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.enterDraftTitle)));
      }
      return;
    }
    if (mounted) setState(() => _saving = true);
    try {
      final document = await MoyueStorageService.instance.saveDocument(
        title: title,
        content: _body.value.text,
        kind: DocumentKind.markdown,
        existingDocument: _currentDocument,
      );
      _currentDocument = document;
      _dirty.value = false;
      unawaited(_cleanupImages(pendingContent: _body.value.text));
      if (popAfter && mounted) Navigator.pop(context, document);
    } on Object catch (error) {
      if (popAfter && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.saveFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyFormat(_MarkdownFormat format) {
    _bodyFocus.requestFocus();
    switch (format) {
      case _MarkdownFormat.heading:
        _toggleLineMarker('## ');
      case _MarkdownFormat.bold:
        _toggleWrappedSelection('**', '**', context.l10n.boldPlaceholder);
      case _MarkdownFormat.italic:
        _toggleWrappedSelection('_', '_', context.l10n.italicPlaceholder);
      case _MarkdownFormat.quote:
        _toggleLineMarker('> ');
      case _MarkdownFormat.list:
        _toggleLineMarker('- ');
      case _MarkdownFormat.link:
        _toggleWrappedSelection(
          '[',
          '](https://)',
          context.l10n.linkPlaceholder,
        );
      case _MarkdownFormat.code:
        _toggleWrappedSelection('`', '`', context.l10n.codePlaceholder);
    }
  }

  void _toggleWrappedSelection(
    String before,
    String after,
    String placeholder,
  ) {
    final controller = _body.value;
    final text = controller.text;
    final selection = _clampSelection(controller.selection, text.length);
    final start = selection.start;
    final end = selection.end;

    final wrappedStart = start - before.length;
    final wrappedEnd = end + after.length;
    if (wrappedStart >= 0 &&
        wrappedEnd <= text.length &&
        text.substring(wrappedStart, start) == before &&
        text.substring(end, wrappedEnd) == after) {
      final selected = text.substring(start, end);
      controller.value = TextEditingValue(
        text: text.replaceRange(wrappedStart, wrappedEnd, selected),
        selection: TextSelection(
          baseOffset: wrappedStart,
          extentOffset: wrappedStart + selected.length,
        ),
      );
      return;
    }

    final selected = start == end ? placeholder : text.substring(start, end);
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, '$before$selected$after'),
      selection: TextSelection(
        baseOffset: start + before.length,
        extentOffset: start + before.length + selected.length,
      ),
    );
  }

  void _toggleLineMarker(String marker) {
    final controller = _body.value;
    final text = controller.text;
    final selection = _clampSelection(controller.selection, text.length);
    final caret = selection.start;
    final lineStart = caret == 0 ? -1 : text.lastIndexOf('\n', caret - 1);
    final offset = lineStart < 0 ? 0 : lineStart + 1;
    if (text.startsWith(marker, offset)) {
      int adjustedOffset(int value) {
        if (value <= offset) return value;
        return math.max(offset, value - marker.length);
      }

      controller.value = TextEditingValue(
        text: text.replaceRange(offset, offset + marker.length, ''),
        selection: TextSelection(
          baseOffset: adjustedOffset(selection.baseOffset),
          extentOffset: adjustedOffset(selection.extentOffset),
          affinity: selection.affinity,
          isDirectional: selection.isDirectional,
        ),
      );
      return;
    }
    controller.value = TextEditingValue(
      text: text.replaceRange(offset, offset, marker),
      selection: TextSelection(
        baseOffset: selection.baseOffset + marker.length,
        extentOffset: selection.extentOffset + marker.length,
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
    );
  }
}

class _EditorCanvas extends StatelessWidget {
  const _EditorCanvas({
    required this.title,
    required this.body,
    required this.titleFocus,
    required this.bodyFocus,
    required this.bodyScrollController,
    required this.keyboardInset,
  });
  final TextEditingController title;
  final TextEditingController body;
  final FocusNode titleFocus;
  final FocusNode bodyFocus;
  final ScrollController bodyScrollController;
  final ValueNotifier<double> keyboardInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      key: const ValueKey('edit'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        key: const ValueKey('editor-writing-surface'),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            TextField(
              controller: title,
              focusNode: titleFocus,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: l10n.draftTitle,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(20, 20, 20, 13),
              ),
            ),
            Divider(color: theme.colorScheme.outlineVariant),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: keyboardInset,
                builder: (context, inset, _) => TextField(
                  controller: body,
                  focusNode: bodyFocus,
                  scrollController: bodyScrollController,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  scrollPadding: EdgeInsets.only(
                    bottom: inset > 0 ? inset + 86 : 24,
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                  decoration: InputDecoration(
                    hintText: l10n.startWriting,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      // The canvas remains full-height and the glass toolbar
                      // floats over it. Reserve only the keyboard height here
                      // so text can continue beneath the translucent toolbar;
                      // scrollPadding above still keeps the caret reachable.
                      inset > 0 ? inset + 20 : 24,
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

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.body,
    required this.document,
    required this.imageCache,
  });
  final String body;
  final ReadingDocument? document;
  final ReaderImageSessionCache imageCache;

  @override
  Widget build(BuildContext context) {
    final palette = moyueMarkdownPaletteOf(context);
    return ColoredBox(
      color: palette.surface,
      child: Markdown(
        key: const ValueKey('preview'),
        data: body,
        selectable: true,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        builders: {'pre': buildMoyueCodeBlockBuilder(context)},
        imageBuilder: (uri, title, alt) {
          final current = document;
          if (current == null) return const SizedBox.shrink();
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: StableReaderImage(
              cacheKey: 'editor:${current.id}:${uri.toString()}',
              sessionCache: imageCache,
              loader: () => MoyueStorageService.instance.readLinkedResource(
                current,
                uri.toString(),
              ),
              semanticLabel: alt,
              onTap: (bytes) => unawaited(ImageLightbox.show(context, bytes)),
            ),
          );
        },
        styleSheet: buildMoyueMarkdownStyleSheet(context),
      ),
    );
  }
}

enum _MarkdownFormat { heading, bold, italic, quote, list, link, code }

class _SettledKeyboardDock extends StatefulWidget {
  const _SettledKeyboardDock({
    required this.enabled,
    required this.bodyFocus,
    required this.keyboardInset,
    required this.child,
  });

  final bool enabled;
  final FocusNode bodyFocus;
  final ValueNotifier<double> keyboardInset;
  final Widget child;

  @override
  State<_SettledKeyboardDock> createState() => _SettledKeyboardDockState();
}

class _SettledKeyboardDockState extends State<_SettledKeyboardDock>
    with WidgetsBindingObserver {
  Timer? _sampleTimer;
  bool _settled = false;
  double _keyboardInset = 0;
  double? _lastSample;
  int _stableSamples = 0;

  bool get _visible => widget.enabled && widget.bodyFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.bodyFocus.addListener(_focusChanged);
  }

  @override
  void didChangeMetrics() {
    // 焦点不变时键盘也可能收起（如系统返回键关闭输入法），
    // 监听窗口度量变化，重新采样以及时隐藏工具栏。
    if (mounted && _visible) _beginSampling();
  }

  @override
  void didUpdateWidget(covariant _SettledKeyboardDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bodyFocus != widget.bodyFocus) {
      oldWidget.bodyFocus.removeListener(_focusChanged);
      widget.bodyFocus.addListener(_focusChanged);
    }
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.bodyFocus != widget.bodyFocus) {
      _beginSampling();
    }
  }

  void _focusChanged() => _beginSampling();

  void _beginSampling() {
    _sampleTimer?.cancel();
    _lastSample = null;
    _stableSamples = 0;
    final needsRebuild = _settled || _keyboardInset != 0;
    _settled = false;
    _keyboardInset = 0;
    widget.keyboardInset.value = 0;
    if (needsRebuild && mounted) setState(() {});
    if (!_visible) return;
    _sampleTimer = Timer(const Duration(milliseconds: 80), _sampleInset);
  }

  void _sampleInset() {
    if (!mounted || !_visible) return;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final previous = _lastSample;
    if (inset <= 0 && previous != null && (inset - previous).abs() < 0.5) {
      // 键盘确认已收起：停在隐藏状态，等待焦点或窗口变化再次触发采样，
      // 避免无限轮询。
      return;
    }
    if (inset > 0 && previous != null && (inset - previous).abs() < 0.5) {
      _stableSamples++;
    } else {
      _stableSamples = inset > 0 ? 1 : 0;
    }
    _lastSample = inset;
    if (_stableSamples >= 3) {
      setState(() {
        _keyboardInset = inset;
        _settled = true;
      });
      widget.keyboardInset.value = inset;
      return;
    }
    _sampleTimer = Timer(const Duration(milliseconds: 45), _sampleInset);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sampleTimer?.cancel();
    widget.bodyFocus.removeListener(_focusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_settled || !_visible || _keyboardInset <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 12,
      right: 12,
      bottom: _keyboardInset + 10,
      child: KeyedSubtree(
        key: const ValueKey('keyboard-format-dock'),
        child: widget.child,
      ),
    );
  }
}

class _FormatBar extends StatelessWidget {
  const _FormatBar({
    required this.onFormat,
    required this.onInsertImage,
    required this.importingImage,
  });
  final ValueChanged<_MarkdownFormat> onFormat;
  final VoidCallback onInsertImage;
  final bool importingImage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: GlassButtonGroup.icons(
            useOwnLayer: true,
            quality: GlassQuality.premium,
            platformViewBackdrop: false,
            settings: moyueGlassSettings(context),
            items: [
              _item(Icons.title_rounded, l10n.heading, _MarkdownFormat.heading),
              _item(Icons.format_bold_rounded, l10n.bold, _MarkdownFormat.bold),
              _item(
                Icons.format_italic_rounded,
                l10n.italic,
                _MarkdownFormat.italic,
              ),
              _item(
                Icons.format_quote_rounded,
                l10n.quote,
                _MarkdownFormat.quote,
              ),
              _item(
                Icons.format_list_bulleted_rounded,
                l10n.list,
                _MarkdownFormat.list,
              ),
              _item(Icons.link_rounded, l10n.link, _MarkdownFormat.link),
              _item(Icons.code_rounded, l10n.code, _MarkdownFormat.code),
              GlassButtonGroupItem(
                icon: importingImage
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: l10n.image,
                onTap: onInsertImage,
                enabled: !importingImage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  GlassButtonGroupItem _item(
    IconData icon,
    String label,
    _MarkdownFormat format,
  ) => GlassButtonGroupItem(
    icon: Icon(icon),
    label: label,
    onTap: () => onFormat(format),
  );
}

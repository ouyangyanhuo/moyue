import 'dart:async';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';
import 'package:moyue_application/widgets/moyue_glass_title_pill.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';

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
        );
  return MaterialPageRoute(
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
  ReadingDocument? _currentDocument;
  bool _importingImage = false;

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
    _titleFocus.dispose();
    _bodyFocus.dispose();
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
                                ? '正在保存…'
                                : _dirty.value
                                ? '草稿已进入恢复队列'
                                : '已自动保存',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_body.value.text.characters.length} 字',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _mode.value == 0
                            ? _EditorCanvas(
                                title: _title.value,
                                body: _body.value,
                                titleFocus: _titleFocus,
                                bodyFocus: _bodyFocus,
                              )
                            : _PreviewCanvas(body: _body.value.text),
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
                            semanticLabel: '返回',
                            size: 44,
                            useOwnLayer: true,
                            settings: moyueGlassSettings(context),
                          ),
                        ),
                        MoyueGlassTitlePill(
                          width: 150,
                          title: _title.value.text.trim().isEmpty
                              ? '新建 Markdown'
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
                                semanticLabel: _mode.value == 0 ? '预览' : '继续编辑',
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
                                semanticLabel: '保存',
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
              titleFocus: _titleFocus,
              bodyFocus: _bodyFocus,
              child: _FormatBar(
                onFormat: _applyFormat,
                onInsertImage: _insertImage,
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
    var document = _currentDocument;
    if (document == null ||
        document.relativePath == null ||
        document.folderId == null) {
      // 旧版根目录文档（无 folderId）不支持资源写入：
      // 先强制落盘迁移到索引存储，再基于迁移后的文档插入。
      await _persist(popAfter: false);
      document = _currentDocument;
      if (document == null ||
          document.relativePath == null ||
          document.folderId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('请先填写标题，保存后再插入图片')));
        }
        return;
      }
    }
    setState(() => _importingImage = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (!mounted) return;
      final file = result == null || result.files.isEmpty
          ? null
          : result.files.single;
      var bytes = file?.bytes;
      // 部分平台的 file_picker 不会自动填充 bytes，需要从缓存路径补读。
      if (bytes == null && !kIsWeb && file?.path != null) {
        try {
          bytes = await File(file!.path!).readAsBytes();
        } on Object {
          bytes = null;
        }
      }
      if (!mounted) return;
      if (file == null || bytes == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法读取所选图片')));
        return;
      }
      if (bytes.length > 8 * 1024 * 1024) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图片不能超过 8 MB')));
        return;
      }
      final link = await MoyueStorageService.instance.saveDocumentImage(
        document: document,
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      if (link == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仅支持 png/jpg/jpeg/gif/webp/bmp 图片')),
        );
        return;
      }
      final controller = _body.value;
      final text = controller.text;
      final caret = controller.selection.isValid
          ? controller.selection.end
          : text.length;
      final snippet = '![${file.name}]($link)\n';
      controller.value = TextEditingValue(
        text: text.replaceRange(caret, caret, snippet),
        selection: TextSelection.collapsed(offset: caret + snippet.length),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('图片已保存到 $link')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('插入图片失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _importingImage = false);
    }
  }

  Future<void> _persist({required bool popAfter}) async {
    _autosaveTimer?.cancel();
    if (_saving) return;
    if (!_dirty.value) {
      if (popAfter && mounted) Navigator.pop(context, _currentDocument);
      return;
    }
    final title = _title.value.text.trim();
    if (title.isEmpty) {
      if (popAfter && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请先填写文稿标题')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyFormat(_MarkdownFormat format) {
    switch (format) {
      case _MarkdownFormat.heading:
        _insertAtLineStart('## ');
      case _MarkdownFormat.bold:
        _wrapSelection('**', '**', '重点文字');
      case _MarkdownFormat.italic:
        _wrapSelection('_', '_', '强调文字');
      case _MarkdownFormat.quote:
        _insertAtLineStart('> ');
      case _MarkdownFormat.list:
        _insertAtLineStart('- ');
      case _MarkdownFormat.link:
        _wrapSelection('[', '](https://)', '链接文字');
      case _MarkdownFormat.code:
        _wrapSelection('`', '`', '代码');
    }
  }

  void _wrapSelection(String before, String after, String placeholder) {
    final controller = _body.value;
    final selection = controller.selection;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = start == end ? placeholder : text.substring(start, end);
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, '$before$selected$after'),
      selection: TextSelection(
        baseOffset: start + before.length,
        extentOffset: start + before.length + selected.length,
      ),
    );
  }

  void _insertAtLineStart(String marker) {
    final controller = _body.value;
    final text = controller.text;
    final caret = controller.selection.isValid
        ? controller.selection.start
        : text.length;
    final lineStart = caret == 0 ? -1 : text.lastIndexOf('\n', caret - 1);
    final offset = lineStart < 0 ? 0 : lineStart + 1;
    controller.value = TextEditingValue(
      text: text.replaceRange(offset, offset, marker),
      selection: TextSelection.collapsed(offset: caret + marker.length),
    );
  }
}

class _EditorCanvas extends StatelessWidget {
  const _EditorCanvas({
    required this.title,
    required this.body,
    required this.titleFocus,
    required this.bodyFocus,
  });
  final TextEditingController title;
  final TextEditingController body;
  final FocusNode titleFocus;
  final FocusNode bodyFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              decoration: const InputDecoration(
                hintText: '文稿标题',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(20, 20, 20, 13),
              ),
            ),
            Divider(color: theme.colorScheme.outlineVariant),
            Expanded(
              child: TextField(
                controller: body,
                focusNode: bodyFocus,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                decoration: const InputDecoration(
                  hintText: '从这里开始写作…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(20, 16, 20, 24),
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
  const _PreviewCanvas({required this.body});
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Markdown(
      key: const ValueKey('preview'),
      data: body,
      selectable: true,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyLarge,
        h1: theme.textTheme.headlineLarge,
        h2: theme.textTheme.headlineMedium,
        h3: theme.textTheme.titleLarge,
        code: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}

enum _MarkdownFormat { heading, bold, italic, quote, list, link, code }

class _SettledKeyboardDock extends StatefulWidget {
  const _SettledKeyboardDock({
    required this.enabled,
    required this.titleFocus,
    required this.bodyFocus,
    required this.child,
  });

  final bool enabled;
  final FocusNode titleFocus;
  final FocusNode bodyFocus;
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

  bool get _visible =>
      widget.enabled &&
      (widget.titleFocus.hasFocus || widget.bodyFocus.hasFocus);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.titleFocus.addListener(_focusChanged);
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
    if (oldWidget.titleFocus != widget.titleFocus) {
      oldWidget.titleFocus.removeListener(_focusChanged);
      widget.titleFocus.addListener(_focusChanged);
    }
    if (oldWidget.bodyFocus != widget.bodyFocus) {
      oldWidget.bodyFocus.removeListener(_focusChanged);
      widget.bodyFocus.addListener(_focusChanged);
    }
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.titleFocus != widget.titleFocus ||
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
      return;
    }
    _sampleTimer = Timer(const Duration(milliseconds: 45), _sampleInset);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sampleTimer?.cancel();
    widget.titleFocus.removeListener(_focusChanged);
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
  const _FormatBar({required this.onFormat, required this.onInsertImage});
  final ValueChanged<_MarkdownFormat> onFormat;
  final VoidCallback onInsertImage;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: GlassButtonGroup.icons(
          useOwnLayer: true,
          settings: moyueGlassSettings(context),
          items: [
            _item(Icons.title_rounded, '标题', _MarkdownFormat.heading),
            _item(Icons.format_bold_rounded, '粗体', _MarkdownFormat.bold),
            _item(Icons.format_italic_rounded, '斜体', _MarkdownFormat.italic),
            _item(Icons.format_quote_rounded, '引用', _MarkdownFormat.quote),
            _item(
              Icons.format_list_bulleted_rounded,
              '列表',
              _MarkdownFormat.list,
            ),
            _item(Icons.link_rounded, '链接', _MarkdownFormat.link),
            _item(Icons.code_rounded, '代码', _MarkdownFormat.code),
            GlassButtonGroupItem(
              icon: const Icon(Icons.image_outlined),
              label: '图片',
              onTap: onInsertImage,
            ),
          ],
        ),
      ),
    ),
  );

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

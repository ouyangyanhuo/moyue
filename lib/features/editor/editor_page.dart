import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';
import 'package:moyue_application/widgets/scrolling_title.dart';

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

  @override
  String? get restorationId =>
      'markdown_editor_${widget.document?.id.hashCode ?? 'new'}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleFocus.addListener(_focusChanged);
    _bodyFocus.addListener(_focusChanged);
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

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _titleFocus
      ..removeListener(_focusChanged)
      ..dispose();
    _bodyFocus
      ..removeListener(_focusChanged)
      ..dispose();
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
      canPop: true,
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
                          child: GlassIconButton(
                            icon: const Icon(
                              CupertinoIcons.chevron_back,
                              size: 21,
                            ),
                            onPressed: _closeEditor,
                            semanticLabel: '返回',
                            size: 44,
                            useOwnLayer: true,
                          ),
                        ),
                        GlassContainer(
                          width: 150,
                          height: 42,
                          useOwnLayer: true,
                          shape: const LiquidRoundedSuperellipse(
                            borderRadius: 12,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          child: ScrollingTitle(
                            _title.value.text.trim().isEmpty
                                ? '新建 Markdown'
                                : _title.value.text.trim(),
                            autoScroll: true,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassIconButton(
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
                              ),
                              const SizedBox(width: 4),
                              GlassIconButton(
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
              visible:
                  _mode.value == 0 &&
                  (_titleFocus.hasFocus || _bodyFocus.hasFocus),
              keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
              child: _FormatBar(onFormat: _applyFormat),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _closeEditor() async {
    await _persist(popAfter: false);
    if (mounted) await Navigator.maybePop(context, _currentDocument);
  }

  Future<void> _save() => _persist(popAfter: true);

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
    required this.visible,
    required this.keyboardInset,
    required this.child,
  });

  final bool visible;
  final double keyboardInset;
  final Widget child;

  @override
  State<_SettledKeyboardDock> createState() => _SettledKeyboardDockState();
}

class _SettledKeyboardDockState extends State<_SettledKeyboardDock> {
  Timer? _settleTimer;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _SettledKeyboardDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.keyboardInset != widget.keyboardInset) {
      _schedule();
    }
  }

  void _schedule() {
    _settleTimer?.cancel();
    if (_settled) setState(() => _settled = false);
    if (!widget.visible || widget.keyboardInset <= 0) return;
    _settleTimer = Timer(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_settled || !widget.visible || widget.keyboardInset <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 12,
      right: 12,
      bottom: widget.keyboardInset + 10,
      child: KeyedSubtree(
        key: const ValueKey('keyboard-format-dock'),
        child: widget.child,
      ),
    );
  }
}

class _FormatBar extends StatelessWidget {
  const _FormatBar({required this.onFormat});
  final ValueChanged<_MarkdownFormat> onFormat;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: GlassButtonGroup.icons(
          useOwnLayer: true,
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

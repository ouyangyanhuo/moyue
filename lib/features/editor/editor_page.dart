import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/data/sample_content.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/widgets/page_heading.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({required this.onSave, super.key});
  final ValueChanged<ReadingDocument> onSave;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  int _mode = 0;
  String _search = '';
  bool _dirty = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: '设计随笔');
    _bodyController = TextEditingController(text: sampleMarkdown);
    _bodyController.addListener(_changed);
    _titleController.addListener(_changed);
  }

  void _changed() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _bodyController.removeListener(_changed);
    _titleController.removeListener(_changed);
    _bodyController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final matches = _search.trim().isEmpty
        ? 0
        : RegExp(
            RegExp.escape(_search),
            caseSensitive: false,
          ).allMatches(_bodyController.text).length;

    return Column(
      children: [
        PageHeading(
          title: '编辑',
          subtitle: _dirty ? '草稿有未保存的更改' : '所有更改均已保存',
          searchHint: '在文稿中查找',
          onSearch: (value) => setState(() => _search = value),
          trailing: GlassIconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _save,
            semanticLabel: '保存文稿',
            size: 46,
            useOwnLayer: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: GlassTabBar.inline(
                  tabs: const [
                    GlassTab(label: '编辑', icon: Icon(Icons.edit_outlined)),
                    GlassTab(
                      label: '预览',
                      icon: Icon(Icons.visibility_outlined),
                    ),
                  ],
                  selectedIndex: _mode,
                  onTabSelected: (value) => setState(() => _mode = value),
                  indicatorColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                  selectedIconColor: theme.colorScheme.onSurface,
                  selectedLabelColor: theme.colorScheme.onSurface,
                  unselectedIconColor: theme.colorScheme.onSurfaceVariant,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              GlassButtonGroup.icons(
                useOwnLayer: true,
                items: [
                  GlassButtonGroupItem(
                    icon: const Icon(Icons.format_bold_rounded),
                    label: '粗体',
                    onTap: () => _wrapSelection('**', '**', '重点文字'),
                  ),
                  GlassButtonGroupItem(
                    icon: const Icon(Icons.title_rounded),
                    label: '标题',
                    onTap: () => _insertAtLineStart('## '),
                  ),
                  GlassButtonGroupItem(
                    icon: const Icon(Icons.link_rounded),
                    label: '链接',
                    onTap: () => _wrapSelection('[', '](https://)', '链接文字'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_search.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                matches == 0 ? '没有找到“$_search”' : '找到 $matches 处“$_search”',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: matches == 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _mode == 0
                ? _EditorSurface(
                    key: const ValueKey('editor'),
                    titleController: _titleController,
                    bodyController: _bodyController,
                  )
                : _PreviewSurface(
                    key: const ValueKey('preview'),
                    title: _titleController.text,
                    markdown: _bodyController.text,
                  ),
          ),
        ),
      ],
    );
  }

  void _save() {
    final title = _titleController.text.trim().isEmpty
        ? '未命名文稿'
        : _titleController.text.trim();
    widget.onSave(
      ReadingDocument(
        id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        content: _bodyController.text,
        kind: DocumentKind.markdown,
        updatedAt: DateTime.now(),
        sourceLabel: '墨阅编辑器',
      ),
    );
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已保存「$title」')));
  }

  void _wrapSelection(String before, String after, String placeholder) {
    final selection = _bodyController.selection;
    final text = _bodyController.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = start == end ? placeholder : text.substring(start, end);
    final replacement = '$before$selected$after';
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: start + before.length,
        extentOffset: start + before.length + selected.length,
      ),
    );
  }

  void _insertAtLineStart(String marker) {
    final text = _bodyController.text;
    final caret = _bodyController.selection.isValid
        ? _bodyController.selection.start
        : text.length;
    final lineStart = text.lastIndexOf('\n', (caret - 1).clamp(0, text.length));
    final offset = lineStart < 0 ? 0 : lineStart + 1;
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(offset, offset, marker),
      selection: TextSelection.collapsed(offset: caret + marker.length),
    );
  }
}

class _EditorSurface extends StatelessWidget {
  const _EditorSurface({
    required this.titleController,
    required this.bodyController,
    super.key,
  });
  final TextEditingController titleController;
  final TextEditingController bodyController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 112),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              style: theme.textTheme.headlineMedium,
              decoration: const InputDecoration(
                hintText: '文稿标题',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(20, 18, 20, 12),
              ),
            ),
            Divider(color: theme.colorScheme.outlineVariant),
            Expanded(
              child: TextField(
                controller: bodyController,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  height: 1.62,
                ),
                decoration: const InputDecoration(
                  hintText: '开始写作…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.title,
    required this.markdown,
    super.key,
  });
  final String title;
  final String markdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Markdown(
      data: markdown,
      selectable: true,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 116),
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyLarge,
        h1: theme.textTheme.headlineLarge,
        h2: theme.textTheme.headlineMedium,
        h3: theme.textTheme.titleLarge,
        blockquote: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        blockquotePadding: const EdgeInsets.all(16),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
        ),
        code: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
        codeblockPadding: const EdgeInsets.all(16),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

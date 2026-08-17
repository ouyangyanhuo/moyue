import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/page_heading.dart';
import 'package:moyue_application/widgets/section_label.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    required this.documents,
    required this.loading,
    super.key,
  });
  final List<ReadingDocument> documents;
  final bool loading;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';
  final Set<String> _selectedIds = {};

  bool get _selecting => _selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.documents
        .where((document) {
          return query.isEmpty ||
              document.title.toLowerCase().contains(query) ||
              document.kind.label.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return CustomScrollView(
      key: const PageStorageKey('library-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeading(
            title: _selecting ? '已选择 ${_selectedIds.length} 项' : '阅读',
            subtitle: _selecting ? '轻点条目可继续选择或取消' : '本地文档，安静阅读',
            searchHint: '搜索文档',
            onSearch: (value) => setState(() => _query = value),
            showSearch: !_selecting,
            trailing: GlassIconButton(
              icon: Icon(
                _selecting ? Icons.delete_rounded : Icons.add_rounded,
                color: _selecting ? Theme.of(context).colorScheme.error : null,
              ),
              onPressed: _selecting ? _deleteSelected : _showAddMenu,
              semanticLabel: _selecting ? '删除所选文档' : '新建或导入',
              size: 46,
              glowColor: Colors.transparent,
              useOwnLayer: true,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionLabel('文档')),
        if (widget.loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyLibrary(
              hasQuery: query.isNotEmpty,
              onCreate: _createMarkdown,
              onImport: _importDocument,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 118),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final document = filtered[index];
                final selected = _selectedIds.contains(document.id);
                return _DocumentTile(
                  document: document,
                  selected: selected,
                  onLongPress: () => _toggleSelection(document),
                  onTap: () {
                    if (_selecting) {
                      _toggleSelection(document);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReaderDetailPage(document: document),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  void _toggleSelection(ReadingDocument document) {
    setState(() {
      if (!_selectedIds.add(document.id)) _selectedIds.remove(document.id);
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 $count 个文档？'),
        content: const Text('所选文档将从本地数据目录中删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final selected = widget.documents
        .where((document) => _selectedIds.contains(document.id))
        .toList(growable: false);
    for (final document in selected) {
      await MoyueStorageService.instance.deleteDocument(document);
    }
    if (mounted) setState(_selectedIds.clear);
  }

  Future<void> _showAddMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('新建 Markdown'),
              onTap: () => Navigator.pop(context, 'create'),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('导入 Markdown 或 HTML'),
              onTap: () => Navigator.pop(context, 'import'),
            ),
          ],
        ),
      ),
    );
    if (action == 'create') await _createMarkdown();
    if (action == 'import') await _importDocument();
  }

  Future<void> _createMarkdown() async {
    Navigator.of(context).restorablePush<ReadingDocument?>(markdownEditorRoute);
  }

  Future<void> _importDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        // Android SAF may mark .md files as unselectable when a custom MIME
        // filter is used. Select first, then validate the extension locally.
        type: FileType.any,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('无法读取文件内容');
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('当前版本支持不超过 8 MB 的文本文档');
      }
      final extension = (file.extension ?? file.name.split('.').last)
          .toLowerCase();
      if (!const {'md', 'markdown', 'html', 'htm'}.contains(extension)) {
        throw const FormatException('请选择 .md、.markdown、.html 或 .htm 文件');
      }
      final kind = extension == 'html' || extension == 'htm'
          ? DocumentKind.html
          : DocumentKind.markdown;
      final title = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final document = await MoyueStorageService.instance.saveDocument(
        title: title,
        content: utf8.decode(bytes, allowMalformed: true),
        kind: kind,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderDetailPage(document: document),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    }
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });
  final ReadingDocument document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 58,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  document.kind == DocumentKind.markdown
                      ? Icons.notes_rounded
                      : Icons.code_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      document.kind.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('selected'),
                        color: theme.colorScheme.primary,
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        key: const ValueKey('normal'),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.hasQuery,
    required this.onCreate,
    required this.onImport,
  });
  final bool hasQuery;
  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.auto_stories_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? '没有匹配的文档' : '还没有文档',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            hasQuery ? '换一个关键词试试' : '新建 Markdown，或从设备导入文件',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建 Markdown'),
            ),
            TextButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('导入文件'),
            ),
          ],
        ],
      ),
    );
  }
}

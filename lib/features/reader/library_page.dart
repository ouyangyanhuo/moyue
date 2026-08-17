import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/widgets/page_heading.dart';
import 'package:moyue_application/widgets/section_label.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    required this.documents,
    required this.onDocumentAdded,
    super.key,
  });

  final List<ReadingDocument> documents;
  final ValueChanged<ReadingDocument> onDocumentAdded;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.documents
        .where((document) {
          final query = _query.trim().toLowerCase();
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
            title: '阅读',
            subtitle: '让文字回到安静、清晰的位置',
            searchHint: '搜索文档',
            onSearch: (value) => setState(() => _query = value),
            trailing: GlassIconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _importDocument,
              semanticLabel: '导入文件',
              size: 46,
              useOwnLayer: true,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionLabel('最近阅读')),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyLibrary(hasQuery: _query.isNotEmpty),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 118),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final document = filtered[index];
                return _DocumentTile(
                  document: document,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReaderDetailPage(document: document),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _importDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md', 'markdown', 'html', 'htm'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('无法读取文件内容');
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('当前版本支持不超过 8 MB 的文本文档');
      }
      final extension = (file.extension ?? '').toLowerCase();
      final kind = extension == 'html' || extension == 'htm'
          ? DocumentKind.html
          : DocumentKind.markdown;
      final title = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final document = ReadingDocument(
        id: 'import-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        content: utf8.decode(bytes, allowMalformed: true),
        kind: kind,
        updatedAt: DateTime.now(),
        sourceLabel: '刚刚导入',
      );
      widget.onDocumentAdded(document);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderDetailPage(document: document),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.onTap});
  final ReadingDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMarkdown = document.kind == DocumentKind.markdown;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  isMarkdown ? Icons.notes_rounded : Icons.code_rounded,
                  color: theme.colorScheme.primary,
                  size: 27,
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
                      '${document.kind.label} · ${document.sourceLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _preview(document.content),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _preview(String value) => value
      .replaceAll(RegExp(r'<[^>]+>|[#>*_`\[\]-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.menu_book_outlined,
            size: 46,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            hasQuery ? '没有匹配的文档' : '还没有导入文档',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery ? '试试更短的关键词' : '支持 .md、.markdown、.html 与 .htm',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

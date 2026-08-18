import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';
import 'package:moyue_application/widgets/page_heading.dart';
import 'package:moyue_application/widgets/scrolling_title.dart';
import 'package:moyue_application/widgets/section_label.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    required this.documents,
    required this.loading,
    this.folders = const [],
    super.key,
  });
  final List<ReadingDocument> documents;
  final List<LibraryFolder> folders;
  final bool loading;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';
  final Set<String> _selectedIds = {};
  final Set<String> _selectedFolderIds = {};

  bool get _selecting =>
      _selectedIds.isNotEmpty || _selectedFolderIds.isNotEmpty;
  int get _selectionCount => _selectedIds.length + _selectedFolderIds.length;

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
    final filteredFolders = widget.folders
        .where((folder) {
          return query.isEmpty || folder.name.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return CustomScrollView(
      key: const PageStorageKey('library-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeading(
            title: _selecting ? '已选择 $_selectionCount 项' : '阅读',
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
              useOwnLayer: true,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionLabel('文档')),
        if (widget.loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty && filteredFolders.isEmpty)
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
              itemCount: filteredFolders.length + filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index < filteredFolders.length) {
                  final folder = filteredFolders[index];
                  final selected = _selectedFolderIds.contains(folder.id);
                  return _FolderTile(
                    folder: folder,
                    selected: selected,
                    onLongPress: () => _toggleFolderSelection(folder),
                    onTap: () {
                      if (_selecting) {
                        _toggleFolderSelection(folder);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _FolderPage(folder: folder),
                          ),
                        );
                      }
                    },
                  );
                }
                final document = filtered[index - filteredFolders.length];
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

  void _toggleFolderSelection(LibraryFolder folder) {
    setState(() {
      if (!_selectedFolderIds.add(folder.id)) {
        _selectedFolderIds.remove(folder.id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectionCount;
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
    final selectedFolders = widget.folders
        .where((folder) => _selectedFolderIds.contains(folder.id))
        .toList(growable: false);
    for (final folder in selectedFolders) {
      await MoyueStorageService.instance.deleteFolder(folder);
    }
    if (mounted) {
      setState(() {
        _selectedIds.clear();
        _selectedFolderIds.clear();
      });
    }
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
              title: const Text('新建 markdown'),
              onTap: () => Navigator.pop(context, 'create'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建文件夹'),
              onTap: () => Navigator.pop(context, 'new-folder'),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('导入文件或文档包'),
              trailing: IconButton(
                icon: const Icon(Icons.error_outline_rounded),
                tooltip: '支持的文件格式',
                onPressed: () => _showImportHelp(context),
              ),
              onTap: () => Navigator.pop(context, 'import'),
            ),
          ],
        ),
      ),
    );
    if (action == 'create') await _createMarkdown();
    if (action == 'new-folder') await _createFolder();
    if (action == 'import') await _importDocument();
  }

  Future<void> _showImportHelp(BuildContext sheetContext) => showDialog<void>(
    context: sheetContext,
    builder: (context) => AlertDialog(
      title: const Text('支持的文件'),
      content: const Text(
        '支持 .md、.html、.zip 和 .moyue。\n\n'
        'ZIP 或 .moyue 至少需要 2 个文件，并包含 Markdown 或 HTML。包内只允许 HTML、Markdown、CSS、JS、常见图片和视频；文档数量大于 2 时会自动创建文件夹。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          const _FolderNameDialog(title: '新建文件夹', actionLabel: '创建'),
    );
    if (name == null || !mounted) return;
    try {
      await MoyueStorageService.instance.createFolder(name);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建文件夹失败：$error')));
      }
    }
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
      if (!const {'md', 'html', 'zip', 'moyue'}.contains(extension)) {
        throw const FormatException('请选择 Markdown、HTML、ZIP 或 .moyue 文件');
      }
      final document = await MoyueStorageService.instance.importDocumentPackage(
        fileName: file.name,
        bytes: bytes,
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

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final LibraryFolder folder;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Icon(
                Icons.folder_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScrollingTitle(
                      folder.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${folder.documents.length} 个文档',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderPage extends StatefulWidget {
  const _FolderPage({required this.folder});
  final LibraryFolder folder;

  @override
  State<_FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<_FolderPage> {
  late LibraryFolder _folder;
  final Set<String> _selectedIds = {};

  bool get _selecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _folder = widget.folder;
    MoyueStorageService.instance.addListener(_reloadFolder);
  }

  @override
  void dispose() {
    MoyueStorageService.instance.removeListener(_reloadFolder);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Stack(
      children: [
        const Positioned.fill(child: MoyueBackdrop()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 62),
            child: _folder.documents.isEmpty
                ? const Center(child: Text('这个文件夹还是空的'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                    itemCount: _folder.documents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final document = _folder.documents[index];
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
                                builder: (_) =>
                                    ReaderDetailPage(document: document),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: FloatingDocumentHeader(
              title: _selecting ? '已选择 ${_selectedIds.length} 项' : _folder.name,
              onBack: () => Navigator.pop(context),
              actionIcon: _selecting ? Icons.delete_rounded : Icons.add_rounded,
              actionLabel: _selecting ? '删除所选文档' : '新建或导入文档',
              actionColor: _selecting
                  ? Theme.of(context).colorScheme.error
                  : null,
              onAction: _selecting ? _deleteSelected : _showAddMenu,
              onTitleTap: _selecting ? null : _renameFolder,
            ),
          ),
        ),
      ],
    ),
  );

  void _toggleSelection(ReadingDocument document) {
    setState(() {
      if (!_selectedIds.add(document.id)) {
        _selectedIds.remove(document.id);
      }
    });
  }

  Future<void> _reloadFolder() async {
    final folders = await MoyueStorageService.instance.loadFolders();
    final matches = folders.where((folder) => folder.id == _folder.id);
    if (mounted && matches.isNotEmpty) {
      setState(() => _folder = matches.first);
    }
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${_selectedIds.length} 个文档？'),
        content: const Text('只会删除所选文档，文件夹中的其他内容会保留。'),
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
    final selected = _folder.documents
        .where((document) => _selectedIds.contains(document.id))
        .toList(growable: false);
    for (final document in selected) {
      await MoyueStorageService.instance.deleteDocument(document);
    }
    if (!mounted) return;
    final remaining = _folder.documents
        .where((document) => !_selectedIds.contains(document.id))
        .toList(growable: false);
    setState(() {
      _folder = _folder.copyWith(documents: remaining);
      _selectedIds.clear();
    });
    if (remaining.isEmpty && mounted) Navigator.pop(context);
  }

  Future<void> _renameFolder() async {
    if (_selecting) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        title: '修改文件夹名称',
        actionLabel: '保存',
        initialValue: _folder.name,
      ),
    );
    if (name == null || name == _folder.name || !mounted) return;
    try {
      await MoyueStorageService.instance.renameFolder(_folder, name);
      if (mounted) setState(() => _folder = _folder.copyWith(name: name));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('重命名失败：$error')));
      }
    }
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
    if (!mounted) return;
    if (action == 'create') await _createMarkdown();
    if (action == 'import') await _importDocument();
  }

  Future<void> _createMarkdown() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          const _FolderNameDialog(title: '新建 Markdown', actionLabel: '创建'),
    );
    if (name == null || !mounted) return;
    try {
      final document = await MoyueStorageService.instance
          .createMarkdownInFolder(folder: _folder, title: name);
      await _reloadFolder();
      if (!mounted) return;
      Navigator.of(context).restorablePush<ReadingDocument?>(
        markdownEditorRoute,
        arguments: markdownEditorArguments(document),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建 Markdown 失败：$error')));
      }
    }
  }

  Future<void> _importDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      final extension = (file.extension ?? file.name.split('.').last)
          .toLowerCase();
      if (!const {'md', 'html'}.contains(extension)) {
        throw const FormatException('文件夹内仅支持导入 .md 或 .html 文件');
      }
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('无法读取文件内容');
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('文件不能超过 8 MB');
      }
      final document = await MoyueStorageService.instance.importIntoFolder(
        folder: _folder,
        fileName: file.name,
        bytes: bytes,
      );
      if (mounted) {
        setState(() {
          _folder = _folder.copyWith(
            documents: [..._folder.documents, document],
          );
        });
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    }
  }
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.actionLabel,
    this.initialValue = '',
  });

  final String title;
  final String actionLabel;
  final String initialValue;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 80,
      decoration: const InputDecoration(hintText: '文件夹名称'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
    ],
  );
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
                    ScrollingTitle(
                      document.title,
                      style: theme.textTheme.titleMedium,
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

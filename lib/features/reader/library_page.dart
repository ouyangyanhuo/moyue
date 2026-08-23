import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/services/system_share_service.dart';
import 'package:moyue_application/widgets/moyue_action_menu.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';
import 'package:moyue_application/widgets/floating_page_shell.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';
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
  State<LibraryPage> createState() => LibraryPageState();
}

class LibraryPageState extends State<LibraryPage> {
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

    final selectingTitle = '已选择 $_selectionCount 项';
    final selectingSubtitle = '轻点条目可继续选择或取消';

    // 标题随页面滚动正常收起；玻璃按钮固定在视口之外的浮层里
    // （与阅读页浮动头部一致），获得完全相同的 premium 按压效果。
    return FloatingPageShell(
      searchHint: '搜索文档',
      onSearch: (value) => setState(() => _query = value),
      showSearch: !_selecting,
      trailing: _selecting
          ? MoyueGlassIconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: _showSelectionActions,
              semanticLabel: '所选项目操作',
              size: 44,
              useOwnLayer: true,
              settings: moyueGlassSettings(context),
            )
          : null,
      child: CustomScrollView(
        key: const PageStorageKey('library-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: FloatingPageTitle(
              title: _selecting ? selectingTitle : '阅读',
              subtitle: _selecting ? selectingSubtitle : '本地文档，安静阅读',
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
                    return DragTarget<List<ReadingDocument>>(
                      onWillAcceptWithDetails: (details) => details.data.any(
                        (document) => document.folderId != folder.id,
                      ),
                      onAcceptWithDetails: (details) =>
                          _moveDocuments(details.data, folder),
                      builder: (context, candidates, _) => _FolderTile(
                        folder: folder,
                        selected: selected,
                        dropTarget: candidates.isNotEmpty,
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
                      ),
                    );
                  }
                  final document = filtered[index - filteredFolders.length];
                  final selected = _selectedIds.contains(document.id);
                  final selectedDocuments = widget.documents
                      .where((item) => _selectedIds.contains(item.id))
                      .toList(growable: false);
                  return _DraggableDocumentTile(
                    document: document,
                    dragDocuments: selectedDocuments.isEmpty
                        ? [document]
                        : selected
                        ? selectedDocuments
                        : [...selectedDocuments, document],
                    selected: selected,
                    onDragStarted: () => _selectForDrag(document),
                    onTap: () {
                      if (_selecting) {
                        _toggleSelection(document);
                      } else {
                        Navigator.of(context).push(readerDetailRoute(document));
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> showAddMenu() => _showAddMenu();

  void _selectForDrag(ReadingDocument document) {
    if (_selectedIds.contains(document.id)) return;
    setState(() => _selectedIds.add(document.id));
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

  Future<void> _showSelectionActions() async {
    final selectedDocuments = widget.documents
        .where((document) => _selectedIds.contains(document.id))
        .toList(growable: false);
    final selectedFolders = widget.folders
        .where((folder) => _selectedFolderIds.contains(folder.id))
        .toList(growable: false);
    final action = await showMoyueActionMenu<String>(
      context: context,
      title: '已选择 $_selectionCount 项',
      actions: [
        if (selectedDocuments.isNotEmpty && widget.folders.isNotEmpty)
          const MoyueMenuAction(
            value: 'move',
            label: '移动到文件夹',
            icon: Icons.drive_file_move_outline,
          ),
        if (selectedDocuments.isNotEmpty || selectedFolders.isNotEmpty)
          MoyueMenuAction(
            value: 'share',
            label: selectedFolders.isEmpty
                ? '分享所选文档'
                : selectedDocuments.isEmpty
                ? '分享所选文件夹 (.moyue)'
                : '分享所选项目',
            icon: Icons.ios_share_rounded,
          ),
        if (selectedDocuments.length == 1 && selectedFolders.isEmpty)
          const MoyueMenuAction(
            value: 'share-folder',
            label: '分享所在文件夹 (.moyue)',
            icon: Icons.folder_zip_outlined,
          ),
        const MoyueMenuAction(
          value: 'delete',
          label: '删除',
          icon: Icons.delete_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'move') {
      await _chooseMoveDestination(selectedDocuments);
    } else if (action == 'share') {
      await _shareSelectedItems(selectedDocuments, selectedFolders);
    } else if (action == 'share-folder') {
      await _shareDocumentFolder(selectedDocuments.single);
    } else if (action == 'delete') {
      await _deleteSelected();
    }
  }

  Future<void> _chooseMoveDestination(List<ReadingDocument> documents) async {
    if (!mounted) return;
    final targets = widget.folders
        .where((folder) => documents.any((doc) => doc.folderId != folder.id))
        .toList(growable: false);
    if (targets.isEmpty) {
      await _showNotice(context, '无法移动', '没有可用的目标文件夹。');
      return;
    }
    final target = await showMoyueActionMenu<LibraryFolder>(
      context: context,
      title: '移动到',
      actions: [
        for (final folder in targets)
          MoyueMenuAction(
            value: folder,
            label: folder.name,
            icon: Icons.folder_rounded,
          ),
      ],
    );
    if (target != null && mounted) await _moveDocuments(documents, target);
  }

  Future<void> _moveDocuments(
    List<ReadingDocument> documents,
    LibraryFolder target,
  ) async {
    try {
      await MoyueStorageService.instance.moveDocuments(
        documents: documents,
        target: target,
      );
      if (mounted) {
        setState(() => _selectedIds.clear());
      }
    } on Object catch (error) {
      if (mounted) await _showNotice(context, '移动失败', '$error');
    }
  }

  Future<void> _shareSelectedItems(
    List<ReadingDocument> documents,
    List<LibraryFolder> folders,
  ) async {
    try {
      final exports = await Future.wait([
        for (final folder in folders)
          MoyueStorageService.instance.exportFolder(folder),
      ]);
      if (!mounted) return;
      await SystemShareService.shareSelection(
        context,
        documents: documents,
        folders: exports,
      );
    } on Object catch (error) {
      if (mounted) await _showNotice(context, '分享失败', '$error');
    }
  }

  Future<void> _shareDocumentFolder(ReadingDocument document) async {
    try {
      final export = await MoyueStorageService.instance.exportMoyue(document);
      if (!mounted) return;
      await SystemShareService.shareMoyue(context, export);
    } on Object catch (error) {
      if (mounted) await _showNotice(context, '分享失败', '$error');
    }
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
      final file = await FilePicker.pickFile(
        // Android SAF may mark .md files as unselectable when a custom MIME
        // filter is used. Select first, then validate the extension locally.
        type: FileType.any,
      );
      if (!mounted || file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('当前版本支持不超过 8 MB 的文本文档');
      }
      final extension = file.name.split('.').last.toLowerCase();
      if (!const {'md', 'html', 'zip', 'moyue'}.contains(extension)) {
        throw const FormatException('请选择 Markdown、HTML、ZIP 或 .moyue 文件');
      }
      final document = await MoyueStorageService.instance.importDocumentPackage(
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      await Navigator.of(context).push(readerDetailRoute(document));
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
    this.dropTarget = false,
  });

  final LibraryFolder folder;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool dropTarget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: dropTarget
          ? theme.colorScheme.secondaryContainer
          : selected
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
  const _FolderPage({required this.folder, this.subPath = ''});
  final LibraryFolder folder;

  /// 包内相对子路径（如 `二级文件夹` 或 `a/b`）；空串表示包根目录。
  final String subPath;

  @override
  State<_FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<_FolderPage> {
  late LibraryFolder _folder;
  final Set<String> _selectedIds = {};
  List<_MoveDestination> _dropTargets = const [_MoveDestination.library()];
  bool _dragging = false;

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
  Widget build(BuildContext context) {
    // 与阅读页一致：列表视口铺满全屏，顶部留白放进滚动 padding，
    // 让文档横条从浮动头部的玻璃后方穿过（沉浸式）。
    final topInset = MediaQuery.paddingOf(context).top + 72;
    final children = _childrenOf(_folder.documents);
    final itemCount = children.dirs.length + children.docs.length;
    final currentName = widget.subPath.isEmpty
        ? _folder.name
        : widget.subPath.split('/').last;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: MoyueBackdrop()),
          Positioned.fill(
            child: itemCount == 0
                ? Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: const Center(child: Text('这个目录还是空的')),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      topInset,
                      18,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    itemCount: itemCount,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index < children.dirs.length) {
                        final name = children.dirs[index];
                        final childPath = widget.subPath.isEmpty
                            ? name
                            : '${widget.subPath}/$name';
                        return _SubDirTile(
                          name: name,
                          docCount: children.dirDocCounts[name] ?? 0,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _FolderPage(
                                folder: _folder,
                                subPath: childPath,
                              ),
                            ),
                          ),
                        );
                      }
                      final document =
                          children.docs[index - children.dirs.length];
                      final selected = _selectedIds.contains(document.id);
                      final selectedDocuments = _folder.documents
                          .where((item) => _selectedIds.contains(item.id))
                          .toList(growable: false);
                      return _DraggableDocumentTile(
                        document: document,
                        dragDocuments: selectedDocuments.isEmpty
                            ? [document]
                            : selected
                            ? selectedDocuments
                            : [...selectedDocuments, document],
                        selected: selected,
                        onDragStarted: () => _selectForDrag(document),
                        onDragEnd: () {
                          if (mounted) setState(() => _dragging = false);
                        },
                        onTap: () {
                          if (_selecting) {
                            _toggleSelection(document);
                          } else {
                            Navigator.of(context)
                                .push(readerDetailRoute(document));
                          }
                        },
                      );
                    },
                  ),
          ),
          if (_dragging)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: _FolderDropTray(
                targets: _dropTargets,
                onMove: _moveDocuments,
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
                  title: _selecting
                      ? '已选择 ${_selectedIds.length} 项'
                      : currentName,
                  onBack: () => Navigator.pop(context),
                  actionIcon: _selecting
                      ? Icons.more_horiz_rounded
                      : Icons.add_rounded,
                  actionLabel: _selecting ? '所选文档操作' : '新建或导入文档',
                  onAction: _selecting ? _showSelectionActions : _showAddMenu,
                  // 只有包根目录支持重命名整个文件夹。
                  onTitleTap: _selecting || widget.subPath.isNotEmpty
                      ? null
                      : _renameFolder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 计算当前子路径下的直系内容：子目录（含各自递归文档数）与直系文档。
  /// 使用逻辑路径还原用户看到的目录层级；物理路径可能带有用于同名隔离的
  /// `.documents/<id>/`，不能拿来构建界面目录。
  ({
    List<String> dirs,
    Map<String, int> dirDocCounts,
    List<ReadingDocument> docs,
  })
  _childrenOf(List<ReadingDocument> documents) {
    final prefix = widget.subPath.isEmpty
        ? const <String>[]
        : widget.subPath.split('/');
    final dirDocCounts = <String, int>{};
    final docs = <ReadingDocument>[];
    for (final document in documents) {
      final logicalPath = document.logicalPath;
      final physicalSegments = document.relativePath?.split('/');
      final inner = logicalPath != null && logicalPath.isNotEmpty
          ? logicalPath.split('/')
          : physicalSegments != null && physicalSegments.length >= 3
          ? physicalSegments.sublist(2)
          : <String>[document.title];
      if (inner.length < prefix.length) continue;
      var matched = true;
      for (var i = 0; i < prefix.length; i++) {
        if (inner[i] != prefix[i]) {
          matched = false;
          break;
        }
      }
      if (!matched) continue;
      if (inner.length == prefix.length + 1) {
        docs.add(document);
      } else {
        final name = inner[prefix.length];
        dirDocCounts[name] = (dirDocCounts[name] ?? 0) + 1;
      }
    }
    final dirs = dirDocCounts.keys.toList()..sort();
    docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return (dirs: dirs, dirDocCounts: dirDocCounts, docs: docs);
  }

  void _toggleSelection(ReadingDocument document) {
    setState(() {
      if (!_selectedIds.add(document.id)) {
        _selectedIds.remove(document.id);
      }
    });
  }

  void _selectForDrag(ReadingDocument document) {
    setState(() {
      _selectedIds.add(document.id);
      _dragging = true;
    });
    unawaited(_loadDropTargets());
  }

  Future<void> _loadDropTargets() async {
    try {
      final folders = await MoyueStorageService.instance.loadFolders();
      if (!mounted) return;
      setState(() {
        _dropTargets = [
          const _MoveDestination.library(),
          for (final folder in folders)
            if (folder.id != _folder.id) _MoveDestination.folder(folder),
        ];
      });
    } on Object {
      // “阅读首页”目标不依赖数据库，即使其他文件夹加载失败，
      // 文档仍然可以从当前文件夹拖回首页。
    }
  }

  Future<void> _showSelectionActions() async {
    final selected = _folder.documents
        .where((document) => _selectedIds.contains(document.id))
        .toList(growable: false);
    final action = await showMoyueActionMenu<String>(
      context: context,
      title: '已选择 ${selected.length} 项',
      actions: [
        const MoyueMenuAction(
          value: 'move',
          label: '移动到…',
          icon: Icons.drive_file_move_outline,
        ),
        const MoyueMenuAction(
          value: 'share',
          label: '分享所选文档',
          icon: Icons.ios_share_rounded,
        ),
        const MoyueMenuAction(
          value: 'share-folder',
          label: '分享整个文件夹 (.moyue)',
          icon: Icons.folder_zip_outlined,
        ),
        const MoyueMenuAction(
          value: 'delete',
          label: '删除',
          icon: Icons.delete_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'move') {
      await _chooseMoveDestination(selected);
    } else if (action == 'share') {
      await _shareDocuments(selected);
    } else if (action == 'share-folder') {
      await _shareCurrentFolder();
    } else if (action == 'delete') {
      await _deleteSelected();
    }
  }

  Future<void> _chooseMoveDestination(List<ReadingDocument> documents) async {
    if (!mounted) return;
    final folders = await MoyueStorageService.instance.loadFolders();
    final targets = [
      const _MoveDestination.library(),
      for (final folder in folders)
        if (folder.id != _folder.id) _MoveDestination.folder(folder),
    ];
    if (!mounted) return;
    final target = await showMoyueActionMenu<_MoveDestination>(
      context: context,
      title: '移动到',
      actions: [
        for (final target in targets)
          MoyueMenuAction(
            value: target,
            label: target.label,
            icon: target.isLibrary ? Icons.home_outlined : Icons.folder_rounded,
          ),
      ],
    );
    if (target != null && mounted) await _moveDocuments(documents, target);
  }

  Future<void> _shareDocuments(List<ReadingDocument> documents) async {
    try {
      await SystemShareService.shareSelection(context, documents: documents);
    } on Object catch (error) {
      if (mounted) await _showNotice(context, '分享失败', '$error');
    }
  }

  Future<void> _shareCurrentFolder() async {
    try {
      final export = await MoyueStorageService.instance.exportFolder(_folder);
      if (!mounted) return;
      await SystemShareService.shareMoyue(context, export);
    } on Object catch (error) {
      if (mounted) await _showNotice(context, '分享失败', '$error');
    }
  }

  Future<void> _moveDocuments(
    List<ReadingDocument> documents,
    _MoveDestination target,
  ) async {
    try {
      if (target.isLibrary) {
        await MoyueStorageService.instance.moveDocumentsToLibrary(documents);
      } else {
        await MoyueStorageService.instance.moveDocuments(
          documents: documents,
          target: target.folder!,
        );
      }
      if (!mounted) return;
      setState(() {
        _folder = _folder.copyWith(
          documents: _folder.documents
              .where((document) => !_selectedIds.contains(document.id))
              .toList(growable: false),
        );
        _selectedIds.clear();
        _dragging = false;
      });
      final folders = await MoyueStorageService.instance.loadFolders();
      if (mounted && !folders.any((folder) => folder.id == _folder.id)) {
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _dragging = false);
      await _showNotice(context, '移动失败', '$error');
    }
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
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null || !mounted) return;
      final extension = file.name.split('.').last.toLowerCase();
      if (!const {'md', 'html'}.contains(extension)) {
        throw const FormatException('文件夹内仅支持导入 .md 或 .html 文件');
      }
      final bytes = await file.readAsBytes();
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

/// 包内子目录横条：进入后展示该物理目录下的递归内容。
class _SubDirTile extends StatelessWidget {
  const _SubDirTile({
    required this.name,
    required this.docCount,
    required this.onTap,
  });

  final String name;
  final int docCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScrollingTitle(name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '$docCount 个文档',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
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
    this.onLongPress,
    required this.selected,
  });
  final ReadingDocument document;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
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
                    Row(
                      children: [
                        Expanded(
                          child: ScrollingTitle(
                            document.title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          document.kind.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '修改于 ${DateFormat('yyyy-MM-dd HH:mm').format(document.updatedAt.toLocal())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _DraggableDocumentTile extends StatelessWidget {
  const _DraggableDocumentTile({
    required this.document,
    required this.dragDocuments,
    required this.onTap,
    required this.onDragStarted,
    required this.selected,
    this.onDragEnd,
  });

  final ReadingDocument document;
  final List<ReadingDocument> dragDocuments;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final VoidCallback? onDragEnd;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 36;
    final tile = _DocumentTile(
      document: document,
      onTap: onTap,
      // 交由 LongPressDraggable 独占长按手势，避免内层 InkWell 抢占
      // gesture arena 导致“能选择但拖不起来”。
      onLongPress: null,
      selected: selected,
    );
    return LongPressDraggable<List<ReadingDocument>>(
      data: dragDocuments,
      hapticFeedbackOnStart: true,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd?.call(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: _DocumentTile(
            document: document,
            onTap: () {},
            onLongPress: null,
            selected: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _FolderDropTray extends StatelessWidget {
  const _FolderDropTray({required this.targets, required this.onMove});

  final List<_MoveDestination> targets;
  final Future<void> Function(
    List<ReadingDocument> documents,
    _MoveDestination target,
  )
  onMove;

  @override
  Widget build(BuildContext context) => GlassContainer(
    height: 76,
    width: double.infinity,
    useOwnLayer: true,
    quality: GlassQuality.premium,
    settings: moyueGlassSettings(context),
    shape: const LiquidRoundedSuperellipse(borderRadius: 18),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.drive_file_move_outline, size: 20),
              SizedBox(height: 2),
              Text('移动到', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: targets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final target = targets[index];
              return DragTarget<List<ReadingDocument>>(
                onWillAcceptWithDetails: (details) =>
                    target.isLibrary ||
                    details.data.any(
                      (document) => document.folderId != target.folder!.id,
                    ),
                onAcceptWithDetails: (details) => onMove(details.data, target),
                builder: (context, candidates, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  constraints: const BoxConstraints(minWidth: 92),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: candidates.isEmpty
                        ? Theme.of(context).colorScheme.surface
                              .withValues(alpha: 0.28)
                        : Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: candidates.isEmpty
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        target.isLibrary
                            ? Icons.home_outlined
                            : Icons.folder_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          target.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _MoveDestination {
  const _MoveDestination.library() : folder = null;
  const _MoveDestination.folder(this.folder);

  final LibraryFolder? folder;
  bool get isLibrary => folder == null;
  String get label => isLibrary ? '阅读首页' : folder!.name;
}

Future<void> _showNotice(BuildContext context, String title, String message) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );

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

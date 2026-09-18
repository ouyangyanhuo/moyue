import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/core/files/document_import_policy.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
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
import 'package:moyue_application/widgets/moyue_create_menu.dart';
import 'package:moyue_application/widgets/scrolling_title.dart';
import 'package:moyue_application/widgets/section_label.dart';

Future<void> _showUnsupportedImportDialog(
  BuildContext context,
  String fileName,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: const Icon(Icons.error_outline_rounded),
    title: Text(dialogContext.l10n.unsupportedImportFileTitle),
    content: Text(
      dialogContext.l10n.unsupportedImportFileDescription(fileName),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(dialogContext.l10n.gotIt),
      ),
    ],
  ),
);

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
    final l10n = context.l10n;
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

    final selectingTitle = l10n.selectedItems(_selectionCount);
    final selectingSubtitle = l10n.tapToContinueSelection;

    // 标题随页面滚动正常收起；玻璃按钮固定在视口之外的浮层里
    // （与阅读页浮动头部一致），获得完全相同的 premium 按压效果。
    return FloatingPageShell(
      searchHint: l10n.searchDocuments,
      onSearch: (value) => setState(() => _query = value),
      showSearch: !_selecting,
      trailing: _selecting
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoyueGlassIconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: _shareSelected,
                  semanticLabel: l10n.shareSelectedItems,
                  size: 44,
                  useOwnLayer: true,
                  settings: moyueGlassSettings(context),
                ),
                const SizedBox(width: 8),
                MoyueGlassIconButton(
                  icon: Icon(
                    Icons.delete_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _deleteSelected,
                  semanticLabel: l10n.deleteSelectedItems,
                  size: 44,
                  useOwnLayer: true,
                  settings: moyueGlassSettings(context),
                ),
              ],
            )
          : null,
      child: CustomScrollView(
        key: const PageStorageKey('library-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: FloatingPageTitle(
              title: _selecting ? selectingTitle : l10n.libraryTitle,
              subtitle: _selecting ? selectingSubtitle : l10n.librarySubtitle,
            ),
          ),
          SliverToBoxAdapter(child: SectionLabel(l10n.documentsSection)),
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
                    final selectedDocuments = widget.documents
                        .where((item) => _selectedIds.contains(item.id))
                        .toList(growable: false);
                    final selectedFolders = widget.folders
                        .where((item) => _selectedFolderIds.contains(item.id))
                        .toList(growable: false);
                    final dragFolders = selected
                        ? selectedFolders
                        : [...selectedFolders, folder];
                    return DragTarget<_LibraryMovePayload>(
                      onWillAcceptWithDetails: (details) =>
                          !details.data.folders.any(
                            (item) => item.id == folder.id,
                          ) &&
                          (details.data.documents.any(
                                (document) => document.folderId != folder.id,
                              ) ||
                              details.data.folders.isNotEmpty),
                      onAcceptWithDetails: (details) =>
                          _moveLibraryItems(details.data, folder),
                      builder: (context, candidates, _) => _DraggableFolderTile(
                        folder: folder,
                        dragData: _LibraryMovePayload(
                          documents: selectedDocuments,
                          folders: dragFolders,
                        ),
                        selected: selected,
                        dropTarget: candidates.isNotEmpty,
                        onDragStarted: () => _selectFolderForDrag(folder),
                        onTap: () {
                          if (_selecting) {
                            _toggleFolderSelection(folder);
                          } else {
                            Navigator.of(context).push(
                              moyuePageRoute<void>(
                                context: context,
                                builder: (_) => _FolderPage(
                                  folder: folder,
                                  initialDestinations: widget.folders,
                                ),
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
                  final selectedFolders = widget.folders
                      .where((item) => _selectedFolderIds.contains(item.id))
                      .toList(growable: false);
                  final dragDocuments = selectedDocuments.isEmpty
                      ? [document]
                      : selected
                      ? selectedDocuments
                      : [...selectedDocuments, document];
                  return _DraggableDocumentTile(
                    document: document,
                    dragData: _LibraryMovePayload(
                      documents: dragDocuments,
                      folders: selectedFolders,
                    ),
                    selected: selected,
                    onDragStarted: () => _selectForDrag(document),
                    onTap: () {
                      if (_selecting) {
                        _toggleSelection(document);
                      } else {
                        Navigator.of(context)
                            .push(readerDetailRoute(context, document));
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

  void _selectFolderForDrag(LibraryFolder folder) {
    if (_selectedFolderIds.contains(folder.id)) return;
    setState(() => _selectedFolderIds.add(folder.id));
  }

  Future<void> _shareSelected() async {
    final selectedDocuments = widget.documents
        .where((document) => _selectedIds.contains(document.id))
        .toList(growable: false);
    final selectedFolders = widget.folders
        .where((folder) => _selectedFolderIds.contains(folder.id))
        .toList(growable: false);
    await _shareSelectedItems(selectedDocuments, selectedFolders);
  }

  Future<void> _moveLibraryItems(
    _LibraryMovePayload payload,
    LibraryFolder target,
  ) async {
    try {
      await MoyueStorageService.instance.moveLibraryItems(
        documents: payload.documents,
        folders: payload.folders,
        target: target,
      );
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _selectedFolderIds.clear();
        });
      }
    } on Object catch (error) {
      if (mounted) {
        await _showNotice(context, context.l10n.moveFailed, '$error');
      }
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
      if (mounted) {
        await _showNotice(context, context.l10n.shareFailed, '$error');
      }
    }
  }

  Future<void> _deleteSelected() async {
    final count = _selectionCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteItemsQuestion(count)),
        content: Text(context.l10n.deleteItemsWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
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
    final action = await showMoyueCreateMenu(context: context);
    if (action == MoyueCreateAction.markdown) await _createMarkdown();
    if (action == MoyueCreateAction.folder) await _createFolder();
    if (action == MoyueCreateAction.import) await _importDocument();
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        title: context.l10n.newFolder,
        actionLabel: context.l10n.create,
      ),
    );
    if (name == null || !mounted) return;
    try {
      await MoyueStorageService.instance.createFolder(name);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.folderCreateFailed('$error'))),
        );
      }
    }
  }

  Future<void> _createMarkdown() async {
    Navigator.of(context).restorablePush<ReadingDocument?>(markdownEditorRoute);
  }

  Future<void> _importDocument() async {
    final l10n = context.l10n;
    try {
      final file = await FilePicker.pickFile(
        // Android SAF may mark .md files as unselectable when a custom MIME
        // filter is used. Select first, then validate the extension locally.
        type: FileType.any,
      );
      if (!mounted || file == null) return;
      if (!DocumentImportPolicy.supportsFileName(file.name)) {
        await _showUnsupportedImportDialog(context, file.name);
        return;
      }
      final extension = DocumentImportPolicy.extensionOf(file.name);
      final bytes = await file.readAsBytes();
      if (DocumentImportPolicy.textExtensions.contains(extension) &&
          bytes.length > 8 * 1024 * 1024) {
        throw FormatException(l10n.documentTextLimit);
      }
      final document = await MoyueStorageService.instance.importDocumentPackage(
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      await Navigator.of(context).push(readerDetailRoute(context, document));
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed('$error'))),
        );
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
  final VoidCallback? onLongPress;
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
                      context.l10n.documentCount(folder.documents.length),
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

class _DraggableFolderTile extends StatelessWidget {
  const _DraggableFolderTile({
    required this.folder,
    required this.dragData,
    required this.selected,
    required this.dropTarget,
    required this.onTap,
    required this.onDragStarted,
  });

  final LibraryFolder folder;
  final _LibraryMovePayload dragData;
  final bool selected;
  final bool dropTarget;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 36;
    final tile = _FolderTile(
      folder: folder,
      selected: selected,
      dropTarget: dropTarget,
      onTap: onTap,
      onLongPress: null,
    );
    return LongPressDraggable<_LibraryMovePayload>(
      data: dragData,
      hapticFeedbackOnStart: true,
      onDragStarted: onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: _FolderTile(
            folder: folder,
            selected: true,
            onTap: () {},
            onLongPress: null,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _FolderPage extends StatefulWidget {
  const _FolderPage({
    required this.folder,
    this.subPath = '',
    this.initialDestinations = const [],
  });
  final LibraryFolder folder;

  /// 包内相对子路径（如 `二级文件夹` 或 `a/b`）；空串表示包根目录。
  final String subPath;
  final List<LibraryFolder> initialDestinations;

  @override
  State<_FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<_FolderPage> {
  late LibraryFolder _folder;
  final Set<String> _selectedIds = {};
  final Set<String> _selectedDirectories = {};
  final GlobalKey _expandedDropAreaKey = GlobalKey(
    debugLabel: 'expanded-folder-drop-area',
  );
  List<_MoveDestination> _dropTargets = const [];
  bool _dragging = false;
  _FolderMovePayload? _expandedDropSelection;
  Timer? _collapseExpandedTimer;
  Offset? _lastDragGlobalPosition;

  bool get _selecting =>
      _selectedIds.isNotEmpty || _selectedDirectories.isNotEmpty;
  int get _selectionCount => _selectedIds.length + _selectedDirectories.length;

  @override
  void initState() {
    super.initState();
    _folder = widget.folder;
    _dropTargets = _buildMoveDestinations([
      _folder,
      ...widget.initialDestinations.where((folder) => folder.id != _folder.id),
    ]);
    MoyueStorageService.instance.addListener(_reloadFolder);
  }

  @override
  void dispose() {
    _collapseExpandedTimer?.cancel();
    MoyueStorageService.instance.removeListener(_reloadFolder);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                    child: Center(child: Text(l10n.emptyDirectory)),
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
                        final selected = _selectedDirectories.contains(
                          childPath,
                        );
                        final selectedDirectories = _selectedDirectories.toList(
                          growable: false,
                        );
                        final selectedDocuments = _folder.documents
                            .where((item) => _selectedIds.contains(item.id))
                            .toList(growable: false);
                        return _DraggableSubDirTile(
                          name: name,
                          docCount: children.dirDocCounts[name] ?? 0,
                          selected: selected,
                          dragData: _FolderMovePayload(
                            sourceRoot: _folder,
                            documents: selectedDocuments,
                            directories: selected
                                ? selectedDirectories
                                : [...selectedDirectories, childPath],
                          ),
                          onDragStarted: () =>
                              _selectDirectoryForDrag(childPath),
                          onDragUpdate: _handleFolderDragUpdate,
                          onDragEnd: _finishDrag,
                          onTap: () {
                            if (_selecting) {
                              _toggleDirectorySelection(childPath);
                            } else {
                              Navigator.of(context).push(
                                moyuePageRoute<void>(
                                  context: context,
                                  builder: (_) => _FolderPage(
                                    folder: _folder,
                                    subPath: childPath,
                                    initialDestinations:
                                        widget.initialDestinations,
                                  ),
                                ),
                              );
                            }
                          },
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
                        dragData: _FolderMovePayload(
                          sourceRoot: _folder,
                          documents: selectedDocuments.isEmpty
                              ? [document]
                              : selected
                              ? selectedDocuments
                              : [...selectedDocuments, document],
                          directories: _selectedDirectories.toList(
                            growable: false,
                          ),
                        ),
                        selected: selected,
                        onDragStarted: () => _selectForDrag(document),
                        onDragUpdate: _handleFolderDragUpdate,
                        onDragEnd: _finishDrag,
                        onTap: () {
                          if (_selecting) {
                            _toggleSelection(document);
                          } else {
                            Navigator.of(context)
                                .push(readerDetailRoute(context, document));
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
                onMove: _moveItems,
                onExpand: _showExpandedDropTargets,
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
                      ? l10n.selectedItems(_selectionCount)
                      : currentName,
                  onBack: () => Navigator.pop(context),
                  actionIcon: _selecting
                      ? Icons.more_horiz_rounded
                      : Icons.add_rounded,
                  actionLabel: _selecting
                      ? l10n.selectedItemActions
                      : l10n.newOrImportDocument,
                  onAction: _selecting ? _showSelectionActions : _showAddMenu,
                  // 只有包根目录支持重命名整个文件夹。
                  onTitleTap: _selecting || widget.subPath.isNotEmpty
                      ? null
                      : _renameFolder,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.sizeOf(context).height * 0.68,
            child: SizedBox(
              key: _expandedDropAreaKey,
              child: IgnorePointer(
                ignoring: _expandedDropSelection == null,
                child: AnimatedSwitcher(
                  duration: moyueMotionDuration(
                    context,
                    const Duration(milliseconds: 300),
                  ),
                  reverseDuration: moyueMotionDuration(
                    context,
                    const Duration(milliseconds: 240),
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => ClipRect(
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(animation),
                      transformHitTests: true,
                      child: child,
                    ),
                  ),
                  child: _expandedDropSelection == null
                      ? const SizedBox.shrink(
                          key: ValueKey('expanded-folder-drop-sheet-hidden'),
                        )
                      : BottomSheet(
                          key: const ValueKey('expanded-folder-drop-sheet'),
                          enableDrag: false,
                          backgroundColor: Colors.transparent,
                          onClosing: () {},
                          builder: (_) => _ExpandedFolderDropSheet(
                            targets: _dropTargets,
                            onAccept: _acceptExpandedDestination,
                          ),
                        ),
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
    for (final path in _folder.subfolderPaths) {
      final segments = path
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList();
      if (segments.length <= prefix.length) continue;
      if (!_startsWithPath(segments, prefix)) continue;
      dirDocCounts.putIfAbsent(segments[prefix.length], () => 0);
    }
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

  bool _startsWithPath(List<String> path, List<String> prefix) {
    if (path.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (path[index] != prefix[index]) return false;
    }
    return true;
  }

  void _toggleSelection(ReadingDocument document) {
    setState(() {
      if (!_selectedIds.add(document.id)) {
        _selectedIds.remove(document.id);
      }
    });
  }

  void _toggleDirectorySelection(String logicalPath) {
    setState(() {
      if (!_selectedDirectories.add(logicalPath)) {
        _selectedDirectories.remove(logicalPath);
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

  void _selectDirectoryForDrag(String logicalPath) {
    setState(() {
      _selectedDirectories.add(logicalPath);
      _dragging = true;
    });
    unawaited(_loadDropTargets());
  }

  void _finishDrag() {
    if (!mounted) return;
    _cancelExpandedDropCollapse();
    _lastDragGlobalPosition = null;
    setState(() {
      _dragging = false;
      _expandedDropSelection = null;
    });
  }

  Future<void> _loadDropTargets() async {
    try {
      final folders = await MoyueStorageService.instance.loadFolders();
      if (!mounted) return;
      final destinations = folders.isEmpty
          ? widget.initialDestinations
          : folders;
      final currentMatches = destinations.where(
        (folder) => folder.id == _folder.id,
      );
      if (currentMatches.isNotEmpty) _folder = currentMatches.first;
      setState(
        () => _dropTargets = _buildMoveDestinations([
          _folder,
          ...destinations.where((folder) => folder.id != _folder.id),
        ]),
      );
    } on Object {
      // “阅读首页”目标不依赖数据库，即使其他文件夹加载失败，
      // 文档仍然可以从当前文件夹拖回首页。
    }
  }

  List<_MoveDestination> _buildMoveDestinations(List<LibraryFolder> folders) {
    final uniqueFolders = <String, LibraryFolder>{
      for (final folder in folders) folder.id: folder,
    }.values.toList(growable: false);
    return [
      const _MoveDestination.library(),
      for (final folder in uniqueFolders.skip(1))
        _MoveDestination.folder(folder),
      if (uniqueFolders.isNotEmpty)
        _MoveDestination.folder(uniqueFolders.first),
      for (final folder in uniqueFolders)
        for (final path in _logicalDirectoryPaths(folder))
          _MoveDestination.folder(folder, logicalPath: path),
    ];
  }

  List<String> _logicalDirectoryPaths(LibraryFolder folder) {
    final paths = <String>{...folder.subfolderPaths};
    void addParents(String value) {
      var current = value;
      while (current.isNotEmpty && current != '.') {
        paths.add(current);
        final slash = current.lastIndexOf('/');
        current = slash < 0 ? '' : current.substring(0, slash);
      }
    }

    for (final document in folder.documents) {
      final logicalPath = document.logicalPath;
      if (logicalPath == null || !logicalPath.contains('/')) continue;
      addParents(logicalPath.substring(0, logicalPath.lastIndexOf('/')));
    }
    return paths.toList()..sort();
  }

  Future<void> _showExpandedDropTargets(_FolderMovePayload selection) async {
    if (!mounted || !_dragging || _expandedDropSelection != null) return;
    _cancelExpandedDropCollapse();
    setState(() => _expandedDropSelection = selection);
  }

  Future<void> _acceptExpandedDestination(_MoveDestination target) async {
    final selection = _expandedDropSelection;
    if (selection == null) return;
    _cancelExpandedDropCollapse();
    if (mounted) setState(() => _expandedDropSelection = null);
    await _moveItems(selection, target);
  }

  void _handleFolderDragUpdate(DragUpdateDetails details) {
    _lastDragGlobalPosition = details.globalPosition;
    if (_expandedDropSelection == null) {
      _cancelExpandedDropCollapse();
      return;
    }
    final bounds = _expandedDropBounds;
    if (bounds == null) return;
    if (bounds.inflate(8).contains(details.globalPosition)) {
      _cancelExpandedDropCollapse();
      return;
    }
    if (_collapseExpandedTimer?.isActive ?? false) return;
    _collapseExpandedTimer = Timer(const Duration(milliseconds: 90), () {
      _collapseExpandedTimer = null;
      if (!mounted || !_dragging || _expandedDropSelection == null) return;
      final position = _lastDragGlobalPosition;
      final currentBounds = _expandedDropBounds;
      if (position == null ||
          currentBounds == null ||
          currentBounds.inflate(8).contains(position)) {
        return;
      }
      setState(() => _expandedDropSelection = null);
    });
  }

  Rect? get _expandedDropBounds {
    final renderObject = _expandedDropAreaKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _cancelExpandedDropCollapse() {
    _collapseExpandedTimer?.cancel();
    _collapseExpandedTimer = null;
  }

  Future<void> _showSelectionActions() async {
    final selected = _folder.documents
        .where((document) => _selectedIds.contains(document.id))
        .toList(growable: false);
    final selection = _FolderMovePayload(
      sourceRoot: _folder,
      documents: selected,
      directories: _selectedDirectories.toList(growable: false),
    );
    final action = await showMoyueActionMenu<String>(
      context: context,
      title: context.l10n.selectedItems(_selectionCount),
      actions: [
        MoyueMenuAction(
          value: 'move',
          label: context.l10n.moveTo,
          icon: Icons.drive_file_move_outline,
        ),
        if (selected.isNotEmpty || _selectedDirectories.isNotEmpty)
          MoyueMenuAction(
            value: 'share',
            label: context.l10n.shareSelectedItems,
            icon: Icons.ios_share_rounded,
          ),
        if (_selectedDirectories.isEmpty && selected.isNotEmpty)
          MoyueMenuAction(
            value: 'share-folder',
            label: context.l10n.shareEntireFolder,
            icon: Icons.folder_zip_outlined,
          ),
        MoyueMenuAction(
          value: 'delete',
          label: context.l10n.delete,
          icon: Icons.delete_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'move') {
      await _chooseMoveDestination(selection);
    } else if (action == 'share') {
      await _shareSelectedFolderItems(
        selected,
        _selectedDirectories.toList(growable: false),
      );
    } else if (action == 'share-folder') {
      await _shareCurrentFolder();
    } else if (action == 'delete') {
      await _deleteSelected();
    }
  }

  Future<void> _chooseMoveDestination(_FolderMovePayload selection) async {
    if (!mounted) return;
    final folders = await MoyueStorageService.instance.loadFolders();
    final currentMatches = folders.where((folder) => folder.id == _folder.id);
    if (currentMatches.isNotEmpty) _folder = currentMatches.first;
    final targets = _buildMoveDestinations([
      _folder,
      ...folders.where((folder) => folder.id != _folder.id),
    ]).where(selection.canMoveTo).toList(growable: false);
    if (!mounted) return;
    if (targets.isEmpty) {
      await _showNotice(
        context,
        context.l10n.noAvailableLocation,
        context.l10n.noAvailableLocationDescription,
      );
      return;
    }
    final target = await showMoyueActionMenu<_MoveDestination>(
      context: context,
      title: context.l10n.moveToTitle,
      actions: [
        for (final target in targets)
          MoyueMenuAction(
            value: target,
            label: target.label(context),
            icon: target.isLibrary ? Icons.home_outlined : Icons.folder_rounded,
          ),
      ],
    );
    if (target != null && mounted) await _moveItems(selection, target);
  }

  Future<void> _shareSelectedFolderItems(
    List<ReadingDocument> documents,
    List<String> directories,
  ) async {
    try {
      // A selected parent already contains every selected descendant. Export
      // only the highest selected directories to avoid duplicate packages.
      final topDirectories = directories
          .where((path) {
            return !directories.any(
              (other) => other != path && path.startsWith('$other/'),
            );
          })
          .toList(growable: false);
      final standaloneDocuments = documents
          .where((document) {
            final path = document.logicalPath;
            if (path == null) return true;
            return !topDirectories.any(
              (directory) => path.startsWith('$directory/'),
            );
          })
          .toList(growable: false);
      final exports = await Future.wait([
        for (final directory in topDirectories)
          MoyueStorageService.instance.exportSubfolder(_folder, directory),
      ]);
      if (!mounted) return;
      await SystemShareService.shareSelection(
        context,
        documents: standaloneDocuments,
        folders: exports,
      );
    } on Object catch (error) {
      if (mounted) {
        await _showNotice(context, context.l10n.shareFailed, '$error');
      }
    }
  }

  Future<void> _shareCurrentFolder() async {
    try {
      final export = await MoyueStorageService.instance.exportFolder(_folder);
      if (!mounted) return;
      await SystemShareService.shareMoyue(context, export);
    } on Object catch (error) {
      if (mounted) {
        await _showNotice(context, context.l10n.shareFailed, '$error');
      }
    }
  }

  Future<void> _moveItems(
    _FolderMovePayload selection,
    _MoveDestination target,
  ) async {
    try {
      await MoyueStorageService.instance.moveFolderItems(
        sourceRoot: selection.sourceRoot,
        documents: selection.documents,
        subfolderPaths: selection.directories,
        targetRoot: target.folder,
        targetParentPath: target.logicalPath,
      );
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectedDirectories.clear();
        _dragging = false;
        _expandedDropSelection = null;
      });
      final folders = await MoyueStorageService.instance.loadFolders();
      if (!mounted) return;
      final current = folders.where((folder) => folder.id == _folder.id);
      if (current.isEmpty) {
        Navigator.pop(context);
      } else {
        setState(() => _folder = current.first);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _dragging = false);
      await _showNotice(context, context.l10n.moveFailed, '$error');
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
    final count = _selectionCount;
    final includesFolders = _selectedDirectories.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteProjectsQuestion(count)),
        content: Text(
          includesFolders
              ? context.l10n.deleteFoldersWarning
              : context.l10n.deleteDocumentsWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
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
    for (final logicalPath in _selectedDirectories.toList(growable: false)) {
      await MoyueStorageService.instance.deleteSubfolder(
        rootFolder: _folder,
        logicalPath: logicalPath,
      );
    }
    if (!mounted) return;
    final folders = await MoyueStorageService.instance.loadFolders();
    if (!mounted) return;
    final matches = folders.where((folder) => folder.id == _folder.id);
    if (matches.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _folder = matches.first;
      _selectedIds.clear();
      _selectedDirectories.clear();
    });
  }

  Future<void> _renameFolder() async {
    if (_selecting) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        title: context.l10n.renameFolderTitle,
        actionLabel: context.l10n.save,
        initialValue: _folder.name,
      ),
    );
    if (name == null || name == _folder.name || !mounted) return;
    try {
      await MoyueStorageService.instance.renameFolder(_folder, name);
      if (mounted) setState(() => _folder = _folder.copyWith(name: name));
    } on Object catch (error) {
      if (mounted) {
        await _showNotice(context, context.l10n.renameFolderTitle, '$error');
      }
    }
  }

  Future<void> _showAddMenu() async {
    final action = await showMoyueCreateMenu(context: context);
    if (!mounted) return;
    if (action == MoyueCreateAction.markdown) await _createMarkdown();
    if (action == MoyueCreateAction.folder) await _createSubfolder();
    if (action == MoyueCreateAction.import) await _importDocument();
  }

  Future<void> _createSubfolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        title: context.l10n.newFolder,
        actionLabel: context.l10n.create,
      ),
    );
    if (name == null || !mounted) return;
    try {
      await MoyueStorageService.instance.createSubfolder(
        rootFolder: _folder,
        parentPath: widget.subPath,
        name: name,
      );
      await _reloadFolder();
    } on Object catch (error) {
      if (mounted) {
        await _showNotice(
          context,
          context.l10n.newFolder,
          context.l10n.folderCreateFailed('$error'),
        );
      }
    }
  }

  Future<void> _createMarkdown() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        title: context.l10n.newMarkdown,
        actionLabel: context.l10n.create,
      ),
    );
    if (name == null || !mounted) return;
    try {
      final document = await MoyueStorageService.instance
          .createMarkdownInFolder(
            folder: _folder,
            title: name,
            logicalDirectory: widget.subPath,
          );
      await _reloadFolder();
      if (!mounted) return;
      Navigator.of(context).restorablePush<ReadingDocument?>(
        markdownEditorRoute,
        arguments: markdownEditorArguments(document),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.createMarkdownFailed('$error'))),
        );
      }
    }
  }

  Future<void> _importDocument() async {
    final l10n = context.l10n;
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null || !mounted) return;
      if (!DocumentImportPolicy.supportsFileName(file.name)) {
        await _showUnsupportedImportDialog(context, file.name);
        return;
      }
      final extension = DocumentImportPolicy.extensionOf(file.name);
      final bytes = await file.readAsBytes();
      if (DocumentImportPolicy.textExtensions.contains(extension) &&
          bytes.length > 8 * 1024 * 1024) {
        throw FormatException(l10n.fileLimit);
      }
      await MoyueStorageService.instance.importDocumentPackageIntoFolder(
        folder: _folder,
        fileName: file.name,
        bytes: bytes,
        logicalDirectory: widget.subPath,
      );
      await _reloadFolder();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed('$error'))),
        );
      }
    }
  }
}

/// 包内子目录横条：进入后展示该物理目录下的递归内容。
class _SubDirTile extends StatelessWidget {
  const _SubDirTile({
    required this.name,
    required this.docCount,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int docCount;
  final bool selected;
  final VoidCallback onTap;

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
                      context.l10n.documentCount(docCount),
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

class _DraggableSubDirTile extends StatelessWidget {
  const _DraggableSubDirTile({
    required this.name,
    required this.docCount,
    required this.selected,
    required this.dragData,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final String name;
  final int docCount;
  final bool selected;
  final _FolderMovePayload dragData;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 36;
    final tile = _SubDirTile(
      name: name,
      docCount: docCount,
      selected: selected,
      onTap: onTap,
    );
    return LongPressDraggable<_FolderMovePayload>(
      data: dragData,
      hapticFeedbackOnStart: true,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: _SubDirTile(
            name: name,
            docCount: docCount,
            selected: true,
            onTap: () {},
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
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
      decoration: InputDecoration(hintText: context.l10n.folderName),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
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
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(document.updatedAt.toLocal()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: moyueMotionDuration(
                  context,
                  const Duration(milliseconds: 160),
                ),
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

class _DraggableDocumentTile<T extends Object> extends StatelessWidget {
  const _DraggableDocumentTile({
    required this.document,
    required this.dragData,
    required this.onTap,
    required this.onDragStarted,
    required this.selected,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final ReadingDocument document;
  final T dragData;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
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
    return LongPressDraggable<T>(
      data: dragData,
      hapticFeedbackOnStart: true,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
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

class _FolderDropTray extends StatefulWidget {
  const _FolderDropTray({
    required this.targets,
    required this.onMove,
    required this.onExpand,
  });

  final List<_MoveDestination> targets;
  final Future<void> Function(
    _FolderMovePayload selection,
    _MoveDestination target,
  )
  onMove;
  final Future<void> Function(_FolderMovePayload selection) onExpand;

  @override
  State<_FolderDropTray> createState() => _FolderDropTrayState();
}

class _FolderDropTrayState extends State<_FolderDropTray> {
  Timer? _expandTimer;

  @override
  void dispose() {
    _expandTimer?.cancel();
    super.dispose();
  }

  void _scheduleExpand(_FolderMovePayload selection) {
    if (_expandTimer?.isActive ?? false) return;
    _expandTimer = Timer(
      const Duration(milliseconds: 320),
      () => unawaited(widget.onExpand(selection)),
    );
  }

  void _cancelExpand() {
    _expandTimer?.cancel();
    _expandTimer = null;
  }

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.drive_file_move_outline, size: 20),
              const SizedBox(height: 2),
              Text(
                context.l10n.moveToTitle,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const estimatedTargetWidth = 108.0;
              final capacity = (constraints.maxWidth / estimatedTargetWidth)
                  .floor()
                  .clamp(1, widget.targets.length);
              final overflow = widget.targets.length > capacity;
              final visibleCount = overflow
                  ? (capacity - 1).clamp(0, widget.targets.length)
                  : capacity;
              final visible = widget.targets.take(visibleCount).toList();
              return Row(
                children: [
                  for (var index = 0; index < visible.length; index++) ...[
                    Flexible(
                      child: _MoveTargetChip(
                        target: visible[index],
                        onAccept: widget.onMove,
                      ),
                    ),
                    if (index != visible.length - 1 || overflow)
                      const SizedBox(width: 8),
                  ],
                  if (overflow)
                    Expanded(
                      child: DragTarget<_FolderMovePayload>(
                        onWillAcceptWithDetails: (details) =>
                            widget.targets.any(details.data.canMoveTo),
                        onMove: (details) => _scheduleExpand(details.data),
                        onLeave: (_) => _cancelExpand(),
                        onAcceptWithDetails: (details) {
                          _cancelExpand();
                          unawaited(widget.onExpand(details.data));
                        },
                        builder: (context, candidates, _) => _MoveTargetSurface(
                          icon: Icons.more_horiz_rounded,
                          label: context.l10n.moreFolders,
                          active: candidates.isNotEmpty,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _MoveTargetChip extends StatelessWidget {
  const _MoveTargetChip({required this.target, required this.onAccept});

  final _MoveDestination target;
  final Future<void> Function(
    _FolderMovePayload selection,
    _MoveDestination target,
  )
  onAccept;

  @override
  Widget build(BuildContext context) => DragTarget<_FolderMovePayload>(
    onWillAcceptWithDetails: (details) => details.data.canMoveTo(target),
    onAcceptWithDetails: (details) => onAccept(details.data, target),
    builder: (context, candidates, _) => _MoveTargetSurface(
      icon: target.isLibrary ? Icons.home_outlined : Icons.folder_rounded,
      label: target.label(context),
      active: candidates.isNotEmpty,
    ),
  );
}

class _MoveTargetSurface extends StatelessWidget {
  const _MoveTargetSurface({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: moyueMotionDuration(context, const Duration(milliseconds: 140)),
    constraints: const BoxConstraints(minWidth: 88, minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: active
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 7),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

class _ExpandedFolderDropSheet extends StatefulWidget {
  const _ExpandedFolderDropSheet({
    required this.targets,
    required this.onAccept,
  });

  final List<_MoveDestination> targets;
  final Future<void> Function(_MoveDestination target) onAccept;

  @override
  State<_ExpandedFolderDropSheet> createState() =>
      _ExpandedFolderDropSheetState();
}

class _ExpandedFolderDropSheetState extends State<_ExpandedFolderDropSheet> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleDragMove(DragTargetDetails<_FolderMovePayload> details) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final nearBottom = details.offset.dy > screenHeight - bottomInset - 92;
    if (!nearBottom) {
      _stopAutoScroll();
      return;
    }
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (_autoScrollTimer?.isActive ?? false) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      final next = (position.pixels + 14).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == position.pixels) {
        _stopAutoScroll();
      } else {
        _scrollController.jumpTo(next);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) => MoyueMaterialSheet(
    expand: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.dragToDestination,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              key: const ValueKey('expanded-folder-target-grid'),
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 56,
              ),
              itemCount: widget.targets.length,
              itemBuilder: (context, index) {
                final target = widget.targets[index];
                return DragTarget<_FolderMovePayload>(
                  onWillAcceptWithDetails: (details) =>
                      details.data.canMoveTo(target),
                  onMove: _handleDragMove,
                  onAcceptWithDetails: (_) =>
                      unawaited(widget.onAccept(target)),
                  builder: (context, candidates, _) => _MoveTargetSurface(
                    icon: target.isLibrary
                        ? Icons.home_outlined
                        : Icons.folder_rounded,
                    label: target.label(context),
                    active: candidates.isNotEmpty,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: DragTarget<_FolderMovePayload>(
              key: const ValueKey('expanded-folder-auto-scroll-target'),
              onWillAcceptWithDetails: (_) {
                _startAutoScroll();
                return true;
              },
              onMove: (_) => _startAutoScroll(),
              onLeave: (_) => _stopAutoScroll(),
              builder: (context, candidates, _) => AnimatedContainer(
                duration: moyueMotionDuration(
                  context,
                  const Duration(milliseconds: 120),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: candidates.isEmpty
                      ? Colors.transparent
                      : Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(context.l10n.dragToScroll),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MoveDestination {
  const _MoveDestination.library() : folder = null, logicalPath = '';
  const _MoveDestination.folder(this.folder, {this.logicalPath = ''});

  final LibraryFolder? folder;
  final String logicalPath;
  bool get isLibrary => folder == null;
  String label(BuildContext context) {
    if (isLibrary) return context.l10n.readingHome;
    if (logicalPath.isEmpty) return folder!.name;
    return '${folder!.name} / ${logicalPath.replaceAll('/', ' / ')}';
  }
}

class _FolderMovePayload {
  const _FolderMovePayload({
    required this.sourceRoot,
    this.documents = const [],
    this.directories = const [],
  });

  final LibraryFolder sourceRoot;
  final List<ReadingDocument> documents;
  final List<String> directories;

  bool canMoveTo(_MoveDestination target) {
    if (target.isLibrary) {
      // 子目录不能被拆散成首页单文档；若未来支持“提升为根文件夹”，
      // 应在存储层增加独立事务后再开放此目标。
      return directories.isEmpty && documents.isNotEmpty;
    }
    final targetFolder = target.folder!;
    if (targetFolder.id != sourceRoot.id) {
      return documents.isNotEmpty || directories.isNotEmpty;
    }
    for (final directory in directories) {
      if (target.logicalPath == directory ||
          target.logicalPath.startsWith('$directory/')) {
        return false;
      }
    }
    final hasMovableDirectory = directories.any((directory) {
      final slash = directory.lastIndexOf('/');
      final parent = slash < 0 ? '' : directory.substring(0, slash);
      return parent != target.logicalPath;
    });
    final hasMovableDocument = documents.any((document) {
      final logicalPath = document.logicalPath ?? '';
      final slash = logicalPath.lastIndexOf('/');
      final parent = slash < 0 ? '' : logicalPath.substring(0, slash);
      return document.folderId != targetFolder.id ||
          parent != target.logicalPath;
    });
    return hasMovableDirectory || hasMovableDocument;
  }
}

class _LibraryMovePayload {
  const _LibraryMovePayload({required this.documents, required this.folders});

  final List<ReadingDocument> documents;
  final List<LibraryFolder> folders;
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
            child: Text(context.l10n.gotIt),
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
            hasQuery
                ? context.l10n.noMatchingDocuments
                : context.l10n.noDocuments,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            hasQuery
                ? context.l10n.tryAnotherKeyword
                : context.l10n.createOrImportHint,
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
              label: Text(context.l10n.newMarkdown),
            ),
            TextButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(context.l10n.importFile),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

enum MoyueCreateAction { markdown, folder, import }

/// 新增菜单与拖拽目标共用的 Material Sheet 表面。
class MoyueMaterialSheet extends StatelessWidget {
  const MoyueMaterialSheet({
    required this.child,
    this.expand = false,
    super.key,
  });

  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.12),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (expand) Expanded(child: child) else child,
        ],
      ),
    ),
  );
}

/// 首页与文件夹页共用的 Material 新增面板。
Future<MoyueCreateAction?> showMoyueCreateMenu({
  required BuildContext context,
}) => showModalBottomSheet<MoyueCreateAction>(
  context: context,
  backgroundColor: Colors.transparent,
  useSafeArea: false,
  builder: (sheetContext) => MoyueMaterialSheet(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.note_add_outlined),
          title: const Text('新建 Markdown'),
          onTap: () => Navigator.pop(sheetContext, MoyueCreateAction.markdown),
        ),
        ListTile(
          leading: const Icon(Icons.create_new_folder_outlined),
          title: const Text('新建文件夹'),
          onTap: () => Navigator.pop(sheetContext, MoyueCreateAction.folder),
        ),
        ListTile(
          leading: const Icon(Icons.file_open_outlined),
          title: const Text('导入文件或文档包'),
          trailing: IconButton(
            icon: const Icon(Icons.error_outline_rounded),
            tooltip: '支持的文件格式',
            onPressed: () => _showImportHelp(sheetContext),
          ),
          onTap: () => Navigator.pop(sheetContext, MoyueCreateAction.import),
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

Future<void> _showImportHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('支持的文件'),
    content: const Text(
      '支持 .md、.html、.zip 和 .moyue。\n\n'
      'ZIP 或 .moyue 至少需要 2 个文件，并包含 Markdown 或 HTML。'
      '包内只允许 HTML、Markdown、CSS、JS、常见图片和视频；'
      '文档数量大于 2 时会自动创建文件夹。',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('知道了'),
      ),
    ],
  ),
);

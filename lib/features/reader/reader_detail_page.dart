import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/reader/native_html_view.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';
import 'package:moyue_application/widgets/image_lightbox.dart';
import 'package:url_launcher/url_launcher.dart';

class ReaderDetailPage extends StatefulWidget {
  const ReaderDetailPage({required this.document, super.key});
  final ReadingDocument document;

  @override
  State<ReaderDetailPage> createState() => _ReaderDetailPageState();
}

class _ReaderDetailPageState extends State<ReaderDetailPage> {
  double _textScale = 1;
  late ReadingDocument _document;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    MoyueStorageService.instance.addListener(_reloadDocument);
  }

  @override
  void dispose() {
    MoyueStorageService.instance.removeListener(_reloadDocument);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readerTopInset = MediaQuery.paddingOf(context).top + 72;
    return PopScope<void>(
      canPop: true,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(_textScale)),
                child: _document.kind == DocumentKind.markdown
                    ? _MarkdownDocument(
                        data: _document.content,
                        document: _document,
                        topInset: readerTopInset,
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          readerTopInset,
                          24,
                          118,
                        ),
                        child: NativeHtmlView(
                          data: _document.content,
                          resourceLoader: (source) => MoyueStorageService
                              .instance
                              .readLinkedResource(_document, source),
                        ),
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
                  child: FloatingDocumentHeader(
                    title: _document.title,
                    onBack: () => Navigator.of(context).pop(),
                    actionIcon: Icons.edit_outlined,
                    actionLabel: '编辑 Markdown',
                    onAction: _document.kind == DocumentKind.markdown
                        ? _editDocument
                        : null,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              height: 64,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: GlassButtonGroup.icons(
                    // The dock is positioned independently over the reader.
                    // Giving it a local glass layer keeps the shader and its
                    // hit targets in the same bottom-screen coordinate space.
                    useOwnLayer: true,
                    settings: moyueGlassSettings(context),
                    items: [
                      GlassButtonGroupItem(
                        icon: const Icon(Icons.format_list_bulleted_rounded),
                        label: '目录',
                        onTap: () => _message('目录导航将在文档索引阶段接入'),
                      ),
                      GlassButtonGroupItem(
                        icon: const Icon(Icons.text_decrease_rounded),
                        label: '缩小字体',
                        onTap: () => setState(
                          () => _textScale = (_textScale - 0.1).clamp(0.8, 1.4),
                        ),
                      ),
                      GlassButtonGroupItem(
                        icon: const Icon(Icons.text_increase_rounded),
                        label: '放大字体',
                        onTap: () => setState(
                          () => _textScale = (_textScale + 0.1).clamp(0.8, 1.4),
                        ),
                      ),
                      GlassButtonGroupItem(
                        icon: const Icon(Icons.ios_share_rounded),
                        label: '导出 .moyue',
                        onTap: _exportDocument,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editDocument() {
    Navigator.of(context).restorablePush<ReadingDocument?>(
      markdownEditorRoute,
      arguments: markdownEditorArguments(_document),
    );
  }

  Future<void> _reloadDocument() async {
    final documents = await MoyueStorageService.instance.loadDocuments();
    final folders = await MoyueStorageService.instance.loadFolders();
    final allDocuments = [
      ...documents,
      ...folders.expand((folder) => folder.documents),
    ];
    final matches = allDocuments.where(
      (item) => item.filePath == _document.filePath,
    );
    if (mounted && matches.isNotEmpty) {
      setState(() => _document = matches.first);
    }
  }

  Future<void> _exportDocument() async {
    try {
      final export = await MoyueStorageService.instance.exportMoyue(_document);
      await FilePicker.saveFile(
        dialogTitle: '导出墨阅文档包',
        fileName: export.fileName,
        type: FileType.any,
        bytes: export.bytes,
      );
      if (mounted) _message('已导出 ${export.fileName}');
    } on Object catch (error) {
      if (mounted) _message('导出失败：$error');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MarkdownDocument extends StatelessWidget {
  const _MarkdownDocument({
    required this.data,
    required this.document,
    required this.topInset,
  });
  final String data;
  final ReadingDocument document;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge!;
    return Markdown(
      data: data,
      selectable: true,
      imageBuilder: (uri, title, alt) => FutureBuilder<Uint8List?>(
        future: MoyueStorageService.instance.readLinkedResource(
          document,
          uri.toString(),
        ),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const SizedBox(
              height: 80,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            );
          }
          return GestureDetector(
            onTap: () => unawaited(ImageLightbox.show(context, bytes)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          );
        },
      ),
      padding: EdgeInsets.fromLTRB(24, topInset, 24, 92),
      onTapLink: (_, href, _) async {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: body,
        h1: theme.textTheme.headlineLarge?.copyWith(height: 1.35),
        h2: theme.textTheme.headlineMedium?.copyWith(height: 1.4),
        h3: theme.textTheme.titleLarge?.copyWith(height: 1.4),
        h4: theme.textTheme.titleMedium,
        blockquote: body.copyWith(color: theme.colorScheme.onSurfaceVariant),
        blockquotePadding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.54,
          ),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockPadding: const EdgeInsets.all(16),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        listBullet: body.copyWith(color: theme.colorScheme.primary),
        a: body.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}

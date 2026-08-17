import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/reader/native_html_view.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
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
    final display = DisplayPreferencesScope.of(context);
    final isInk = display.mode == ReadingDisplayMode.ink;
    return PopScope<void>(
      canPop: true,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: theme.colorScheme.surface,
        appBar: GlassAppBar(
          toolbarHeight: 58,
          leading: GlassIconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(CupertinoIcons.chevron_back, size: 21),
            semanticLabel: '返回',
            size: 44,
            glowColor: Colors.transparent,
            useOwnLayer: true,
          ),
          title: GlassContainer(
            width: 204,
            height: 42,
            useOwnLayer: true,
            shape: const LiquidRoundedSuperellipse(borderRadius: 12),
            glowIntensity: 0,
            alignment: Alignment.center,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: (constraints.maxWidth - 32).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Text(
                    _document.title,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            if (_document.kind == DocumentKind.markdown)
              GlassIconButton(
                icon: const Icon(CupertinoIcons.pencil, size: 20),
                semanticLabel: '编辑 Markdown',
                onPressed: _editDocument,
                glowColor: Colors.transparent,
                useOwnLayer: true,
                size: 44,
              ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(_textScale)),
            child: _document.kind == DocumentKind.markdown
                ? _MarkdownDocument(data: _document.content)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 92),
                    child: NativeHtmlView(data: _document.content),
                  ),
          ),
        ),
        bottomNavigationBar: GlassToolbar(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          children: [
            GlassButtonGroup.icons(
              items: [
                GlassButtonGroupItem(
                  icon: Icon(
                    isInk ? Icons.water_drop : Icons.water_drop_outlined,
                  ),
                  label: '墨模式',
                  onTap: () => display.setMode(
                    isInk ? ReadingDisplayMode.paper : ReadingDisplayMode.ink,
                  ),
                ),
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
                  label: '分享',
                  onTap: () => _message('已准备分享「${_document.title}」'),
                ),
              ],
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
    final matches = documents.where(
      (item) => item.filePath == _document.filePath,
    );
    if (mounted && matches.isNotEmpty) {
      setState(() => _document = matches.first);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MarkdownDocument extends StatelessWidget {
  const _MarkdownDocument({required this.data});
  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge!;
    return Markdown(
      data: data,
      selectable: true,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 92),
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

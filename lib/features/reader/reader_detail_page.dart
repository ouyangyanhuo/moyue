import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/reader/native_html_view.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:url_launcher/url_launcher.dart';

class ReaderDetailPage extends StatefulWidget {
  const ReaderDetailPage({required this.document, super.key});
  final ReadingDocument document;

  @override
  State<ReaderDetailPage> createState() => _ReaderDetailPageState();
}

class _ReaderDetailPageState extends State<ReaderDetailPage> {
  double _textScale = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = DisplayPreferencesScope.of(context);
    final isInk = display.mode == ReadingDisplayMode.ink;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: '返回',
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.document.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.document.kind.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GlassIconButton(
              icon: Icon(isInk ? Icons.water_drop : Icons.water_drop_outlined),
              semanticLabel: '墨模式',
              onPressed: () => display.setMode(
                isInk ? ReadingDisplayMode.paper : ReadingDisplayMode.ink,
              ),
              useOwnLayer: true,
              size: 42,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(_textScale)),
          child: widget.document.kind == DocumentKind.markdown
              ? _MarkdownDocument(data: widget.document.content)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 92),
                  child: NativeHtmlView(data: widget.document.content),
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
                onTap: () => _message('已准备分享「${widget.document.title}」'),
              ),
            ],
          ),
        ],
      ),
    );
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

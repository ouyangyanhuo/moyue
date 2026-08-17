import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/services/rss_service.dart';
import 'package:moyue_application/widgets/page_heading.dart';
import 'package:moyue_application/widgets/section_label.dart';
import 'package:url_launcher/url_launcher.dart';

class RssPage extends StatefulWidget {
  const RssPage({
    required this.initialSources,
    required this.initialArticles,
    super.key,
  });
  final List<FeedSource> initialSources;
  final List<FeedArticle> initialArticles;

  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> with AutomaticKeepAliveClientMixin {
  late final RssService _rssService;
  late final List<FeedSource> _sources;
  late List<FeedArticle> _articles;
  String _query = '';
  String? _loadingSourceId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rssService = RssService();
    _sources = List.of(widget.initialSources);
    _articles = List.of(widget.initialArticles);
  }

  @override
  void dispose() {
    _rssService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final query = _query.trim().toLowerCase();
    final sources = _sources
        .where((source) {
          return query.isEmpty ||
              source.title.toLowerCase().contains(query) ||
              source.url.toString().toLowerCase().contains(query);
        })
        .toList(growable: false);
    final articles = _articles
        .where((article) {
          return query.isEmpty ||
              article.title.toLowerCase().contains(query) ||
              article.summary.toLowerCase().contains(query) ||
              article.sourceTitle.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        key: const PageStorageKey('rss-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeading(
              title: '订阅',
              subtitle: '${_sources.length} 个订阅源 · 下拉即可刷新',
              searchHint: '搜索订阅或文章',
              onSearch: (value) => setState(() => _query = value),
              trailing: GlassIconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _showAddSource,
                semanticLabel: '添加订阅',
                size: 46,
                useOwnLayer: true,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionLabel(
              '订阅源',
              action: Text(
                '点按单独刷新',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverList.separated(
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final source = sources[index];
                return _FeedSourceTile(
                  source: source,
                  loading: _loadingSourceId == source.id,
                  onTap: () => _refreshSource(source),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SectionLabel(
              query.isEmpty ? '最新文章' : '搜索结果',
              action: Text(
                '${articles.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (articles.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyArticles(hasQuery: query.isNotEmpty),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 118),
              sliver: SliverList.separated(
                itemCount: articles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ArticleCard(
                  article: articles[index],
                  onTap: () => _openArticle(articles[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshSource(FeedSource source) async {
    if (_loadingSourceId != null) return;
    setState(() => _loadingSourceId = source.id);
    try {
      final result = await _rssService.load(source);
      if (!mounted) return;
      final sourceIndex = _sources.indexWhere((item) => item.id == source.id);
      if (sourceIndex >= 0) {
        _sources[sourceIndex] = source.copyWith(
          title: result.title,
          unreadCount: result.articles.length,
        );
      }
      setState(() {
        _articles = [
          ...result.articles,
          ..._articles.where((article) => article.sourceId != source.id),
        ];
      });
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刷新 ${source.title} 失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _loadingSourceId = null);
    }
  }

  Future<void> _refreshAll() async {
    for (final source in List<FeedSource>.of(_sources)) {
      await _refreshSource(source);
    }
  }

  Future<void> _openArticle(FeedArticle article) async {
    final link = article.link;
    if (link == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('这篇文章没有可打开的链接')));
      return;
    }
    await launchUrl(link, mode: LaunchMode.externalApplication);
  }

  Future<void> _showAddSource() async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final source = await showDialog<FeedSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加 RSS 订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '名称（可选）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '订阅地址',
                hintText: 'https://example.com/feed.xml',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final uri = Uri.tryParse(urlController.text.trim());
              if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('请输入完整的 https 订阅地址')),
                );
                return;
              }
              Navigator.pop(
                dialogContext,
                FeedSource(
                  id: 'feed-${DateTime.now().microsecondsSinceEpoch}',
                  title: titleController.text.trim().isEmpty
                      ? uri.host
                      : titleController.text.trim(),
                  url: uri,
                ),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    titleController.dispose();
    urlController.dispose();
    if (source == null || !mounted) return;
    setState(() => _sources.insert(0, source));
    await _refreshSource(source);
  }
}

class _FeedSourceTile extends StatelessWidget {
  const _FeedSourceTile({
    required this.source,
    required this.loading,
    required this.onTap,
  });
  final FeedSource source;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      const Color(0xFFA94642),
      const Color(0xFF4B8883),
      const Color(0xFF7A654D),
      const Color(0xFF747C68),
    ];
    final color = colors[source.id.hashCode.abs() % colors.length];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        source.title.characters.first.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      source.url.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${source.unreadCount}',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTap});
  final FeedArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${article.sourceTitle} · ${_relativeTime(article.publishedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.summary.isEmpty ? '点按阅读原文' : article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.rss_feed_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime? time) {
    if (time == null) {
      return '时间未知';
    }
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes.clamp(1, 59)} 分钟前';
    }
    if (difference.inHours < 24) return '${difference.inHours} 小时前';
    return '${difference.inDays} 天前';
  }
}

class _EmptyArticles extends StatelessWidget {
  const _EmptyArticles({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 42, 24, 120),
    child: Column(
      children: [
        Icon(
          Icons.rss_feed_rounded,
          size: 44,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(hasQuery ? '没有匹配的文章' : '下拉刷新订阅源'),
      ],
    ),
  );
}

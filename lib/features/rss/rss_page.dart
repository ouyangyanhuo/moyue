import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/services/rss_service.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/page_heading.dart';
import 'package:moyue_application/widgets/section_label.dart';
import 'package:url_launcher/url_launcher.dart';

class RssPage extends StatefulWidget {
  const RssPage({this.initialSources = const [], super.key});

  final List<FeedSource> initialSources;

  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> with AutomaticKeepAliveClientMixin {
  late final RssService _rssService;
  final List<FeedSource> _sources = [];
  List<FeedArticle> _articles = [];
  String _query = '';
  String? _loadingSourceId;
  final Set<String> _selectedSourceIds = {};

  bool get _selecting => _selectedSourceIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rssService = RssService();
    _sources.addAll(widget.initialSources);
    _loadStoredFeeds();
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
              title: _selecting ? '已选择 ${_selectedSourceIds.length} 项' : '订阅',
              subtitle: _selecting
                  ? '轻点订阅源可继续选择或取消'
                  : '${_sources.length} 个订阅源 · 下拉即可刷新',
              searchHint: '搜索订阅或文章',
              onSearch: (value) => setState(() => _query = value),
              showSearch: !_selecting,
              trailing: GlassIconButton(
                icon: Icon(
                  _selecting ? Icons.delete_rounded : Icons.add_rounded,
                  color: _selecting
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                onPressed: _selecting ? _deleteSelectedSources : _showAddSource,
                semanticLabel: _selecting ? '删除所选订阅' : '添加订阅',
                size: 46,
                useOwnLayer: true,
                settings: moyueGlassSettings(context),
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
            sliver: sources.isEmpty
                ? SliverToBoxAdapter(
                    child: _EmptySources(
                      hasQuery: query.isNotEmpty,
                      onAdd: _showAddSource,
                    ),
                  )
                : SliverList.separated(
                    itemCount: sources.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final source = sources[index];
                      return _FeedSourceTile(
                        source: source,
                        loading: _loadingSourceId == source.id,
                        selected: _selectedSourceIds.contains(source.id),
                        onLongPress: () => _toggleSourceSelection(source),
                        onTap: () => _selecting
                            ? _toggleSourceSelection(source)
                            : _refreshSource(source),
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
      if (result.errorMessage case final message?) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      final stored = await MoyueStorageService.instance.saveFeedXml(
        source,
        result.rawBody,
      );
      final sourceIndex = _sources.indexWhere((item) => item.id == source.id);
      if (sourceIndex >= 0) {
        _sources[sourceIndex] = stored.copyWith(
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
      await MoyueStorageService.instance.saveFeedSources(_sources);
    } on Object catch (error) {
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
    final source = await showModalBottomSheet<FeedSource>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddFeedSheet(),
    );
    if (source == null || !mounted) return;
    setState(() => _sources.insert(0, source));
    try {
      await MoyueStorageService.instance.saveFeedSources(_sources);
      await _refreshSource(source);
    } on Object catch (error) {
      _sources.removeWhere((item) => item.id == source.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('添加订阅失败：$error')));
      }
    }
  }

  Future<void> _loadStoredFeeds() async {
    try {
      final sources = await MoyueStorageService.instance.loadFeedSources();
      final articles = <FeedArticle>[];
      for (final source in sources) {
        final xml = await MoyueStorageService.instance.readFeedXml(source);
        if (xml == null || xml.isEmpty) continue;
        try {
          articles.addAll(_rssService.parse(source, xml).articles);
        } on Object {
          // Keep the subscription even if a previously saved feed is malformed.
        }
      }
      if (mounted) {
        setState(() {
          _sources
            ..clear()
            ..addAll(sources);
          _articles = articles;
        });
      }
    } on Object {
      // The empty-state remains usable if local index initialization fails.
    }
  }

  void _toggleSourceSelection(FeedSource source) {
    setState(() {
      if (!_selectedSourceIds.add(source.id)) {
        _selectedSourceIds.remove(source.id);
      }
    });
  }

  Future<void> _deleteSelectedSources() async {
    final selected = _sources
        .where((source) => _selectedSourceIds.contains(source.id))
        .toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${selected.length} 个订阅？'),
        content: const Text('所选订阅源及已保存的 RSS 文件会一并删除。'),
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
    for (final source in selected) {
      await MoyueStorageService.instance.deleteFeed(source);
    }
    _sources.removeWhere((item) => _selectedSourceIds.contains(item.id));
    _articles = _articles
        .where((item) => !_selectedSourceIds.contains(item.sourceId))
        .toList();
    _selectedSourceIds.clear();
    await MoyueStorageService.instance.saveFeedSources(_sources);
    if (mounted) setState(() {});
  }
}

class _AddFeedSheet extends StatefulWidget {
  const _AddFeedSheet();

  @override
  State<_AddFeedSheet> createState() => _AddFeedSheetState();
}

class _AddFeedSheetState extends State<_AddFeedSheet> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('添加 RSS 订阅', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '订阅地址',
              hintText: 'https://example.com/feed.xml',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '名称（可选）'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _submit, child: const Text('添加订阅')),
        ],
      ),
    ),
  );

  void _submit() {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _error = '请输入完整的 https 订阅地址');
      return;
    }
    Navigator.pop(
      context,
      FeedSource(
        id: 'feed-${DateTime.now().microsecondsSinceEpoch}',
        title: _title.text.trim().isEmpty ? uri.host : _title.text.trim(),
        url: uri,
      ),
    );
  }
}

class _FeedSourceTile extends StatelessWidget {
  const _FeedSourceTile({
    required this.source,
    required this.loading,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });
  final FeedSource source;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

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
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources({required this.hasQuery, required this.onAdd});
  final bool hasQuery;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      child: Column(
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.rss_feed_rounded,
            size: 44,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            hasQuery ? '没有匹配的订阅' : '还没有订阅',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery ? '换一个关键词试试' : '添加订阅后，原始 RSS 会保存在本地',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加 RSS 订阅'),
            ),
          ],
        ],
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

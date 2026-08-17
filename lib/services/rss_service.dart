import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:moyue_application/models/feed_models.dart';
import 'package:rss_dart/dart_rss.dart';

class FeedLoadResult {
  const FeedLoadResult({
    required this.title,
    required this.articles,
    required this.rawBody,
  });
  final String title;
  final List<FeedArticle> articles;
  final String rawBody;
}

class RssService {
  RssService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<FeedLoadResult> load(FeedSource source) async {
    final response = await _client
        .get(
          source.url,
          headers: const {
            'accept': 'application/rss+xml, application/atom+xml, text/xml',
            'user-agent': 'Moyue/1.0 RSS Reader',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RssLoadException('订阅源返回 ${response.statusCode}');
    }

    return parse(source, response.body);
  }

  FeedLoadResult parse(FeedSource source, String body) {
    if (_looksLikeAtom(body)) {
      final feed = AtomFeed.parse(body);
      final sourceTitle = _clean(feed.title) ?? source.title;
      return FeedLoadResult(
        title: sourceTitle,
        rawBody: body,
        articles: feed.items
            .take(30)
            .map((item) {
              final link = item.links.isEmpty ? null : item.links.first.href;
              return FeedArticle(
                id: item.id ?? link ?? '${source.id}-${item.title}',
                sourceId: source.id,
                sourceTitle: sourceTitle,
                title: _clean(item.title) ?? '无标题文章',
                summary: _plainText(item.summary ?? item.content ?? ''),
                link: link == null ? null : Uri.tryParse(link),
                publishedAt: DateTime.tryParse(
                  item.updated ?? item.published ?? '',
                ),
              );
            })
            .toList(growable: false),
      );
    }

    final feed = RssFeed.parse(body);
    final sourceTitle = _clean(feed.title) ?? source.title;
    return FeedLoadResult(
      title: sourceTitle,
      rawBody: body,
      articles: feed.items
          .take(30)
          .map((item) {
            return FeedArticle(
              id: item.guid ?? item.link ?? '${source.id}-${item.title}',
              sourceId: source.id,
              sourceTitle: sourceTitle,
              title: _clean(item.title) ?? '无标题文章',
              summary: _plainText(item.description ?? ''),
              link: item.link == null ? null : Uri.tryParse(item.link!),
              publishedAt: _parseRssDate(item.pubDate),
            );
          })
          .toList(growable: false),
    );
  }

  bool _looksLikeAtom(String value) {
    final prefix = value.substring(0, value.length.clamp(0, 600)).toLowerCase();
    return prefix.contains('<feed') && prefix.contains('atom');
  }

  String _plainText(String value) {
    final text = (html_parser.parseFragment(value).text ?? '').trim();
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  DateTime? _parseRssDate(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  void dispose() => _client.close();
}

class RssLoadException implements Exception {
  const RssLoadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class FeedSource {
  const FeedSource({
    required this.id,
    required this.title,
    required this.url,
    this.unreadCount = 0,
  });

  final String id;
  final String title;
  final Uri url;
  final int unreadCount;

  FeedSource copyWith({String? title, Uri? url, int? unreadCount}) =>
      FeedSource(
        id: id,
        title: title ?? this.title,
        url: url ?? this.url,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

class FeedArticle {
  const FeedArticle({
    required this.id,
    required this.sourceId,
    required this.sourceTitle,
    required this.title,
    required this.summary,
    required this.link,
    required this.publishedAt,
  });

  final String id;
  final String sourceId;
  final String sourceTitle;
  final String title;
  final String summary;
  final Uri? link;
  final DateTime? publishedAt;
}

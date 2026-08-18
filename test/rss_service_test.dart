import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/services/rss_service.dart';

void main() {
  test('RSS 2.0 订阅源会被解析为原生文章模型', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode('''
        <rss version="2.0"><channel>
          <title>测试订阅</title>
          <item>
            <guid>article-1</guid>
            <title>原生 RSS 阅读</title>
            <description><![CDATA[<p>不使用 WebView。</p>]]></description>
            <link>https://example.com/article-1</link>
            <pubDate>2026-08-17T09:41:00Z</pubDate>
          </item>
        </channel></rss>
      '''),
        200,
        headers: {'content-type': 'application/rss+xml; charset=utf-8'},
      );
    });
    final service = RssService(client: client);
    addTearDown(service.dispose);

    final result = await service.load(
      FeedSource(
        id: 'test',
        title: '占位名称',
        url: Uri.parse('https://example.com/feed.xml'),
      ),
    );

    expect(result.title, '测试订阅');
    expect(result.errorMessage, isNull);
    expect(result.rawBody, contains('<rss version="2.0">'));
    expect(result.articles, hasLength(1));
    expect(result.articles.single.title, '原生 RSS 阅读');
    expect(result.articles.single.summary, '不使用 WebView。');
    expect(
      result.articles.single.link,
      Uri.parse('https://example.com/article-1'),
    );
  });

  test('网络失败会返回可展示错误而不会逃逸到主 isolate', () async {
    final client = MockClient((request) async {
      throw http.ClientException('连接失败');
    });
    final service = RssService(client: client);
    addTearDown(service.dispose);

    final result = await service.load(
      FeedSource(
        id: 'offline',
        title: '离线订阅',
        url: Uri.parse('https://example.com/feed.xml'),
      ),
    );

    expect(result.articles, isEmpty);
    expect(result.errorMessage, contains('连接失败'));
  });

  test('未声明 charset 的 GBK 中文 RSS 会按原始字节正确解码', () async {
    final xml = '''
      <rss version="2.0"><channel><title>中文订阅</title>
      <item><guid>cn-1</guid><title>中文文章</title>
      <description>正文内容</description></item></channel></rss>
    ''';
    final client = MockClient(
      (_) async => http.Response.bytes(gbk.encode(xml), 200),
    );
    final service = RssService(client: client);
    addTearDown(service.dispose);

    final result = await service.load(
      FeedSource(
        id: 'gbk',
        title: '占位名称',
        url: Uri.parse('https://example.com/cn.xml'),
      ),
    );

    expect(result.title, '中文订阅');
    expect(result.articles.single.title, '中文文章');
    expect(result.articles.single.summary, '正文内容');
  });
}

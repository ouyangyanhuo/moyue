import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/reading_document.dart';

const sampleMarkdown = r'''# 设计随笔

好的设计是克制的，也是充满善意的。  
它在于解决问题，而非炫耀技法。

> 少即是多，但少的前提是足够好。  
> — Dieter Rams

## 关注要点

- [x] 明确问题与目标
- [x] 信息层级清晰
- [ ] 交互反馈及时
- [ ] 视觉克制一致

## 代码示例

```javascript
function hello(name) {
  console.log(`Hello, ${name}!`);
}

hello('Moyue');
```

## 回到文字本身

阅读界面的价值不在于装饰，而在于让注意力自然落到内容上。墨阅保留必要的触感，同时让正文保持安静、稳定与清晰。
''';

const sampleHtml = '''
<!doctype html><html lang="zh-CN"><body>
<h1>HTML 阅读示例</h1>
<p>这是由 <strong>Flutter 原生组件</strong> 排版的 HTML 文档，不依赖 WebView。</p>
<blockquote>阅读不是浏览，而是与作者共享一段安静的时间。</blockquote>
<h2>支持的内容</h2>
<ul><li>标题、段落与强调</li><li>有序和无序列表</li><li>引用、代码块与链接</li></ul>
<pre><code>final reader = MoyueReader.native();</code></pre>
<p><a href="https://flutter.dev">了解 Flutter</a></p>
</body></html>
''';

final initialDocuments = <ReadingDocument>[
  ReadingDocument(
    id: 'design-notes',
    title: '设计随笔',
    content: sampleMarkdown,
    kind: DocumentKind.markdown,
    updatedAt: DateTime(2026, 8, 17, 9, 41),
  ),
  ReadingDocument(
    id: 'html-native-reader',
    title: 'HTML 原生阅读示例',
    content: sampleHtml,
    kind: DocumentKind.html,
    updatedAt: DateTime(2026, 8, 16, 20, 18),
  ),
  ReadingDocument(
    id: 'markdown-writing',
    title: '如何优雅地使用 Markdown',
    content: '# 如何优雅地使用 Markdown\n\n让标记退到文字背后，让结构自然浮现。',
    kind: DocumentKind.markdown,
    updatedAt: DateTime(2026, 8, 15, 18, 30),
  ),
];

final initialFeedSources = <FeedSource>[
  FeedSource(
    id: 'sspai',
    title: '少数派',
    url: Uri.parse('https://sspai.com/feed'),
    unreadCount: 24,
  ),
  FeedSource(
    id: 'wuyanlan',
    title: '阮一峰的网络日志',
    url: Uri.parse('https://www.ruanyifeng.com/blog/atom.xml'),
    unreadCount: 18,
  ),
  FeedSource(
    id: 'macstories',
    title: 'MacStories',
    url: Uri.parse('https://www.macstories.net/feed/'),
    unreadCount: 12,
  ),
];

final sampleFeedArticles = <FeedArticle>[
  FeedArticle(
    id: 'a1',
    sourceId: 'sspai',
    sourceTitle: '少数派',
    title: '如何优雅地使用 Markdown',
    summary: '分享一些提升 Markdown 写作效率的小技巧。',
    link: Uri.parse('https://sspai.com'),
    publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  FeedArticle(
    id: 'a2',
    sourceId: 'wuyanlan',
    sourceTitle: '阮一峰的网络日志',
    title: 'ChatGPT 背后的工程细节',
    summary: '从工程角度聊聊大模型应用的架构与实践要点。',
    link: Uri.parse('https://www.ruanyifeng.com/blog/'),
    publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  FeedArticle(
    id: 'a3',
    sourceId: 'macstories',
    sourceTitle: 'MacStories',
    title: '全新的移动阅读体验',
    summary: '关于专注、排版和移动端内容消费的观察。',
    link: Uri.parse('https://www.macstories.net'),
    publishedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

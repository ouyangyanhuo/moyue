# 墨阅 / Moyue

一款面向手机阅读场景的 Markdown、HTML 与 RSS 阅读器。界面使用温和的纸张色、Material 3 排版和克制的 Liquid Glass 交互层。

## 当前功能

- 阅读 `.md`、`.markdown`、`.html`、`.htm` 本地文件。
- Markdown 由 `flutter_markdown_plus` 转换为 Flutter Widget；没有 WebView 依赖。
- HTML 由 `package:html` 解析 DOM，再映射为 Flutter 文本、列表、引用和代码区块；没有 WebView 依赖。
- Markdown 编辑、快捷格式工具和原生实时预览。
- RSS 1.0 / 2.0 / Atom 订阅、刷新、搜索与外部浏览器打开原文。
- 纸张模式与墨模式，以及对比度和减少动态效果偏好。

## 结构说明

- `lib/core/display/display_preferences.dart` 定义墨模式边界。后续接入电子墨水屏刷新策略时，可替换 `DisplayModeController` 的实现而无需修改业务页面。
- `lib/features/reader/` 包含原生 Markdown/HTML 阅读界面。
- `lib/features/editor/` 包含编辑器与预览。
- `lib/features/rss/` 和 `lib/services/rss_service.dart` 包含订阅界面与真实网络解析。
- `liquid_glass_widgets` 仅用于 Dock、圆形按钮、搜索和工具按钮，正文保持稳定的实体纸张表面。

## 验证

```sh
flutter analyze
flutter test
flutter build web
```

# 墨阅 / Moyue

一款面向**手机阅读场景**的 Markdown、HTML 与 RSS 阅读器。界面使用温和的纸张色、Material 3 排版和克制的 Liquid Glass 交互层（仅用于 Dock、圆形按钮、搜索和工具按钮，正文始终保持在稳定的实体纸张表面上）。

软件原则是**不使用任何 WebView / 浏览器内核**，Markdown 与 HTML 全部映射为原生 Flutter Widget 渲染，以适配移动端与未来的电子墨水屏。

## 当前功能

- 阅读 `.md`、`.markdown`、`.html`、`.htm` 本地文件。
- Markdown 由 `flutter_markdown_plus` 转换为 Flutter Widget；没有 WebView 依赖。
- HTML 由 `package:html` 解析 DOM，再映射为 Flutter 文本、列表、引用和代码区块；没有 WebView 依赖。
- Markdown 编辑、快捷格式工具和原生实时预览。
- 自定义 `.moyue` 文档包（ZIP + `meta.json`）导入 / 导出。
- RSS 1.0 / 2.0 / Atom 订阅、刷新、搜索与外部浏览器打开原文。
- 纸张模式与墨模式，以及对比度和减少动态效果偏好。

## 架构总览

```mermaid
flowchart TD
    subgraph SHELL[App Shell · lib/app]
        A[MoyueApp / MoyueShell]
        A --> B[LibraryPage<br/>阅读]
        A --> C[RssPage<br/>订阅]
        A --> D[SettingsPage<br/>设置]
    end

    subgraph FEAT[Feature 页面 · lib/features]
        B --> E[ReaderDetailPage<br/>文档阅读]
        B --> F[MarkdownEditorPage<br/>编辑 / 预览]
        E --> F
    end

    subgraph CORE[核心边界 · lib/core]
        G[DisplayModeController<br/>纸张 / 墨模式]
        H[MoyueTheme<br/>调色板 / 排版]
        I[MoyueI18n<br/>本地化边界]
    end

    subgraph SVC[Services · lib/services]
        J[MoyueStorageService<br/>存储门面 · 单例]
        K[DocumentPackageService<br/>文档包导入/导出]
        L[RssService<br/>订阅网络解析]
        M[TextDecoder<br/>UTF-8 / GBK 回退]
    end

    subgraph DATA[数据层]
        N[(moyue_index.db<br/>SQLite 索引)]
        O[/markdown · html · rss 文件/]
    end

    E --> J
    F --> J
    C --> L
    J --> K
    J --> N
    J --> O
    K --> M
    L --> M
    G -.驱动主题.-> H
```

## 渲染管线（无 WebView）

Markdown 与 HTML 各自走原生 Widget 路径，最终都渲染为 Flutter 组件；图片等资源通过 `readLinkedResource` 按文档所在目录解析相对链接后以字节流渲染。

```mermaid
flowchart LR
    subgraph IN[输入]
        MD1[Markdown 源码]
        HTML1[HTML 源码]
    end

    MD1 --> MFP[flutter_markdown_plus<br/>Markdown 组件]
    HTML1 --> HP[package:html<br/>DOM 解析]

    MFP --> W1[Markdown Widget<br/>+ MarkdownStyleSheet]
    HP --> W2[NativeHtmlView<br/>DOM → 原生 Widget]

    W1 --> RW[原生 Widget 渲染<br/>无 WebView]
    W2 --> RW

    RW --> RES[readLinkedResource<br/>→ Image.memory]
```

## 文档导入事务（.moyue / .zip）

导入是**事务性**的：先校验路径安全与允许的扩展名，再解析 `meta.json` 并校验 `format_version`，随后暂存 SQLite 行并写文件，全部成功后提交；任一失败则回滚数据库行并删除部分写入的目录。

```mermaid
sequenceDiagram
    participant U as 用户
    participant UI as LibraryPage
    participant P as DocumentPackageService
    participant D as moyue_index.db
    participant F as PackageFileStore

    U->>UI: 选择 .md / .html / .zip / .moyue
    UI->>P: importFile(bytes)
    P->>P: 校验路径安全（.. / 绝对 / 符号链接）
    P->>P: 校验允许扩展名
    P->>P: 解析 meta.json · 校验 format_version
    P->>D: 暂存 folders / documents / resources 行
    P->>F: 写入文档包文件
    alt 全部成功
        D->>D: 提交事务
        P-->>UI: 返回主文档
    else 任一失败
        D->>D: 回滚事务
        F->>F: 删除部分目录
        P-->>UI: 抛出 FormatException
    end
```

## 存储映射（SQLite 只存相对路径）

```mermaid
flowchart LR
    R[应用根目录]
    R --> DB["moyue_index.db<br/>SQLite 索引"]
    R --> MD["markdown/{folder-id}/..."]
    R --> HT["html/{folder-id}/..."]
    R --> RS["rss/{folder-id}/feed.xml"]

    DB -.绝对路径由平台适配器运行时解析.-> R
```

## 编辑器：自动保存与恢复

编辑内容约 900ms 防抖后自动保存；应用进入后台（inactive / paused / hidden）时主动持久化；标题、正文与脏标记均通过 `RestorableTextEditingController` / `RestorationMixin` 支持进程重启后的状态恢复。

```mermaid
flowchart TD
    T[编辑正文 / 标题] --> DT[900ms 防抖定时器]
    DT --> SAVE[保存存储 · dirty=false]
    L{应用生命周期变化} -->|inactive / paused / hidden| P[unawaited persist]
    P --> SAVE
    R[RestorableTextEditingController] --> ST[进程重启后<br/>Restoration 恢复]
```

## 结构说明

- `lib/core/display/display_preferences.dart` 定义墨模式边界。后续接入电子墨水屏刷新策略时，可替换 `DisplayModeController` 的实现而无需修改业务页面。
- `lib/features/reader/` 包含原生 Markdown/HTML 阅读界面（`NativeHtmlView`）。
- `lib/features/editor/` 包含编辑器、快捷格式与实时预览。
- `lib/features/rss/` 和 `lib/services/rss_service.dart` 包含订阅界面与真实网络解析。
- `lib/services/document_package_service.dart` 实现 `.moyue` / `.zip` 文档包的导入、导出与资源解析。
- `docs/moyue-format-v1.md` 描述 `.moyue` 文档包格式规范 v1。
- `liquid_glass_widgets` 仅用于 Dock、圆形按钮、搜索和工具按钮，正文保持稳定的实体纸张表面。

## 验证

```sh
flutter pub get
flutter analyze
flutter test
flutter build web
```

- 测试位于 `test/`，覆盖文本编码回退、RSS 解析、文档包校验、HTML 渲染与 widget。
- 新增服务 / 解码 / 格式逻辑时请补充对应测试。

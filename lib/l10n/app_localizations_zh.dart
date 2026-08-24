// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '墨阅';

  @override
  String get readingTab => '阅读';

  @override
  String get subscriptionsTab => '订阅';

  @override
  String get settingsTab => '设置';

  @override
  String get createOrImport => '新建或导入';

  @override
  String get addSubscription => '添加订阅';

  @override
  String get aboutMoyue => '关于墨阅';

  @override
  String get pressBackAgain => '再按一次返回桌面';

  @override
  String fileImported(String fileName) {
    return '已导入 $fileName';
  }

  @override
  String fileImportFailed(String fileName, String error) {
    return '导入 $fileName 失败：$error';
  }

  @override
  String get unknownError => '未知错误';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSubtitle => '护眼阅读，随你调整';

  @override
  String get searchSettings => '搜索设置';

  @override
  String get displaySection => '显示';

  @override
  String get generalSection => '通用';

  @override
  String get readingSection => '阅读';

  @override
  String get debugSection => '调试';

  @override
  String get noMatchingSettings => '没有匹配的设置';

  @override
  String get appColors => '应用配色';

  @override
  String get monetColors => '莫奈取色';

  @override
  String get customColor => '自定义颜色';

  @override
  String get appColorsDescription =>
      'Android 12 及以上优先读取主屏壁纸公开的主色，并由墨阅生成 Material 配色；关闭后可选择预设颜色，或输入任意十六进制颜色作为软件主题色。';

  @override
  String get useSystemMonet => '使用壁纸莫奈取色';

  @override
  String get monetUnavailable => '当前系统不支持莫奈取色，将使用自定义颜色。';

  @override
  String get customAppColor => '自定义软件颜色';

  @override
  String get hexColor => '十六进制颜色';

  @override
  String get invalidHexColor => '请输入 6 位十六进制颜色，例如 #6D7967';

  @override
  String get nightMode => '夜间模式';

  @override
  String get followSystem => '跟随系统';

  @override
  String get followSystemThemeDescription => '根据系统浅色或深色外观自动切换';

  @override
  String get lightMode => '浅色';

  @override
  String get lightModeDescription => '始终使用纸张浅色外观';

  @override
  String get darkMode => '深色';

  @override
  String get darkModeDescription => '始终使用低亮度夜间外观';

  @override
  String get language => '语言';

  @override
  String get systemPreferredLanguage => '使用系统首选语言';

  @override
  String get chinese => '中文';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get sansSerifFont => '界面字体';

  @override
  String get systemSans => '系统字体';

  @override
  String get claudeStyleSans => '衬线体';

  @override
  String get roundedSans => '无衬线';

  @override
  String get chooseSansSerif => '选择应用界面字体，可切换衬线字形';

  @override
  String get inkMode => '墨模式';

  @override
  String get unavailable => '暂未开放';

  @override
  String get inkModeDescription => '模仿电子墨水屏并减少各类动画的纯粹阅读模式。接口已经预留，当前版本暂未开放。';

  @override
  String get contrast => '对比度';

  @override
  String get contrastDescription => '调整纸张背景与文字、图标之间的明暗差异。数值越高，前景与背景的区分越明显。';

  @override
  String get softwareFontSize => '软件字体大小';

  @override
  String fontSizeDescription(int percent) {
    return '调整墨阅所有页面的界面字号。当前选择 $percent%，应用后需要重启。';
  }

  @override
  String get restartRequired => '需要重启墨阅';

  @override
  String get restartRequiredDescription => '应用新的软件字体大小后，墨阅会立即重启，以确保所有页面同步生效。';

  @override
  String get fontSavedRestartManually => '字号已保存，请手动重新打开墨阅以完全生效';

  @override
  String get reduceMotion => '减少动态效果';

  @override
  String get reduceMotionDescription =>
      '减少页面切换、列表状态变化和部分装饰动画，降低视觉干扰，也可减轻低刷新率设备的刷新压力。';

  @override
  String get enabled => '已开启';

  @override
  String get disabled => '已关闭';

  @override
  String get predictiveBack => '预见性返回';

  @override
  String get standardBack => '普通返回';

  @override
  String get predictiveBackDescription =>
      '在支持的 Android 设备上，返回手势过程中会预览即将返回的页面。若遇到兼容问题，可关闭并使用普通返回行为。';

  @override
  String get webReader => 'Web 阅读器';

  @override
  String get nativeFlutter => '原生 Flutter';

  @override
  String get webReaderDescription =>
      '开启后 HTML 使用系统 WebView 渲染，以获得更完整的网页、CSS 与 JavaScript 兼容性；关闭后使用 Flutter 原生排版。Markdown 始终使用原生渲染。';

  @override
  String get nativeLayoutEngine => '原生排版引擎';

  @override
  String get nativeEngineWebViewDescription =>
      'Markdown 始终使用 Flutter 原生高性能引擎渲染，不依赖 WebView。当前 HTML 已设置为使用网页引擎。';

  @override
  String get nativeEngineAllDescription =>
      'Markdown 与 HTML 当前都使用 Flutter 原生组件排版。Markdown 始终不会依赖 WebView。';

  @override
  String get markdownOnly => 'Markdown';

  @override
  String get markdownAndHtml => 'Markdown 与 HTML';

  @override
  String get fpsDisplay => '帧率显示';

  @override
  String get showing => '显示中';

  @override
  String get hidden => '已隐藏';

  @override
  String get fpsDisplayDescription => '在屏幕右上角显示实时渲染帧率，仅用于调试性能；关闭后不会显示帧率徽标。';

  @override
  String get currentStatus => '当前状态';

  @override
  String viewSettingDescription(String title) {
    return '查看$title说明';
  }

  @override
  String get apply => '应用';

  @override
  String get applyAndRestart => '应用并重启';

  @override
  String get cancel => '取消';

  @override
  String get aboutTagline => '朴素、护眼的 Markdown、HTML 与 RSS 阅读器';

  @override
  String get author => '作者';

  @override
  String get version => '版本';

  @override
  String get versionUnavailable => '无法读取版本信息';

  @override
  String get versionLoading => '正在读取版本信息…';

  @override
  String get closeSearch => '关闭搜索';

  @override
  String get search => '搜索';

  @override
  String get close => '关闭';

  @override
  String get back => '返回';

  @override
  String get renameFolder => '修改文件夹名称';

  @override
  String get newMarkdown => '新建 Markdown';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get importFileOrPackage => '导入文件或文档包';

  @override
  String get supportedFileFormats => '支持的文件格式';

  @override
  String get supportedFiles => '支持的文件';

  @override
  String get supportedFilesDescription =>
      '支持 .md、.html、.zip 和 .moyue。\n\nZIP 或 .moyue 至少需要 2 个文件，并包含 Markdown 或 HTML。包内只允许 HTML、Markdown、CSS、JS、常见图片和视频；文档数量大于 2 时会自动创建文件夹。';

  @override
  String get gotIt => '知道了';

  @override
  String selectedItems(int count) {
    return '已选择 $count 项';
  }

  @override
  String get tapToContinueSelection => '轻点条目可继续选择或取消';

  @override
  String get searchDocuments => '搜索文档';

  @override
  String get shareSelectedItems => '分享所选项目';

  @override
  String get deleteSelectedItems => '删除所选项目';

  @override
  String get libraryTitle => '阅读';

  @override
  String get librarySubtitle => '本地文档，安静阅读';

  @override
  String get documentsSection => '文档';

  @override
  String get moveFailed => '移动失败';

  @override
  String get shareFailed => '分享失败';

  @override
  String deleteItemsQuestion(int count) {
    return '删除 $count 个项目？';
  }

  @override
  String get deleteItemsWarning => '所选文档将从本地数据目录中删除，此操作无法撤销。';

  @override
  String get delete => '删除';

  @override
  String get create => '创建';

  @override
  String get save => '保存';

  @override
  String folderCreateFailed(String error) {
    return '创建文件夹失败：$error';
  }

  @override
  String get documentTextLimit => '文本文档不能超过 8 MB';

  @override
  String get chooseSupportedDocument => '请选择 Markdown、HTML、ZIP 或 .moyue 文件';

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String documentCount(int count) {
    return '$count 个文档';
  }

  @override
  String get emptyDirectory => '这个目录还是空的';

  @override
  String get selectedItemActions => '所选项目操作';

  @override
  String get newOrImportDocument => '新建或导入文档';

  @override
  String get moveTo => '移动到…';

  @override
  String get shareSelectedDocuments => '分享所选文档';

  @override
  String get shareEntireFolder => '分享整个文件夹 (.moyue)';

  @override
  String get noAvailableLocation => '没有可用位置';

  @override
  String get noAvailableLocationDescription => '请先创建另一个文件夹，或选择当前目录之外的位置。';

  @override
  String get moveToTitle => '移动到';

  @override
  String deleteProjectsQuestion(int count) {
    return '删除 $count 个项目？';
  }

  @override
  String get deleteFoldersWarning => '所选文件夹及其中的全部文档和子文件夹都会被删除，此操作无法撤销。';

  @override
  String get deleteDocumentsWarning => '只会删除所选文档，文件夹中的其他内容会保留。';

  @override
  String get renameFolderTitle => '修改文件夹名称';

  @override
  String get folderName => '文件夹名称';

  @override
  String createMarkdownFailed(String error) {
    return '创建 Markdown 失败：$error';
  }

  @override
  String get fileLimit => '文件不能超过 8 MB';

  @override
  String get moreFolders => '更多文件夹';

  @override
  String get dragToDestination => '拖到目标文件夹';

  @override
  String get dragToScroll => '拖到面板底部可自动向下滚动';

  @override
  String get readingHome => '阅读首页';

  @override
  String get noMatchingDocuments => '没有匹配的文档';

  @override
  String get noDocuments => '还没有文档';

  @override
  String get tryAnotherKeyword => '换一个关键词试试';

  @override
  String get createOrImportHint => '新建 Markdown，或从设备导入文件';

  @override
  String get importFile => '导入文件';

  @override
  String get searchSubscriptions => '搜索订阅或文章';

  @override
  String get deleteSelectedSubscriptions => '删除所选订阅';

  @override
  String get subscriptionsTitle => '订阅';

  @override
  String subscriptionCountRefresh(int count) {
    return '$count 个订阅源 · 下拉即可刷新';
  }

  @override
  String get sourcesSection => '订阅源';

  @override
  String get tapToRefresh => '点按单独刷新';

  @override
  String get latestArticles => '最新文章';

  @override
  String get searchResults => '搜索结果';

  @override
  String refreshSourceFailed(String name, String error) {
    return '刷新 $name 失败：$error';
  }

  @override
  String get articleHasNoLink => '这篇文章没有可打开的链接';

  @override
  String addSubscriptionFailed(String error) {
    return '添加订阅失败：$error';
  }

  @override
  String deleteSubscriptionsQuestion(int count) {
    return '删除 $count 个订阅？';
  }

  @override
  String get deleteSubscriptionsWarning => '所选订阅源及已保存的 RSS 文件会一并删除。';

  @override
  String get addRssSubscription => '添加 RSS 订阅';

  @override
  String get subscriptionAddress => '订阅地址';

  @override
  String get optionalName => '名称（可选）';

  @override
  String get invalidHttpsAddress => '请输入完整的 https 订阅地址';

  @override
  String get noMatchingSubscriptions => '没有匹配的订阅';

  @override
  String get noSubscriptions => '还没有订阅';

  @override
  String get subscriptionsTryAnotherKeyword => '换一个关键词试试';

  @override
  String get subscriptionsEmptyHint => '添加订阅后，原始 RSS 会保存在本地';

  @override
  String get readOriginal => '点按阅读原文';

  @override
  String get untitledArticle => '无标题文章';

  @override
  String get unknownTime => '时间未知';

  @override
  String minutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get noMatchingArticles => '没有匹配的文章';

  @override
  String get pullToRefreshSources => '下拉刷新订阅源';

  @override
  String get editMarkdown => '编辑 Markdown';

  @override
  String get documentHasNoHeadings => '当前文档没有标题目录';

  @override
  String get tableOfContents => '目录';

  @override
  String get chooseHeadingToJump => '选择标题以跳转';

  @override
  String shareDocumentFailed(String error) {
    return '分享文档失败：$error';
  }

  @override
  String get decreaseFontSize => '缩小字体';

  @override
  String get increaseFontSize => '放大字体';

  @override
  String get shareDocument => '分享文档';

  @override
  String get shareMarkdown => '分享 Markdown';

  @override
  String get chooseMarkdownShareFormat => '选择分享文件、纯文字或整篇排版图片';

  @override
  String get shareAsFile => '分享 Markdown 文件';

  @override
  String get shareAsText => '分享为纯文字';

  @override
  String get shareAsImage => '分享整篇排版图片';

  @override
  String get cannotCreateShareImage => '无法生成分享图片';

  @override
  String get saving => '正在保存…';

  @override
  String get draftQueued => '草稿已进入恢复队列';

  @override
  String get autoSaved => '已自动保存';

  @override
  String characterCount(int count) {
    return '$count 字';
  }

  @override
  String get preview => '预览';

  @override
  String get continueEditing => '继续编辑';

  @override
  String get insertImageNeedsTitle => '请先填写标题，保存后再插入图片';

  @override
  String get imageLimit => '图片不能超过 8 MB';

  @override
  String get supportedImageTypes => '仅支持 png/jpg/jpeg/gif/webp/bmp 图片';

  @override
  String imageSaved(String path) {
    return '图片已保存到 $path';
  }

  @override
  String insertImageFailed(String error) {
    return '插入图片失败：$error';
  }

  @override
  String get enterDraftTitle => '请先填写文稿标题';

  @override
  String saveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get draftTitle => '文稿标题';

  @override
  String get startWriting => '从这里开始写作…';

  @override
  String get heading => '标题';

  @override
  String get bold => '粗体';

  @override
  String get italic => '斜体';

  @override
  String get quote => '引用';

  @override
  String get list => '列表';

  @override
  String get link => '链接';

  @override
  String get code => '代码';

  @override
  String get image => '图片';

  @override
  String get boldPlaceholder => '重点文字';

  @override
  String get italicPlaceholder => '强调文字';

  @override
  String get linkPlaceholder => '链接文字';

  @override
  String get codePlaceholder => '代码';

  @override
  String get unsupportedWebViewPlatform => '当前平台不支持系统 WebView，请关闭设置中的 Web 阅读器。';

  @override
  String cannotRenderElement(String element) {
    return '无法渲染 $element';
  }

  @override
  String get imageResourceMissing => '图片资源不存在';

  @override
  String get storageSection => '存储';

  @override
  String get clearCache => '清空缓存';

  @override
  String get clearCacheSummary => '不影响文档、订阅和设置';

  @override
  String get clearApplicationData => '清空全部数据';

  @override
  String get clearApplicationDataSummary => '删除文档、订阅及全部设置';

  @override
  String get clearCacheQuestion => '确定清空缓存？';

  @override
  String get clearCacheWarning => '这是危险操作。临时导入文件及缓存会被删除，但文档、订阅和设置会保留。';

  @override
  String get clearApplicationDataQuestion => '确定清空全部数据？';

  @override
  String get clearApplicationDataWarning =>
      '这是不可撤销的危险操作。所有文档、文件夹、RSS 订阅、设置和缓存都会被永久删除，应用随后会关闭。';

  @override
  String get cacheCleared => '缓存已清空';

  @override
  String get storageOperationFailed => '操作失败，请稍后重试';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Moyue';

  @override
  String get readingTab => 'Reading';

  @override
  String get subscriptionsTab => 'Subscriptions';

  @override
  String get settingsTab => 'Settings';

  @override
  String get createOrImport => 'Create or import';

  @override
  String get addSubscription => 'Add subscription';

  @override
  String get aboutMoyue => 'About Moyue';

  @override
  String get pressBackAgain => 'Press back again to exit';

  @override
  String fileImported(String fileName) {
    return 'Imported $fileName';
  }

  @override
  String fileImportFailed(String fileName, String error) {
    return 'Could not import $fileName: $error';
  }

  @override
  String get unknownError => 'Unknown error';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Calm reading, tuned to you';

  @override
  String get searchSettings => 'Search settings';

  @override
  String get displaySection => 'Appearance';

  @override
  String get generalSection => 'General';

  @override
  String get readingSection => 'Reading';

  @override
  String get debugSection => 'Debug';

  @override
  String get noMatchingSettings => 'No matching settings';

  @override
  String get appColors => 'App colors';

  @override
  String get monetColors => 'Monet colors';

  @override
  String get customColor => 'Custom color';

  @override
  String get appColorsDescription =>
      'On Android 12 or later, Moyue reads the home wallpaper\'s public primary color and builds a Material palette from it. Turn this off to choose a preset or enter any hexadecimal app color.';

  @override
  String get useSystemMonet => 'Use wallpaper Monet colors';

  @override
  String get monetUnavailable =>
      'Monet colors are unavailable on this system. A custom color will be used.';

  @override
  String get customAppColor => 'Custom app color';

  @override
  String get hexColor => 'Hex color';

  @override
  String get invalidHexColor => 'Enter a 6-digit hex color, such as #6D7967';

  @override
  String get nightMode => 'Night mode';

  @override
  String get followSystem => 'Follow system';

  @override
  String get followSystemThemeDescription =>
      'Automatically follow the system light or dark appearance';

  @override
  String get lightMode => 'Light';

  @override
  String get lightModeDescription => 'Always use the light paper appearance';

  @override
  String get darkMode => 'Dark';

  @override
  String get darkModeDescription => 'Always use the low-light night appearance';

  @override
  String get language => 'Language';

  @override
  String get systemPreferredLanguage => 'Use the system preferred language';

  @override
  String get chinese => '中文';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get english => 'English';

  @override
  String get sansSerifFont => 'Interface font';

  @override
  String get systemSans => 'System font';

  @override
  String get claudeStyleSans => 'Claude-style serif';

  @override
  String get roundedSans => 'Rounded sans-serif';

  @override
  String get chooseSansSerif =>
      'Choose the app typeface, including a Claude-style serif option';

  @override
  String get inkMode => 'Ink mode';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get inkModeDescription =>
      'An e-ink-inspired reading mode that removes most animation. Its interface is reserved but not available in this version.';

  @override
  String get contrast => 'Contrast';

  @override
  String get contrastDescription =>
      'Adjust the difference between the paper background and foreground text and icons. Higher values make them easier to distinguish.';

  @override
  String get softwareFontSize => 'App font size';

  @override
  String fontSizeDescription(int percent) {
    return 'Adjust the interface text size across Moyue. The current choice is $percent%, and applying it requires a restart.';
  }

  @override
  String get restartRequired => 'Restart Moyue';

  @override
  String get restartRequiredDescription =>
      'Moyue will restart after applying the new app font size so every page updates consistently.';

  @override
  String get fontSavedRestartManually =>
      'Font size saved. Reopen Moyue to apply it everywhere.';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get reduceMotionDescription =>
      'Reduce page transitions, list state animations, and decorative motion to lower visual distraction and refresh pressure on low-refresh displays.';

  @override
  String get enabled => 'On';

  @override
  String get disabled => 'Off';

  @override
  String get predictiveBack => 'Predictive back';

  @override
  String get standardBack => 'Standard back';

  @override
  String get predictiveBackDescription =>
      'Preview the destination while swiping back on supported Android devices. Turn this off to use standard back behavior if compatibility issues occur.';

  @override
  String get webReader => 'Web reader';

  @override
  String get nativeFlutter => 'Native Flutter';

  @override
  String get webReaderDescription =>
      'When enabled, HTML uses the system WebView for broader web, CSS, and JavaScript compatibility. When disabled, HTML uses native Flutter layout. Markdown always remains native.';

  @override
  String get nativeLayoutEngine => 'Native layout engine';

  @override
  String get nativeEngineWebViewDescription =>
      'Markdown always uses Flutter\'s high-performance native engine without WebView. HTML is currently configured to use the web engine.';

  @override
  String get nativeEngineAllDescription =>
      'Markdown and HTML currently use native Flutter widgets. Markdown never depends on WebView.';

  @override
  String get markdownOnly => 'Markdown';

  @override
  String get markdownAndHtml => 'Markdown and HTML';

  @override
  String get fpsDisplay => 'FPS display';

  @override
  String get showing => 'Visible';

  @override
  String get hidden => 'Hidden';

  @override
  String get fpsDisplayDescription =>
      'Show live rendering FPS in the upper-right corner for performance debugging. Turning it off removes the badge.';

  @override
  String get currentStatus => 'Current status';

  @override
  String viewSettingDescription(String title) {
    return 'View $title details';
  }

  @override
  String get apply => 'Apply';

  @override
  String get applyAndRestart => 'Apply and restart';

  @override
  String get cancel => 'Cancel';

  @override
  String get aboutTagline =>
      'A calm, eye-friendly Markdown, HTML, and RSS reader';

  @override
  String get author => 'Author';

  @override
  String get version => 'Version';

  @override
  String get versionUnavailable => 'Could not read version information';

  @override
  String get versionLoading => 'Reading version information…';

  @override
  String get closeSearch => 'Close search';

  @override
  String get search => 'Search';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get newMarkdown => 'New Markdown';

  @override
  String get newFolder => 'New folder';

  @override
  String get importFileOrPackage => 'Import file or document package';

  @override
  String get supportedFileFormats => 'Supported file formats';

  @override
  String get supportedFiles => 'Supported files';

  @override
  String get supportedFilesDescription =>
      'Supports .md, .html, .zip, and .moyue.\n\nZIP or .moyue packages must contain at least 2 files and include Markdown or HTML. Packages may contain only HTML, Markdown, CSS, JavaScript, common images, and videos. A folder is created automatically when there are more than 2 documents.';

  @override
  String get gotIt => 'Got it';

  @override
  String selectedItems(int count) {
    return '$count selected';
  }

  @override
  String get tapToContinueSelection => 'Tap items to select or deselect them';

  @override
  String get searchDocuments => 'Search documents';

  @override
  String get shareSelectedItems => 'Share selected items';

  @override
  String get deleteSelectedItems => 'Delete selected items';

  @override
  String get libraryTitle => 'Reading';

  @override
  String get librarySubtitle => 'Local documents, quiet reading';

  @override
  String get documentsSection => 'Documents';

  @override
  String get moveFailed => 'Move failed';

  @override
  String get shareFailed => 'Share failed';

  @override
  String deleteItemsQuestion(int count) {
    return 'Delete $count items?';
  }

  @override
  String get deleteItemsWarning =>
      'The selected documents will be removed from local storage. This cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String folderCreateFailed(String error) {
    return 'Could not create folder: $error';
  }

  @override
  String get documentTextLimit => 'Text documents cannot exceed 8 MB';

  @override
  String get chooseSupportedDocument =>
      'Choose a Markdown, HTML, ZIP, or .moyue file';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
      zero: 'No documents',
    );
    return '$_temp0';
  }

  @override
  String get emptyDirectory => 'This folder is empty';

  @override
  String get selectedItemActions => 'Selected item actions';

  @override
  String get newOrImportDocument => 'Create or import a document';

  @override
  String get moveTo => 'Move to…';

  @override
  String get shareSelectedDocuments => 'Share selected documents';

  @override
  String get shareEntireFolder => 'Share entire folder (.moyue)';

  @override
  String get noAvailableLocation => 'No available location';

  @override
  String get noAvailableLocationDescription =>
      'Create another folder first, or choose a location outside the current folder.';

  @override
  String get moveToTitle => 'Move to';

  @override
  String deleteProjectsQuestion(int count) {
    return 'Delete $count items?';
  }

  @override
  String get deleteFoldersWarning =>
      'Selected folders and all documents and subfolders inside them will be deleted. This cannot be undone.';

  @override
  String get deleteDocumentsWarning =>
      'Only selected documents will be deleted. Other folder content will remain.';

  @override
  String get renameFolderTitle => 'Rename folder';

  @override
  String get folderName => 'Folder name';

  @override
  String createMarkdownFailed(String error) {
    return 'Could not create Markdown: $error';
  }

  @override
  String get fileLimit => 'Files cannot exceed 8 MB';

  @override
  String get moreFolders => 'More folders';

  @override
  String get dragToDestination => 'Drag to a destination folder';

  @override
  String get dragToScroll => 'Drag to the bottom to scroll automatically';

  @override
  String get readingHome => 'Reading home';

  @override
  String get noMatchingDocuments => 'No matching documents';

  @override
  String get noDocuments => 'No documents yet';

  @override
  String get tryAnotherKeyword => 'Try another keyword';

  @override
  String get createOrImportHint =>
      'Create Markdown or import a file from your device';

  @override
  String get importFile => 'Import file';

  @override
  String get searchSubscriptions => 'Search subscriptions or articles';

  @override
  String get deleteSelectedSubscriptions => 'Delete selected subscriptions';

  @override
  String get subscriptionsTitle => 'Subscriptions';

  @override
  String subscriptionCountRefresh(int count) {
    return '$count sources · pull to refresh';
  }

  @override
  String get sourcesSection => 'Sources';

  @override
  String get tapToRefresh => 'Tap to refresh one source';

  @override
  String get latestArticles => 'Latest articles';

  @override
  String get searchResults => 'Search results';

  @override
  String refreshSourceFailed(String name, String error) {
    return 'Could not refresh $name: $error';
  }

  @override
  String get articleHasNoLink => 'This article has no link to open';

  @override
  String addSubscriptionFailed(String error) {
    return 'Could not add subscription: $error';
  }

  @override
  String deleteSubscriptionsQuestion(int count) {
    return 'Delete $count subscriptions?';
  }

  @override
  String get deleteSubscriptionsWarning =>
      'Selected sources and their saved RSS files will be deleted.';

  @override
  String get addRssSubscription => 'Add RSS subscription';

  @override
  String get subscriptionAddress => 'Subscription URL';

  @override
  String get optionalName => 'Name (optional)';

  @override
  String get invalidHttpsAddress => 'Enter a complete HTTPS subscription URL';

  @override
  String get noMatchingSubscriptions => 'No matching subscriptions';

  @override
  String get noSubscriptions => 'No subscriptions yet';

  @override
  String get subscriptionsTryAnotherKeyword => 'Try another keyword';

  @override
  String get subscriptionsEmptyHint =>
      'Original RSS files are saved locally after you subscribe';

  @override
  String get readOriginal => 'Tap to read the original';

  @override
  String get untitledArticle => 'Untitled article';

  @override
  String get unknownTime => 'Unknown time';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count hr ago';
  }

  @override
  String daysAgo(int count) {
    return '$count d ago';
  }

  @override
  String get noMatchingArticles => 'No matching articles';

  @override
  String get pullToRefreshSources => 'Pull to refresh subscriptions';

  @override
  String get editMarkdown => 'Edit Markdown';

  @override
  String get documentHasNoHeadings => 'This document has no heading outline';

  @override
  String get tableOfContents => 'Table of contents';

  @override
  String get chooseHeadingToJump => 'Choose a heading to jump to it';

  @override
  String shareDocumentFailed(String error) {
    return 'Could not share document: $error';
  }

  @override
  String get decreaseFontSize => 'Decrease font size';

  @override
  String get increaseFontSize => 'Increase font size';

  @override
  String get shareDocument => 'Share document';

  @override
  String get shareMarkdown => 'Share Markdown';

  @override
  String get chooseMarkdownShareFormat =>
      'Share the file, plain text, or one image of the complete rendered document';

  @override
  String get shareAsFile => 'Share Markdown file';

  @override
  String get shareAsText => 'Share as plain text';

  @override
  String get shareAsImage => 'Share full rendered document as image';

  @override
  String get cannotCreateShareImage => 'Could not create the share image';

  @override
  String get saving => 'Saving…';

  @override
  String get draftQueued => 'Draft added to the recovery queue';

  @override
  String get autoSaved => 'Autosaved';

  @override
  String characterCount(int count) {
    return '$count characters';
  }

  @override
  String get preview => 'Preview';

  @override
  String get continueEditing => 'Continue editing';

  @override
  String get insertImageNeedsTitle =>
      'Enter and save a title before inserting an image';

  @override
  String get imageLimit => 'Images cannot exceed 8 MB';

  @override
  String get supportedImageTypes =>
      'Only png, jpg, jpeg, gif, webp, and bmp images are supported';

  @override
  String imageSaved(String path) {
    return 'Image saved to $path';
  }

  @override
  String get imageImportSucceeded => 'Image imported';

  @override
  String get imageImportFailed => 'Could not import image';

  @override
  String insertImageFailed(String error) {
    return 'Could not insert image: $error';
  }

  @override
  String get enterDraftTitle => 'Enter a title first';

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get draftTitle => 'Draft title';

  @override
  String get startWriting => 'Start writing here…';

  @override
  String get heading => 'Heading';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get quote => 'Quote';

  @override
  String get list => 'List';

  @override
  String get link => 'Link';

  @override
  String get code => 'Code';

  @override
  String get image => 'Image';

  @override
  String get boldPlaceholder => 'important text';

  @override
  String get italicPlaceholder => 'emphasized text';

  @override
  String get linkPlaceholder => 'link text';

  @override
  String get codePlaceholder => 'code';

  @override
  String get unsupportedWebViewPlatform =>
      'System WebView is unavailable on this platform. Turn off the Web reader in Settings.';

  @override
  String cannotRenderElement(String element) {
    return 'Could not render $element';
  }

  @override
  String get imageResourceMissing => 'Image resource not found';

  @override
  String get storageSection => 'Storage';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearCacheSummary =>
      'Keeps documents, subscriptions, and settings';

  @override
  String get clearApplicationData => 'Clear all data';

  @override
  String get clearApplicationDataSummary =>
      'Deletes documents, subscriptions, and settings';

  @override
  String get clearCacheQuestion => 'Clear the cache?';

  @override
  String get clearCacheWarning =>
      'This is a dangerous operation. Temporary imports and cached files will be deleted; documents, subscriptions, and settings will remain.';

  @override
  String get clearApplicationDataQuestion => 'Clear all application data?';

  @override
  String get clearApplicationDataWarning =>
      'This dangerous operation cannot be undone. All documents, folders, RSS subscriptions, settings, and caches will be permanently deleted, and the app will close.';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get storageOperationFailed => 'The operation failed. Try again later.';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The localized application name
  ///
  /// In en, this message translates to:
  /// **'Moyue'**
  String get appName;

  /// No description provided for @readingTab.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get readingTab;

  /// No description provided for @subscriptionsTab.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptionsTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @createOrImport.
  ///
  /// In en, this message translates to:
  /// **'Create or import'**
  String get createOrImport;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscription;

  /// No description provided for @aboutMoyue.
  ///
  /// In en, this message translates to:
  /// **'About Moyue'**
  String get aboutMoyue;

  /// No description provided for @pressBackAgain.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressBackAgain;

  /// No description provided for @fileImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {fileName}'**
  String fileImported(String fileName);

  /// No description provided for @fileImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import {fileName}: {error}'**
  String fileImportFailed(String fileName, String error);

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paper, type, and reading—your way'**
  String get settingsSubtitle;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get searchSettings;

  /// No description provided for @displaySection.
  ///
  /// In en, this message translates to:
  /// **'Appearance & paper'**
  String get displaySection;

  /// No description provided for @typographySection.
  ///
  /// In en, this message translates to:
  /// **'Type & size'**
  String get typographySection;

  /// No description provided for @generalSection.
  ///
  /// In en, this message translates to:
  /// **'Interaction & language'**
  String get generalSection;

  /// No description provided for @readingSection.
  ///
  /// In en, this message translates to:
  /// **'Reading & content'**
  String get readingSection;

  /// No description provided for @debugSection.
  ///
  /// In en, this message translates to:
  /// **'Developer & diagnostics'**
  String get debugSection;

  /// No description provided for @noMatchingSettings.
  ///
  /// In en, this message translates to:
  /// **'No matching settings'**
  String get noMatchingSettings;

  /// No description provided for @appColors.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get appColors;

  /// No description provided for @monetColors.
  ///
  /// In en, this message translates to:
  /// **'Monet colors'**
  String get monetColors;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get customColor;

  /// No description provided for @appColorsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the accent for buttons, selections, and notices. Supported Android devices can follow the wallpaper; otherwise use a preset or the color picker.'**
  String get appColorsDescription;

  /// No description provided for @useSystemMonet.
  ///
  /// In en, this message translates to:
  /// **'Use wallpaper Monet colors'**
  String get useSystemMonet;

  /// No description provided for @monetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Monet colors are unavailable on this system. A custom color will be used.'**
  String get monetUnavailable;

  /// No description provided for @customAppColor.
  ///
  /// In en, this message translates to:
  /// **'Custom app color'**
  String get customAppColor;

  /// No description provided for @hexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get hexColor;

  /// No description provided for @invalidHexColor.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit hex color, such as #C3C6B8'**
  String get invalidHexColor;

  /// No description provided for @nightMode.
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get nightMode;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @followSystemThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically follow the system light or dark appearance'**
  String get followSystemThemeDescription;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @lightModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Always use the light paper appearance'**
  String get lightModeDescription;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @darkModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Always use the low-light night appearance'**
  String get darkModeDescription;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemPreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use the system preferred language'**
  String get systemPreferredLanguage;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get simplifiedChinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @sansSerifFont.
  ///
  /// In en, this message translates to:
  /// **'Font style'**
  String get sansSerifFont;

  /// No description provided for @systemSans.
  ///
  /// In en, this message translates to:
  /// **'System font'**
  String get systemSans;

  /// No description provided for @claudeStyleSans.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get claudeStyleSans;

  /// No description provided for @roundedSans.
  ///
  /// In en, this message translates to:
  /// **'Rounded sans-serif'**
  String get roundedSans;

  /// No description provided for @chooseSansSerif.
  ///
  /// In en, this message translates to:
  /// **'Choose Moyue\'s global font style'**
  String get chooseSansSerif;

  /// No description provided for @systemFontDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow the system typeface for the best compatibility'**
  String get systemFontDescription;

  /// No description provided for @serifFontDescription.
  ///
  /// In en, this message translates to:
  /// **'A more expressive and aesthetically refined bookish serif typeface'**
  String get serifFontDescription;

  /// No description provided for @roundedFontDescription.
  ///
  /// In en, this message translates to:
  /// **'A soft, modern rounded sans-serif typeface'**
  String get roundedFontDescription;

  /// No description provided for @inkMode.
  ///
  /// In en, this message translates to:
  /// **'Ink mode'**
  String get inkMode;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @inkModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use a green e-paper palette, system serif type, and reduced motion. Switching requires a restart; your font and color preferences are preserved.'**
  String get inkModeDescription;

  /// No description provided for @inkModeRestartDescription.
  ///
  /// In en, this message translates to:
  /// **'Switching ink mode restarts Moyue. Your font, size, color, and reader-style preferences are preserved and return when ink mode is disabled.'**
  String get inkModeRestartDescription;

  /// No description provided for @inkModeSavedRestartManually.
  ///
  /// In en, this message translates to:
  /// **'Ink mode was saved. Reopen Moyue to apply it everywhere.'**
  String get inkModeSavedRestartManually;

  /// No description provided for @managedByInkMode.
  ///
  /// In en, this message translates to:
  /// **'Managed by ink mode'**
  String get managedByInkMode;

  /// No description provided for @managedByInkModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Ink mode is using its dedicated green display palette, system serif typeface, fixed size, and reader style. Your saved choices remain intact and return after ink mode is disabled.'**
  String get managedByInkModeDescription;

  /// No description provided for @inkTypeface.
  ///
  /// In en, this message translates to:
  /// **'System serif'**
  String get inkTypeface;

  /// No description provided for @inkPaperPalette.
  ///
  /// In en, this message translates to:
  /// **'16-level ink palette'**
  String get inkPaperPalette;

  /// No description provided for @inkReaderStyle.
  ///
  /// In en, this message translates to:
  /// **'Ink reader style'**
  String get inkReaderStyle;

  /// No description provided for @softwareFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get softwareFontSize;

  /// No description provided for @fontSizeDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust the interface text size across Moyue. The current choice is {percent}%, and applying it requires a restart.'**
  String fontSizeDescription(int percent);

  /// No description provided for @fontSizeOptionDescription.
  ///
  /// In en, this message translates to:
  /// **'{percent}% global interface text; applying it requires a restart'**
  String fontSizeOptionDescription(int percent);

  /// No description provided for @restartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart Moyue'**
  String get restartRequired;

  /// No description provided for @restartRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'Moyue will restart after applying the new app font size so every page updates consistently.'**
  String get restartRequiredDescription;

  /// No description provided for @fontSavedRestartManually.
  ///
  /// In en, this message translates to:
  /// **'Font size saved. Reopen Moyue to apply it everywhere.'**
  String get fontSavedRestartManually;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// No description provided for @reduceMotionDescription.
  ///
  /// In en, this message translates to:
  /// **'Reduce page transitions, sheet animations, and decorative motion for a calmer interface without changing how reading or controls work.'**
  String get reduceMotionDescription;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get disabled;

  /// No description provided for @predictiveBack.
  ///
  /// In en, this message translates to:
  /// **'Predictive back'**
  String get predictiveBack;

  /// No description provided for @standardBack.
  ///
  /// In en, this message translates to:
  /// **'Standard back'**
  String get standardBack;

  /// No description provided for @predictiveBackDescription.
  ///
  /// In en, this message translates to:
  /// **'Preview the destination while swiping back on supported Android devices. Turn this off to use standard back behavior if compatibility issues occur.'**
  String get predictiveBackDescription;

  /// No description provided for @webReader.
  ///
  /// In en, this message translates to:
  /// **'HTML web engine'**
  String get webReader;

  /// No description provided for @nativeFlutter.
  ///
  /// In en, this message translates to:
  /// **'Native Flutter'**
  String get nativeFlutter;

  /// No description provided for @webReaderDescription.
  ///
  /// In en, this message translates to:
  /// **'Use system WebView for HTML with complex styling or scripts. Turn off for native layout. Markdown always uses the native renderer.'**
  String get webReaderDescription;

  /// No description provided for @nativeLayoutEngine.
  ///
  /// In en, this message translates to:
  /// **'Native layout engine'**
  String get nativeLayoutEngine;

  /// No description provided for @nativeEngineWebViewDescription.
  ///
  /// In en, this message translates to:
  /// **'Markdown always uses Flutter\'s high-performance native engine without WebView. HTML is currently configured to use the web engine.'**
  String get nativeEngineWebViewDescription;

  /// No description provided for @nativeEngineAllDescription.
  ///
  /// In en, this message translates to:
  /// **'Markdown and HTML currently use native Flutter widgets. Markdown never depends on WebView.'**
  String get nativeEngineAllDescription;

  /// No description provided for @markdownOnly.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get markdownOnly;

  /// No description provided for @markdownAndHtml.
  ///
  /// In en, this message translates to:
  /// **'Markdown and HTML'**
  String get markdownAndHtml;

  /// No description provided for @markdownRenderingMode.
  ///
  /// In en, this message translates to:
  /// **'Loading & selection'**
  String get markdownRenderingMode;

  /// No description provided for @segmentedRendering.
  ///
  /// In en, this message translates to:
  /// **'Segmented rendering'**
  String get segmentedRendering;

  /// No description provided for @segmentedRenderingDescription.
  ///
  /// In en, this message translates to:
  /// **'Build content in viewport-sized segments for smoother long-document scrolling and lower memory use. Select all only covers content that has already been built.'**
  String get segmentedRenderingDescription;

  /// No description provided for @wholeDocumentRendering.
  ///
  /// In en, this message translates to:
  /// **'Whole-document rendering'**
  String get wholeDocumentRendering;

  /// No description provided for @wholeDocumentRenderingDescription.
  ///
  /// In en, this message translates to:
  /// **'Build the entire document at once so selection and copy can span off-screen paragraphs. Very long documents use more memory.'**
  String get wholeDocumentRenderingDescription;

  /// No description provided for @markdownRenderingStyle.
  ///
  /// In en, this message translates to:
  /// **'Text color theme'**
  String get markdownRenderingStyle;

  /// No description provided for @moyueAdaptiveMarkdownTheme.
  ///
  /// In en, this message translates to:
  /// **'Moyue adaptive'**
  String get moyueAdaptiveMarkdownTheme;

  /// No description provided for @moyueAdaptiveMarkdownThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow the app appearance and active color scheme for a unified reading surface'**
  String get moyueAdaptiveMarkdownThemeDescription;

  /// No description provided for @warmPaperMarkdownTheme.
  ///
  /// In en, this message translates to:
  /// **'Warm paper'**
  String get warmPaperMarkdownTheme;

  /// No description provided for @warmPaperMarkdownThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'A low-glare warm paper surface with brown-black body text'**
  String get warmPaperMarkdownThemeDescription;

  /// No description provided for @githubLightMarkdownThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'A clear and restrained light technical-document palette'**
  String get githubLightMarkdownThemeDescription;

  /// No description provided for @githubDarkMarkdownThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'A low-luminance dark surface with crisp blue links'**
  String get githubDarkMarkdownThemeDescription;

  /// No description provided for @solarizedLightMarkdownThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'The classic warm Solarized light reading palette'**
  String get solarizedLightMarkdownThemeDescription;

  /// No description provided for @solarizedDarkMarkdownThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'The classic deep-cyan, low-contrast Solarized dark palette'**
  String get solarizedDarkMarkdownThemeDescription;

  /// No description provided for @codeBlockAppearance.
  ///
  /// In en, this message translates to:
  /// **'Code color theme'**
  String get codeBlockAppearance;

  /// No description provided for @vscodeAutomaticTheme.
  ///
  /// In en, this message translates to:
  /// **'VS Code automatic'**
  String get vscodeAutomaticTheme;

  /// No description provided for @vscodeAutomaticThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use VS Code Light+ or Dark+ with the app appearance'**
  String get vscodeAutomaticThemeDescription;

  /// No description provided for @vscodeLightThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Classic light VS Code syntax highlighting'**
  String get vscodeLightThemeDescription;

  /// No description provided for @vscodeDarkThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Classic dark VS Code syntax highlighting'**
  String get vscodeDarkThemeDescription;

  /// No description provided for @vscodeModernThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Modern token colors from the VS Code Modern family'**
  String get vscodeModernThemeDescription;

  /// No description provided for @monokaiThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'The highly recognizable dark Monokai token palette'**
  String get monokaiThemeDescription;

  /// No description provided for @monokaiDimmedThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'A lower-luminance, less intense Monokai variant'**
  String get monokaiDimmedThemeDescription;

  /// No description provided for @solarizedCodeThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Low-contrast, eye-friendly Solarized syntax colors'**
  String get solarizedCodeThemeDescription;

  /// No description provided for @kimbieThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Dark syntax highlighting built on warm brown tones'**
  String get kimbieThemeDescription;

  /// No description provided for @tomorrowThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Classic high-contrast tokens on a deep blue surface'**
  String get tomorrowThemeDescription;

  /// No description provided for @highContrastCodeThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Strong token-to-background separation for accessibility'**
  String get highContrastCodeThemeDescription;

  /// No description provided for @communityCodeThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'The {themeName} syntax palette from the editor theme ecosystem'**
  String communityCodeThemeDescription(String themeName);

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get codeCopied;

  /// No description provided for @plainTextCode.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get plainTextCode;

  /// No description provided for @codeLineCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String codeLineCount(int count);

  /// No description provided for @fpsDisplay.
  ///
  /// In en, this message translates to:
  /// **'FPS display'**
  String get fpsDisplay;

  /// No description provided for @showing.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get showing;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @fpsDisplayDescription.
  ///
  /// In en, this message translates to:
  /// **'Show live rendering FPS in the upper-right corner for performance debugging. Turning it off removes the badge.'**
  String get fpsDisplayDescription;

  /// No description provided for @currentStatus.
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get currentStatus;

  /// No description provided for @viewSettingDescription.
  ///
  /// In en, this message translates to:
  /// **'View {title} details'**
  String viewSettingDescription(String title);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @applyAndRestart.
  ///
  /// In en, this message translates to:
  /// **'Apply and restart'**
  String get applyAndRestart;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A calm, eye-friendly Markdown, HTML, and RSS reader'**
  String get aboutTagline;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @versionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not read version information'**
  String get versionUnavailable;

  /// No description provided for @versionLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading version information…'**
  String get versionLoading;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @renameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameFolder;

  /// No description provided for @newMarkdown.
  ///
  /// In en, this message translates to:
  /// **'New Markdown'**
  String get newMarkdown;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @importFileOrPackage.
  ///
  /// In en, this message translates to:
  /// **'Import file or document package'**
  String get importFileOrPackage;

  /// No description provided for @supportedFileFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported file formats'**
  String get supportedFileFormats;

  /// No description provided for @supportedFiles.
  ///
  /// In en, this message translates to:
  /// **'Supported files'**
  String get supportedFiles;

  /// No description provided for @supportedFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Supports md, html, htm, zip, and moyue.\nPackages need 2+ files, including a document; styles, scripts, images, and videos are allowed. More than 2 documents creates a folder.'**
  String get supportedFilesDescription;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @selectedItems.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedItems(int count);

  /// No description provided for @tapToContinueSelection.
  ///
  /// In en, this message translates to:
  /// **'Tap items to select or deselect them'**
  String get tapToContinueSelection;

  /// No description provided for @searchDocuments.
  ///
  /// In en, this message translates to:
  /// **'Search documents'**
  String get searchDocuments;

  /// No description provided for @shareSelectedItems.
  ///
  /// In en, this message translates to:
  /// **'Share selected items'**
  String get shareSelectedItems;

  /// No description provided for @deleteSelectedItems.
  ///
  /// In en, this message translates to:
  /// **'Delete selected items'**
  String get deleteSelectedItems;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get libraryTitle;

  /// No description provided for @librarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local documents, quiet reading'**
  String get librarySubtitle;

  /// No description provided for @documentsSection.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsSection;

  /// No description provided for @moveFailed.
  ///
  /// In en, this message translates to:
  /// **'Move failed'**
  String get moveFailed;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed'**
  String get shareFailed;

  /// No description provided for @deleteItemsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items?'**
  String deleteItemsQuestion(int count);

  /// No description provided for @deleteItemsWarning.
  ///
  /// In en, this message translates to:
  /// **'The selected documents will be removed from local storage. This cannot be undone.'**
  String get deleteItemsWarning;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @folderCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create folder: {error}'**
  String folderCreateFailed(String error);

  /// No description provided for @documentTextLimit.
  ///
  /// In en, this message translates to:
  /// **'Text documents cannot exceed 8 MB'**
  String get documentTextLimit;

  /// No description provided for @chooseSupportedDocument.
  ///
  /// In en, this message translates to:
  /// **'Choose a .zip, .moyue, .md, .html, or .htm file'**
  String get chooseSupportedDocument;

  /// No description provided for @unsupportedImportFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file'**
  String get unsupportedImportFileTitle;

  /// No description provided for @unsupportedImportFileDescription.
  ///
  /// In en, this message translates to:
  /// **'Cannot import \"{fileName}\". Only .zip, .moyue, .md, .html, and .htm files are supported.'**
  String unsupportedImportFileDescription(String fileName);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @documentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No documents} =1{1 document} other{{count} documents}}'**
  String documentCount(int count);

  /// No description provided for @emptyDirectory.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get emptyDirectory;

  /// No description provided for @selectedItemActions.
  ///
  /// In en, this message translates to:
  /// **'Selected item actions'**
  String get selectedItemActions;

  /// No description provided for @newOrImportDocument.
  ///
  /// In en, this message translates to:
  /// **'Create or import a document'**
  String get newOrImportDocument;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get moveTo;

  /// No description provided for @shareSelectedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Share selected documents'**
  String get shareSelectedDocuments;

  /// No description provided for @shareEntireFolder.
  ///
  /// In en, this message translates to:
  /// **'Share entire folder (.moyue)'**
  String get shareEntireFolder;

  /// No description provided for @noAvailableLocation.
  ///
  /// In en, this message translates to:
  /// **'No available location'**
  String get noAvailableLocation;

  /// No description provided for @noAvailableLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Create another folder first, or choose a location outside the current folder.'**
  String get noAvailableLocationDescription;

  /// No description provided for @moveToTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get moveToTitle;

  /// No description provided for @deleteProjectsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items?'**
  String deleteProjectsQuestion(int count);

  /// No description provided for @deleteFoldersWarning.
  ///
  /// In en, this message translates to:
  /// **'Selected folders and all documents and subfolders inside them will be deleted. This cannot be undone.'**
  String get deleteFoldersWarning;

  /// No description provided for @deleteDocumentsWarning.
  ///
  /// In en, this message translates to:
  /// **'Only selected documents will be deleted. Other folder content will remain.'**
  String get deleteDocumentsWarning;

  /// No description provided for @renameFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameFolderTitle;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @createMarkdownFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create Markdown: {error}'**
  String createMarkdownFailed(String error);

  /// No description provided for @fileLimit.
  ///
  /// In en, this message translates to:
  /// **'Files cannot exceed 8 MB'**
  String get fileLimit;

  /// No description provided for @moreFolders.
  ///
  /// In en, this message translates to:
  /// **'More folders'**
  String get moreFolders;

  /// No description provided for @dragToDestination.
  ///
  /// In en, this message translates to:
  /// **'Drag to a destination folder'**
  String get dragToDestination;

  /// No description provided for @dragToScroll.
  ///
  /// In en, this message translates to:
  /// **'Drag to the bottom to scroll automatically'**
  String get dragToScroll;

  /// No description provided for @readingHome.
  ///
  /// In en, this message translates to:
  /// **'Reading home'**
  String get readingHome;

  /// No description provided for @noMatchingDocuments.
  ///
  /// In en, this message translates to:
  /// **'No matching documents'**
  String get noMatchingDocuments;

  /// No description provided for @noDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get noDocuments;

  /// No description provided for @tryAnotherKeyword.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword'**
  String get tryAnotherKeyword;

  /// No description provided for @createOrImportHint.
  ///
  /// In en, this message translates to:
  /// **'Create Markdown or import a file from your device'**
  String get createOrImportHint;

  /// No description provided for @importFile.
  ///
  /// In en, this message translates to:
  /// **'Import file'**
  String get importFile;

  /// No description provided for @searchSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Search subscriptions or articles'**
  String get searchSubscriptions;

  /// No description provided for @deleteSelectedSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Delete selected subscriptions'**
  String get deleteSelectedSubscriptions;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptionsTitle;

  /// No description provided for @subscriptionCountRefresh.
  ///
  /// In en, this message translates to:
  /// **'{count} sources · pull to refresh'**
  String subscriptionCountRefresh(int count);

  /// No description provided for @sourcesSection.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesSection;

  /// No description provided for @tapToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Tap to refresh one source'**
  String get tapToRefresh;

  /// No description provided for @latestArticles.
  ///
  /// In en, this message translates to:
  /// **'Latest articles'**
  String get latestArticles;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get searchResults;

  /// No description provided for @refreshSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh {name}: {error}'**
  String refreshSourceFailed(String name, String error);

  /// No description provided for @articleHasNoLink.
  ///
  /// In en, this message translates to:
  /// **'This article has no link to open'**
  String get articleHasNoLink;

  /// No description provided for @addSubscriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add subscription: {error}'**
  String addSubscriptionFailed(String error);

  /// No description provided for @deleteSubscriptionsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} subscriptions?'**
  String deleteSubscriptionsQuestion(int count);

  /// No description provided for @deleteSubscriptionsWarning.
  ///
  /// In en, this message translates to:
  /// **'Selected sources and their saved RSS files will be deleted.'**
  String get deleteSubscriptionsWarning;

  /// No description provided for @addRssSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add RSS subscription'**
  String get addRssSubscription;

  /// No description provided for @subscriptionAddress.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get subscriptionAddress;

  /// No description provided for @optionalName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get optionalName;

  /// No description provided for @invalidHttpsAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a complete HTTPS subscription URL'**
  String get invalidHttpsAddress;

  /// No description provided for @noMatchingSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'No matching subscriptions'**
  String get noMatchingSubscriptions;

  /// No description provided for @noSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet'**
  String get noSubscriptions;

  /// No description provided for @subscriptionsTryAnotherKeyword.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword'**
  String get subscriptionsTryAnotherKeyword;

  /// No description provided for @subscriptionsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Original RSS files are saved locally after you subscribe'**
  String get subscriptionsEmptyHint;

  /// No description provided for @readOriginal.
  ///
  /// In en, this message translates to:
  /// **'Tap to read the original'**
  String get readOriginal;

  /// No description provided for @untitledArticle.
  ///
  /// In en, this message translates to:
  /// **'Untitled article'**
  String get untitledArticle;

  /// No description provided for @unknownTime.
  ///
  /// In en, this message translates to:
  /// **'Unknown time'**
  String get unknownTime;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hr ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String daysAgo(int count);

  /// No description provided for @noMatchingArticles.
  ///
  /// In en, this message translates to:
  /// **'No matching articles'**
  String get noMatchingArticles;

  /// No description provided for @pullToRefreshSources.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh subscriptions'**
  String get pullToRefreshSources;

  /// No description provided for @editMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Edit Markdown'**
  String get editMarkdown;

  /// No description provided for @documentHasNoHeadings.
  ///
  /// In en, this message translates to:
  /// **'This document has no heading outline'**
  String get documentHasNoHeadings;

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of contents'**
  String get tableOfContents;

  /// No description provided for @chooseHeadingToJump.
  ///
  /// In en, this message translates to:
  /// **'Choose a heading to jump to it'**
  String get chooseHeadingToJump;

  /// No description provided for @shareDocumentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share document: {error}'**
  String shareDocumentFailed(String error);

  /// No description provided for @decreaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get decreaseFontSize;

  /// No description provided for @increaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get increaseFontSize;

  /// No description provided for @shareDocument.
  ///
  /// In en, this message translates to:
  /// **'Share document'**
  String get shareDocument;

  /// No description provided for @shareMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Share Markdown'**
  String get shareMarkdown;

  /// No description provided for @chooseMarkdownShareFormat.
  ///
  /// In en, this message translates to:
  /// **'Share the file, plain text, or one image of the complete rendered document'**
  String get chooseMarkdownShareFormat;

  /// No description provided for @shareAsFile.
  ///
  /// In en, this message translates to:
  /// **'Share Markdown file'**
  String get shareAsFile;

  /// No description provided for @shareAsText.
  ///
  /// In en, this message translates to:
  /// **'Share as plain text'**
  String get shareAsText;

  /// No description provided for @shareAsImage.
  ///
  /// In en, this message translates to:
  /// **'Share full rendered document as image'**
  String get shareAsImage;

  /// No description provided for @cannotCreateShareImage.
  ///
  /// In en, this message translates to:
  /// **'Could not create the share image'**
  String get cannotCreateShareImage;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @draftQueued.
  ///
  /// In en, this message translates to:
  /// **'Draft added to the recovery queue'**
  String get draftQueued;

  /// No description provided for @autoSaved.
  ///
  /// In en, this message translates to:
  /// **'Autosaved'**
  String get autoSaved;

  /// No description provided for @characterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String characterCount(int count);

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get continueEditing;

  /// No description provided for @insertImageNeedsTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter and save a title before inserting an image'**
  String get insertImageNeedsTitle;

  /// No description provided for @imageLimit.
  ///
  /// In en, this message translates to:
  /// **'Images cannot exceed 8 MB'**
  String get imageLimit;

  /// No description provided for @supportedImageTypes.
  ///
  /// In en, this message translates to:
  /// **'Only png, jpg, jpeg, gif, webp, and bmp images are supported'**
  String get supportedImageTypes;

  /// No description provided for @imageSaved.
  ///
  /// In en, this message translates to:
  /// **'Image saved to {path}'**
  String imageSaved(String path);

  /// No description provided for @imageImportSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Image imported'**
  String get imageImportSucceeded;

  /// No description provided for @imageImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import image'**
  String get imageImportFailed;

  /// No description provided for @insertImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not insert image: {error}'**
  String insertImageFailed(String error);

  /// No description provided for @enterDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title first'**
  String get enterDraftTitle;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @draftTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft title'**
  String get draftTitle;

  /// No description provided for @startWriting.
  ///
  /// In en, this message translates to:
  /// **'Start writing here…'**
  String get startWriting;

  /// No description provided for @heading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get heading;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @quote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quote;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @boldPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'important text'**
  String get boldPlaceholder;

  /// No description provided for @italicPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'emphasized text'**
  String get italicPlaceholder;

  /// No description provided for @linkPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'link text'**
  String get linkPlaceholder;

  /// No description provided for @codePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'code'**
  String get codePlaceholder;

  /// No description provided for @unsupportedWebViewPlatform.
  ///
  /// In en, this message translates to:
  /// **'System WebView is unavailable on this platform. Turn off the Web reader in Settings.'**
  String get unsupportedWebViewPlatform;

  /// No description provided for @cannotRenderElement.
  ///
  /// In en, this message translates to:
  /// **'Could not render {element}'**
  String cannotRenderElement(String element);

  /// No description provided for @imageResourceMissing.
  ///
  /// In en, this message translates to:
  /// **'Image resource not found'**
  String get imageResourceMissing;

  /// No description provided for @referencedResourceMissing.
  ///
  /// In en, this message translates to:
  /// **'The referenced resource is missing'**
  String get referencedResourceMissing;

  /// No description provided for @storageSection.
  ///
  /// In en, this message translates to:
  /// **'Data & storage'**
  String get storageSection;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCacheSummary.
  ///
  /// In en, this message translates to:
  /// **'Keeps documents, subscriptions, and settings'**
  String get clearCacheSummary;

  /// No description provided for @clearApplicationData.
  ///
  /// In en, this message translates to:
  /// **'Clear all data'**
  String get clearApplicationData;

  /// No description provided for @clearApplicationDataSummary.
  ///
  /// In en, this message translates to:
  /// **'Deletes documents, subscriptions, and settings'**
  String get clearApplicationDataSummary;

  /// No description provided for @clearCacheQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear the cache?'**
  String get clearCacheQuestion;

  /// No description provided for @clearCacheWarning.
  ///
  /// In en, this message translates to:
  /// **'This is a dangerous operation. Temporary imports and cached files will be deleted; documents, subscriptions, and settings will remain.'**
  String get clearCacheWarning;

  /// No description provided for @clearApplicationDataQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear all application data?'**
  String get clearApplicationDataQuestion;

  /// No description provided for @clearApplicationDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This dangerous operation cannot be undone. All documents, folders, RSS subscriptions, settings, and caches will be permanently deleted, and the app will close.'**
  String get clearApplicationDataWarning;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @storageOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The operation failed. Try again later.'**
  String get storageOperationFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

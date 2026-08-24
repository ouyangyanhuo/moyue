import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/features/debug/debug_fps_overlay.dart';
import 'package:moyue_application/features/reader/library_page.dart';
import 'package:moyue_application/features/rss/rss_page.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/l10n/app_localizations.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/debug_service.dart';
import 'package:moyue_application/services/incoming_file_service.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';

class MoyueApp extends StatefulWidget {
  const MoyueApp({super.key});

  @override
  State<MoyueApp> createState() => _MoyueAppState();
}

class _MoyueAppState extends State<MoyueApp> with WidgetsBindingObserver {
  final MoyueDisplayPreferences _display = MoyueDisplayPreferences();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _incomingFiles = IncomingFileService.instance;
  int _seenIncomingRevision = 0;
  Timer? _appearanceRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _incomingFiles.addListener(_handleIncomingFile);
    unawaited(DebugService.instance.refresh());
    unawaited(_display.load());
    unawaited(_incomingFiles.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingFiles.removeListener(_handleIncomingFile);
    _appearanceRefreshTimer?.cancel();
    _display.dispose();
    super.dispose();
  }

  void _handleIncomingFile() {
    final event = _incomingFiles.latestEvent;
    if (event == null || event.revision <= _seenIncomingRevision) return;
    _seenIncomingRevision = event.revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messageContext = _messengerKey.currentContext;
      if (messageContext == null) return;
      final l10n = AppLocalizations.of(messageContext);
      final text = event.succeeded
          ? l10n.fileImported(event.fileName)
          : l10n.fileImportFailed(
              event.fileName,
              event.error ?? l10n.unknownError,
            );
      _messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台时重查 debug.lock，便于随时放入/移除文件切换调试模式。
    if (state == AppLifecycleState.resumed) {
      unawaited(DebugService.instance.refresh());
      unawaited(_display.load());
      // Wallpaper/theme overlays can be committed shortly after the activity
      // resumes. Re-read once after that window so a newly applied wallpaper
      // cannot leave the previous seed color cached in the running app.
      _appearanceRefreshTimer?.cancel();
      _appearanceRefreshTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) unawaited(_display.load());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DisplayPreferencesScope(
      controller: _display,
      child: AnimatedBuilder(
        animation: _display,
        builder: (context, _) {
          final seedColor = Color(_display.effectiveSeedArgb);
          final themeMode = switch (_display.themePreference) {
            MoyueThemePreference.system => ThemeMode.system,
            MoyueThemePreference.light => ThemeMode.light,
            MoyueThemePreference.dark => ThemeMode.dark,
          };
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: _messengerKey,
            onGenerateTitle: (context) => AppLocalizations.of(context).appName,
            theme: buildMoyueTheme(
              inkMode: _display.isInkMode,
              brightness: Brightness.light,
              seedColor: seedColor,
              fontFamily: _display.appFontFamily,
              reduceMotion: _display.reduceMotion,
            ),
            darkTheme: buildMoyueTheme(
              inkMode: _display.isInkMode,
              brightness: Brightness.dark,
              seedColor: seedColor,
              fontFamily: _display.appFontFamily,
              reduceMotion: _display.reduceMotion,
            ),
            themeMode: themeMode,
            locale: _display.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            restorationScopeId: 'moyue_app',
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(_display.appFontScale),
                disableAnimations:
                    MediaQuery.disableAnimationsOf(context) ||
                    _display.reduceMotion,
                accessibleNavigation:
                    MediaQuery.accessibleNavigationOf(context) ||
                    _display.reduceMotion,
              ),
              child: GlassTheme(
                data: GlassThemeData(
                  light: GlassThemeVariant.light.copyWith(
                    settings: GlassThemeVariant.light.settings?.copyWith(
                      glassColor: Colors.white.withValues(
                        alpha: _display.glassOpacity,
                      ),
                      lightIntensity: 0.28,
                      ambientStrength: 0,
                      fresnelStrength: 0,
                      edgeAbsorption: 0.06,
                    ),
                  ),
                  dark: GlassThemeVariant.dark.copyWith(
                    settings: GlassThemeVariant.dark.settings?.copyWith(
                      glassColor: Colors.white.withValues(
                        alpha: _display.glassOpacity,
                      ),
                      lightIntensity: 0.22,
                      ambientStrength: 0,
                      fresnelStrength: 0,
                      edgeAbsorption: 0.09,
                    ),
                  ),
                  interaction: const GlassInteractionSettings(stretch: 0.18),
                ),
                // 全局调试浮层挂在 Navigator 之上的最外层，
                // 这样阅读页、文件夹页、编辑页等被推入的完整路由也能覆盖到。
                child: Stack(
                  children: [
                    ?child,
                    ListenableBuilder(
                      listenable: DebugService.instance,
                      builder: (context, _) {
                        final debug = DebugService.instance;
                        if (!debug.enabled || !debug.fpsBadgeVisible) {
                          return const SizedBox.shrink();
                        }
                        // 右上角、页面操作按钮行之下，避免遮挡玻璃控件。
                        return Positioned(
                          top: MediaQuery.paddingOf(context).top + 58,
                          right: 12,
                          child: const IgnorePointer(child: DebugFpsOverlay()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            home: const MoyueShell(),
          );
        },
      ),
    );
  }
}

class MoyueShell extends StatefulWidget {
  const MoyueShell({super.key});

  @override
  State<MoyueShell> createState() => _MoyueShellState();
}

class _MoyueShellState extends State<MoyueShell> {
  int _selectedIndex = 0;
  final _libraryKey = GlobalKey<LibraryPageState>();
  final _rssKey = GlobalKey<RssPageState>();
  final _settingsKey = GlobalKey<SettingsPageState>();
  final _storage = MoyueStorageService.instance;
  List<ReadingDocument> _documents = const [];
  List<LibraryFolder> _folders = const [];
  bool _loading = true;
  bool _exitArmed = false;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _storage.addListener(_reloadDocuments);
    _reloadDocuments();
  }

  @override
  void dispose() {
    _storage.removeListener(_reloadDocuments);
    _exitTimer?.cancel();
    super.dispose();
  }

  Future<void> _reloadDocuments() async {
    try {
      final documents = await _storage.loadDocuments();
      final folders = await _storage.loadFolders();
      if (mounted) {
        setState(() {
          _documents = documents;
          _folders = folders;
        });
      }
    } on Object {
      // 加载失败（含存储后端缺失等 Error）一律回退到空状态，
      // 避免未处理异步异常打断 UI。
      if (mounted) {
        setState(() {
          _documents = const [];
          _folders = const [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final display = DisplayPreferencesScope.of(context);
    final dockSettings = LiquidGlassSettings(
      ambientRim: 1,
      thickness: 30,
      blur: 3,
      chromaticAberration: 0.45,
      lightIntensity: 0.4,
      refractiveIndex: 1.59,
      saturation: 0.7,
      ambientStrength: 1,
      fresnelStrength: 1,
      lightAngle: 2.356,
      glowIntensity: 0.75,
      shadowElevation: 0,
      edgeAbsorption: 0.06,
      shadow: moyueGlassShadow(display.glassOpacity),
      glassColor: Colors.white.withValues(alpha: display.glassOpacity),
    );
    final pages = [
      LibraryPage(
        key: _libraryKey,
        documents: _documents,
        folders: _folders,
        loading: _loading,
      ),
      RssPage(key: _rssKey),
      SettingsPage(key: _settingsKey),
    ];

    return PopScope<void>(
      canPop: _exitArmed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_exitArmed) {
          SystemNavigator.pop();
          return;
        }
        setState(() => _exitArmed = true);
        _exitTimer?.cancel();
        _exitTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _exitArmed = false);
        });
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: GlassScaffold(
                background: const MoyueBackdrop(),
                // GlassScaffold uses this color for its bottom edge fade even
                // when a custom background widget is present. Supplying the
                // active surface keeps the dock mask dark in night mode.
                backgroundColor: theme.colorScheme.surface,
                statusBarStyle: theme.brightness == Brightness.dark
                    ? GlassStatusBarStyle.light
                    : GlassStatusBarStyle.dark,
                bottomBar: GlassTabBar.bottom(
                  tabs: [
                    GlassTab(
                      icon: const Icon(Icons.menu_book_outlined),
                      activeIcon: const Icon(Icons.menu_book_rounded),
                      label: l10n.readingTab,
                      semanticLabel: l10n.readingTab,
                    ),
                    GlassTab(
                      icon: const Icon(Icons.rss_feed_outlined),
                      activeIcon: const Icon(Icons.rss_feed_rounded),
                      label: l10n.subscriptionsTab,
                      semanticLabel: l10n.subscriptionsTab,
                    ),
                    GlassTab(
                      icon: const Icon(Icons.tune_outlined),
                      activeIcon: const Icon(Icons.tune_rounded),
                      label: l10n.settingsTab,
                      semanticLabel: l10n.settingsTab,
                    ),
                  ],
                  selectedIndex: _selectedIndex,
                  onTabSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  settings: dockSettings,
                  quality: GlassQuality.premium,
                  glowDuration: display.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  extraButton: GlassTabBarExtraButton(
                    icon: Icon(
                      _selectedIndex == 2
                          ? Icons.info_outline_rounded
                          : Icons.add_rounded,
                    ),
                    label: switch (_selectedIndex) {
                      0 => l10n.createOrImport,
                      1 => l10n.addSubscription,
                      _ => l10n.aboutMoyue,
                    },
                    size: 64,
                    onTap: _invokePrimaryAction,
                  ),
                  barHeight: 64,
                  horizontalPadding: 16,
                  verticalPadding: 14,
                  indicatorColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                  selectedIconColor: theme.colorScheme.onSurface,
                  selectedLabelColor: theme.colorScheme.onSurface,
                  unselectedIconColor: theme.colorScheme.onSurfaceVariant,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelFontSize: 11,
                ),
                body: Material(
                  type: MaterialType.transparency,
                  child: SafeArea(
                    bottom: false,
                    child: IndexedStack(index: _selectedIndex, children: pages),
                  ),
                ),
              ),
            ),
          ),
          if (_exitArmed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 106,
              child: Center(
                child: Material(
                  color: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.9,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Text(
                      l10n.pressBackAgain,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _invokePrimaryAction() {
    if (_selectedIndex == 0) {
      _libraryKey.currentState?.showAddMenu();
    } else if (_selectedIndex == 1) {
      _rssKey.currentState?.showAddSource();
    } else {
      _settingsKey.currentState?.showAbout();
    }
  }
}

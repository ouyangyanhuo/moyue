import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
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
  const MoyueApp({this.display, super.key});

  final MoyueDisplayPreferences? display;

  @override
  State<MoyueApp> createState() => _MoyueAppState();
}

class _MoyueAppState extends State<MoyueApp> with WidgetsBindingObserver {
  late final MoyueDisplayPreferences _display =
      widget.display ?? MoyueDisplayPreferences();
  late final bool _ownsDisplay = widget.display == null;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _incomingFiles = IncomingFileService.instance;
  final _dynamicColorKey = GlobalKey<DynamicColorBuilderState>();
  int _seenIncomingRevision = 0;
  Timer? _appearanceRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _incomingFiles.addListener(_handleIncomingFile);
    unawaited(DebugService.instance.refresh());
    if (widget.display == null) unawaited(_display.load());
    unawaited(_incomingFiles.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingFiles.removeListener(_handleIncomingFile);
    _appearanceRefreshTimer?.cancel();
    if (_ownsDisplay) _display.dispose();
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
      unawaited(_dynamicColorKey.currentState?.initPlatformState());
      // Wallpaper/theme overlays can be committed shortly after the activity
      // resumes. Re-read once after that window so a newly applied wallpaper
      // cannot leave the previous seed color cached in the running app.
      _appearanceRefreshTimer?.cancel();
      _appearanceRefreshTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        unawaited(_display.load());
        unawaited(_dynamicColorKey.currentState?.initPlatformState());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      key: _dynamicColorKey,
      builder: (lightDynamic, darkDynamic) => DisplayPreferencesScope(
        controller: _display,
        child: AnimatedBuilder(
          animation: _display,
          builder: (context, _) {
            final seedColor = Color(_display.effectiveSeedArgb);
            final useMonet = _display.useDynamicColor;
            final themeMode = switch (_display.themePreference) {
              MoyueThemePreference.system => ThemeMode.system,
              MoyueThemePreference.light => ThemeMode.light,
              MoyueThemePreference.dark => ThemeMode.dark,
            };
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: _messengerKey,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context).appName,
              theme: buildMoyueTheme(
                inkMode: _display.isInkMode,
                brightness: Brightness.light,
                seedColor: seedColor,
                fontFamily: _display.effectiveAppFontFamily,
                dynamicColorScheme: useMonet ? lightDynamic : null,
                reduceMotion: _display.effectiveReduceMotion,
              ),
              darkTheme: buildMoyueTheme(
                inkMode: _display.isInkMode,
                brightness: Brightness.dark,
                seedColor: seedColor,
                fontFamily: _display.effectiveAppFontFamily,
                dynamicColorScheme: useMonet ? darkDynamic : null,
                reduceMotion: _display.effectiveReduceMotion,
              ),
              themeMode: themeMode,
              locale: _display.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              restorationScopeId: 'moyue_app',
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness:
                          Theme.of(context).brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarColor: Theme.of(context)
                          .colorScheme
                          .surface,
                      systemNavigationBarIconBrightness:
                          Theme.of(context).brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarDividerColor: Colors.transparent,
                    ),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(
                          _display.effectiveAppFontScale,
                        ),
                        disableAnimations:
                            MediaQuery.disableAnimationsOf(context) ||
                            _display.effectiveReduceMotion,
                        accessibleNavigation:
                            MediaQuery.accessibleNavigationOf(context) ||
                            _display.effectiveReduceMotion,
                      ),
                      child: GlassTheme(
                        data: GlassThemeData(
                          light: GlassThemeVariant.light.copyWith(
                            settings: GlassThemeVariant.light.settings
                                ?.copyWith(
                                  glassColor: Colors.white.withValues(
                                    alpha: _display.glassOpacity,
                                  ),
                                  lightIntensity: _display.isInkMode
                                      ? 0.22
                                      : 0.28,
                                  ambientStrength: 0,
                                  fresnelStrength: _display.isInkMode
                                      ? 0.08
                                      : 0,
                                  edgeAbsorption: 0.06,
                                  saturation: _display.isInkMode ? 0 : null,
                                  chromaticAberration: _display.isInkMode
                                      ? 0
                                      : null,
                                ),
                          ),
                          dark: GlassThemeVariant.dark.copyWith(
                            settings: GlassThemeVariant.dark.settings?.copyWith(
                              glassColor: Colors.white.withValues(
                                alpha: _display.glassOpacity,
                              ),
                              lightIntensity: _display.isInkMode ? 0.18 : 0.22,
                              ambientStrength: 0,
                              fresnelStrength: _display.isInkMode ? 0.08 : 0,
                              edgeAbsorption: 0.09,
                              saturation: _display.isInkMode ? 0 : null,
                              chromaticAberration: _display.isInkMode
                                  ? 0
                                  : null,
                            ),
                          ),
                          interaction: GlassInteractionSettings(
                            stretch: _display.isInkMode ? 0 : 0.18,
                          ),
                        ),
                        // 全局调试浮层挂在 Navigator 之上的最外层，
                        // 这样阅读页、文件夹页、编辑页等被推入的完整路由也能覆盖到。
                        child: _InkGlassQualityBoundary(
                          enabled: _display.isInkMode,
                          child: Stack(
                            children: [
                              ?child,
                              ListenableBuilder(
                                listenable: DebugService.instance,
                                builder: (context, _) {
                                  final debug = DebugService.instance;
                                  if (!debug.enabled ||
                                      !debug.fpsBadgeVisible) {
                                    return const SizedBox.shrink();
                                  }
                                  // 右上角、页面操作按钮行之下，避免遮挡玻璃控件。
                                  return Positioned(
                                    top: MediaQuery.paddingOf(context).top + 58,
                                    right: 12,
                                    child: const IgnorePointer(
                                      child: DebugFpsOverlay(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              home: const MoyueShell(),
            );
          },
        ),
      ),
    );
  }
}

class _InkGlassQualityBoundary extends StatelessWidget {
  const _InkGlassQualityBoundary({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    // The package marks adaptive scoping experimental, but pinning both bounds
    // to standard is the only supported way to cap explicit premium children.
    // ignore: experimental_member_use
    return GlassAdaptiveScope(
      minQuality: GlassQuality.standard,
      maxQuality: GlassQuality.standard,
      initialQuality: GlassQuality.standard,
      allowStepUp: false,
      child: child,
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
  late final _rssPage = RssPage(key: _rssKey);
  late final _settingsPage = SettingsPage(key: _settingsKey);
  Widget? _libraryPage;
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
      if (mounted) {
        setState(() {
          _loading = false;
          _libraryPage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final display = DisplayPreferencesScope.of(context);
    final inkMode = display.isInkMode;
    final dockSettings = LiquidGlassSettings(
      ambientRim: 1,
      thickness: 30,
      blur: inkMode ? 1 : 3,
      chromaticAberration: inkMode ? 0 : 0.45,
      lightIntensity: inkMode ? 0.28 : 0.4,
      refractiveIndex: 1.59,
      saturation: inkMode ? 0 : 0.7,
      ambientStrength: inkMode ? 0.06 : 1,
      fresnelStrength: inkMode ? 0.12 : 1,
      lightAngle: 2.356,
      glowIntensity: inkMode ? 0 : 0.75,
      shadowElevation: 0,
      edgeAbsorption: 0.06,
      shadow: moyueGlassShadow(display.glassOpacity),
      glassColor: Colors.white.withValues(alpha: display.glassOpacity),
    );
    final pages = [
      _libraryPage ??= LibraryPage(
        key: _libraryKey,
        documents: _documents,
        folders: _folders,
        loading: _loading,
      ),
      _rssPage,
      _settingsPage,
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
                // The package's texture-capture fade can retain a light
                // background frame across a runtime theme change. Moyue uses
                // an explicit theme-aware overlay below the dock instead.
                bottomEdgeFade: false,
                bodyOverlays: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 132 + MediaQuery.paddingOf(context).bottom,
                    child: const _MoyueDockEdgeFade(),
                  ),
                ],
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
                  onTabSelected: (index) {
                    if (index == _selectedIndex) return;
                    setState(() => _selectedIndex = index);
                  },
                  settings: dockSettings,
                  quality: inkMode
                      ? GlassQuality.standard
                      : GlassQuality.premium,
                  glowDuration: display.effectiveReduceMotion
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
                    top: false,
                    bottom: false,
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          TickerMode(
                            enabled: i == _selectedIndex,
                            child: RepaintBoundary(child: pages[i]),
                          ),
                      ],
                    ),
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

class _MoyueDockEdgeFade extends StatelessWidget {
  const _MoyueDockEdgeFade();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return IgnorePointer(
      child: DecoratedBox(
        key: const ValueKey('home-dock-edge-fade'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              surface.withValues(alpha: 0),
              surface.withValues(alpha: 0.12),
              surface.withValues(alpha: 0.72),
              surface,
            ],
            stops: const [0, 0.34, 0.72, 1],
          ),
        ),
      ),
    );
  }
}

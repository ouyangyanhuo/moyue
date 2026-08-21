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
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';

class MoyueApp extends StatefulWidget {
  const MoyueApp({super.key});

  @override
  State<MoyueApp> createState() => _MoyueAppState();
}

class _MoyueAppState extends State<MoyueApp> with WidgetsBindingObserver {
  final MoyueDisplayPreferences _display = MoyueDisplayPreferences();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(DebugService.instance.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _display.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台时重查 debug.lock，便于随时放入/移除文件切换调试模式。
    if (state == AppLifecycleState.resumed) {
      unawaited(DebugService.instance.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DisplayPreferencesScope(
      controller: _display,
      child: AnimatedBuilder(
        animation: _display,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '墨阅',
          theme: buildMoyueTheme(inkMode: _display.isInkMode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          restorationScopeId: 'moyue_app',
          builder: (context, child) => GlassTheme(
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
          home: const MoyueShell(),
        ),
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
      LibraryPage(documents: _documents, folders: _folders, loading: _loading),
      const RssPage(),
      const SettingsPage(),
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
                statusBarStyle: GlassStatusBarStyle.dark,
                bottomBar: GlassTabBar.bottom(
                  tabs: const [
                    GlassTab(
                      icon: Icon(Icons.menu_book_outlined),
                      activeIcon: Icon(Icons.menu_book_rounded),
                      label: '阅读',
                      semanticLabel: '阅读',
                    ),
                    GlassTab(
                      icon: Icon(Icons.rss_feed_outlined),
                      activeIcon: Icon(Icons.rss_feed_rounded),
                      label: '订阅',
                      semanticLabel: '订阅',
                    ),
                    GlassTab(
                      icon: Icon(Icons.tune_outlined),
                      activeIcon: Icon(Icons.tune_rounded),
                      label: '设置',
                      semanticLabel: '设置',
                    ),
                  ],
                  selectedIndex: _selectedIndex,
                  onTabSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  settings: dockSettings,
                  quality: GlassQuality.standard,
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
                      '再按一次返回桌面',
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
}

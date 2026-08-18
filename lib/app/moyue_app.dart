import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/features/reader/library_page.dart';
import 'package:moyue_application/features/rss/rss_page.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/l10n/app_localizations.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/moyue_backdrop.dart';

class MoyueApp extends StatefulWidget {
  const MoyueApp({super.key});

  @override
  State<MoyueApp> createState() => _MoyueAppState();
}

class _MoyueAppState extends State<MoyueApp> {
  final MoyueDisplayPreferences _display = MoyueDisplayPreferences();

  @override
  void dispose() {
    _display.dispose();
    super.dispose();
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
            child: child!,
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
    } on Exception {
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
      thickness: 30,
      blur: 3,
      chromaticAberration: 0.3,
      lightIntensity: 0.6,
      refractiveIndex: 1.59,
      saturation: 0.7,
      ambientStrength: 1,
      lightAngle: 2.356,
      glassColor: Colors.white.withValues(alpha: display.glassOpacity),
      shadowElevation: 0,
      shadow: moyueGlassShadow(display.glassOpacity),
      edgeAbsorption: 0.06,
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

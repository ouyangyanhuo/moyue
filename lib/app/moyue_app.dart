import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';
import 'package:moyue_application/features/reader/library_page.dart';
import 'package:moyue_application/features/rss/rss_page.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/l10n/app_localizations.dart';
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
                ),
              ),
              dark: GlassThemeVariant.dark.copyWith(
                settings: GlassThemeVariant.dark.settings?.copyWith(
                  glassColor: Colors.white.withValues(
                    alpha: _display.glassOpacity,
                  ),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _storage.addListener(_reloadDocuments);
    _reloadDocuments();
  }

  @override
  void dispose() {
    _storage.removeListener(_reloadDocuments);
    super.dispose();
  }

  Future<void> _reloadDocuments() async {
    try {
      final documents = await _storage.loadDocuments();
      if (mounted) setState(() => _documents = documents);
    } on Exception {
      if (mounted) setState(() => _documents = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = [
      LibraryPage(documents: _documents, loading: _loading),
      const RssPage(),
      const SettingsPage(),
    ];

    return Material(
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
          onTabSelected: (index) => setState(() => _selectedIndex = index),
          quality: GlassQuality.standard,
          barHeight: 64,
          horizontalPadding: 16,
          verticalPadding: 14,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.2),
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
    );
  }
}

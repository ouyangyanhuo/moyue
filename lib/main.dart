import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  runApp(
    LiquidGlassWidgets.wrap(
      child: const MyApp(),
      brightnessResolver: Theme.maybeBrightnessOf,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF66725F)),
        useMaterial3: true,
      ),
      dark: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB7C2AF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => AppLocalizations.of(context).appName,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        darkTheme: darkTheme,
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final destinations = <_DockDestination>[
      _DockDestination(
        label: localizations.homeTab,
        message: localizations.homeMessage,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _DockDestination(
        label: localizations.libraryTab,
        message: localizations.libraryMessage,
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
      ),
      _DockDestination(
        label: localizations.notesTab,
        message: localizations.notesMessage,
        icon: Icons.edit_note_outlined,
        activeIcon: Icons.edit_note_rounded,
      ),
      _DockDestination(
        label: localizations.profileTab,
        message: localizations.profileMessage,
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    final selectedDestination = destinations[_selectedIndex];
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      background: _MoyueBackdrop(isDark: isDark),
      statusBarStyle: isDark
          ? GlassStatusBarStyle.light
          : GlassStatusBarStyle.dark,
      bottomBar: GlassTabBar.bottom(
        tabs: [
          for (final destination in destinations)
            GlassTab(
              icon: Icon(destination.icon),
              activeIcon: Icon(destination.activeIcon),
              label: destination.label,
              semanticLabel: destination.label,
              glowColor: colorScheme.primary,
            ),
        ],
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        quality: GlassQuality.standard,
        barHeight: 66,
        horizontalPadding: 16,
        verticalPadding: 14,
        indicatorColor: colorScheme.primary.withValues(
          alpha: isDark ? 0.34 : 0.22,
        ),
        selectedIconColor: colorScheme.onSurface,
        selectedLabelColor: colorScheme.onSurface,
        unselectedIconColor: colorScheme.onSurfaceVariant,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
      ),
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _DockPage(
            key: ValueKey(_selectedIndex),
            destination: selectedDestination,
          ),
        ),
      ),
    );
  }
}

class _DockDestination {
  const _DockDestination({
    required this.label,
    required this.message,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final String message;
  final IconData icon;
  final IconData activeIcon;
}

class _DockPage extends StatelessWidget {
  const _DockPage({super.key, required this.destination});

  final _DockDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Icon(
                destination.activeIcon,
                size: 42,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              destination.label,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              destination.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoyueBackdrop extends StatelessWidget {
  const _MoyueBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? const [Color(0xFF111412), Color(0xFF1B211D), Color(0xFF101210)]
        : const [Color(0xFFF7F3E9), Color(0xFFDCE4D7), Color(0xFFF1E9DD)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: _BackdropGlow(
              color: isDark ? const Color(0xFF66725F) : const Color(0xFFB9C8AF),
              size: 260,
            ),
          ),
          Positioned(
            bottom: 40,
            left: -90,
            child: _BackdropGlow(
              color: isDark ? const Color(0xFF5F544B) : const Color(0xFFE5CDBA),
              size: 300,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

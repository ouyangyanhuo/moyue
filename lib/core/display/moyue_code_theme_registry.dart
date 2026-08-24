import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_highlighting/themes/a11y-dark.dart';
import 'package:flutter_highlighting/themes/a11y-light.dart';
import 'package:flutter_highlighting/themes/atom-one-dark.dart';
import 'package:flutter_highlighting/themes/atom-one-light.dart';
import 'package:flutter_highlighting/themes/darcula.dart';
import 'package:flutter_highlighting/themes/dracula.dart';
import 'package:flutter_highlighting/themes/github-dark.dart';
import 'package:flutter_highlighting/themes/github-dark-dimmed.dart';
import 'package:flutter_highlighting/themes/github.dart';
import 'package:flutter_highlighting/themes/gruvbox-dark.dart';
import 'package:flutter_highlighting/themes/gruvbox-light.dart';
import 'package:flutter_highlighting/themes/kimbie-dark.dart';
import 'package:flutter_highlighting/themes/monokai-sublime.dart';
import 'package:flutter_highlighting/themes/monokai.dart';
import 'package:flutter_highlighting/themes/night-owl.dart';
import 'package:flutter_highlighting/themes/nord.dart';
import 'package:flutter_highlighting/themes/solarized-dark.dart';
import 'package:flutter_highlighting/themes/solarized-light.dart';
import 'package:flutter_highlighting/themes/tokyo-night-dark.dart';
import 'package:flutter_highlighting/themes/tokyo-night-light.dart';
import 'package:flutter_highlighting/themes/tomorrow-night-blue.dart';
import 'package:flutter_highlighting/themes/vs.dart';
import 'package:flutter_highlighting/themes/vs2015.dart';
import 'package:flutter_highlighting/themes/xcode.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';

typedef MoyueCodeThemeLabelBuilder = String Function(BuildContext context);
typedef MoyueCodePaletteBuilder = Map<String, TextStyle> Function(
  Brightness brightness,
);

class MoyueCodeThemeDefinition {
  const MoyueCodeThemeDefinition({
    required this.id,
    required this.labelBuilder,
    required this.descriptionBuilder,
    required this.paletteBuilder,
  });

  final String id;
  final MoyueCodeThemeLabelBuilder labelBuilder;
  final MoyueCodeThemeLabelBuilder descriptionBuilder;
  final MoyueCodePaletteBuilder paletteBuilder;

  String label(BuildContext context) => labelBuilder(context);
  String description(BuildContext context) => descriptionBuilder(context);
  Map<String, TextStyle> palette(Brightness brightness) =>
      paletteBuilder(brightness);
}

/// Syntax-highlight theme contribution point, modeled after VS Code's stable
/// theme ID + contributed token palette approach.
class MoyueCodeThemeRegistry {
  MoyueCodeThemeRegistry._();

  static const defaultThemeId = 'vscode-auto';
  static final Set<String> _builtInIds = <String>{};
  static final LinkedHashMap<String, MoyueCodeThemeDefinition> _themes =
      LinkedHashMap<String, MoyueCodeThemeDefinition>();

  static List<MoyueCodeThemeDefinition> get themes {
    _ensureBuiltIns();
    return List.unmodifiable(_themes.values);
  }

  static void register(MoyueCodeThemeDefinition theme, {bool replace = false}) {
    _ensureBuiltIns();
    if (theme.id.trim().isEmpty) {
      throw ArgumentError.value(theme.id, 'theme.id', 'must not be empty');
    }
    if (!replace && _themes.containsKey(theme.id)) {
      throw StateError('Code theme "${theme.id}" is already registered.');
    }
    _themes[theme.id] = theme;
  }

  static bool unregister(String id) {
    _ensureBuiltIns();
    if (_builtInIds.contains(id)) return false;
    return _themes.remove(id) != null;
  }

  static MoyueCodeThemeDefinition resolve(String id) {
    _ensureBuiltIns();
    return _themes[id] ?? _themes[defaultThemeId]!;
  }

  static String migrateLegacyId(String? id) => switch (id) {
    null || '' || 'soft' || 'outlined' || 'minimal' => defaultThemeId,
    _ => id,
  };

  static void _ensureBuiltIns() {
    if (_builtInIds.isNotEmpty) return;
    for (final theme in _builtIns) {
      _themes[theme.id] = theme;
      _builtInIds.add(theme.id);
    }
  }

  static MoyueCodeThemeDefinition _fixed({
    required String id,
    required String label,
    required Map<String, TextStyle> palette,
    required MoyueCodeThemeLabelBuilder description,
  }) => MoyueCodeThemeDefinition(
    id: id,
    labelBuilder: (_) => label,
    descriptionBuilder: description,
    paletteBuilder: (_) => palette,
  );

  static final List<MoyueCodeThemeDefinition> _builtIns = [
    MoyueCodeThemeDefinition(
      id: defaultThemeId,
      labelBuilder: (context) => context.l10n.vscodeAutomaticTheme,
      descriptionBuilder: (context) =>
          context.l10n.vscodeAutomaticThemeDescription,
      paletteBuilder: (brightness) =>
          brightness == Brightness.dark ? vs2015Theme : vsTheme,
    ),
    _fixed(
      id: 'vscode-light-plus',
      label: 'VS Code Light+',
      palette: vsTheme,
      description: (context) => context.l10n.vscodeLightThemeDescription,
    ),
    _fixed(
      id: 'vscode-dark-plus',
      label: 'VS Code Dark+',
      palette: vs2015Theme,
      description: (context) => context.l10n.vscodeDarkThemeDescription,
    ),
    _fixed(
      id: 'github-light',
      label: 'GitHub Light',
      palette: githubTheme,
      description: (context) =>
          context.l10n.communityCodeThemeDescription('GitHub Light'),
    ),
    _fixed(
      id: 'github-dark',
      label: 'GitHub Dark',
      palette: githubDarkTheme,
      description: (context) =>
          context.l10n.communityCodeThemeDescription('GitHub Dark'),
    ),
    _fixed(
      id: 'monokai',
      label: 'Monokai',
      palette: monokaiTheme,
      description: (context) => context.l10n.monokaiThemeDescription,
    ),
    _fixed(
      id: 'monokai-dimmed',
      label: 'Monokai Dimmed',
      palette: monokaiSublimeTheme,
      description: (context) => context.l10n.monokaiDimmedThemeDescription,
    ),
    _fixed(
      id: 'solarized-light',
      label: 'Solarized Light',
      palette: solarizedLightTheme,
      description: (context) => context.l10n.solarizedCodeThemeDescription,
    ),
    _fixed(
      id: 'solarized-dark',
      label: 'Solarized Dark',
      palette: solarizedDarkTheme,
      description: (context) => context.l10n.solarizedCodeThemeDescription,
    ),
    _fixed(
      id: 'kimbie-dark',
      label: 'Kimbie Dark',
      palette: kimbieDarkTheme,
      description: (context) => context.l10n.kimbieThemeDescription,
    ),
    _fixed(
      id: 'tomorrow-night-blue',
      label: 'Tomorrow Night Blue',
      palette: tomorrowNightBlueTheme,
      description: (context) => context.l10n.tomorrowThemeDescription,
    ),
    _fixed(
      id: 'high-contrast-light',
      label: 'High Contrast Light',
      palette: a11yLightTheme,
      description: (context) => context.l10n.highContrastCodeThemeDescription,
    ),
    _fixed(
      id: 'high-contrast-dark',
      label: 'High Contrast Dark',
      palette: a11yDarkTheme,
      description: (context) => context.l10n.highContrastCodeThemeDescription,
    ),
    for (final contribution
        in <({String id, String label, Map<String, TextStyle> palette})>[
          (
            id: 'atom-one-light',
            label: 'Atom One Light',
            palette: atomOneLightTheme,
          ),
          (
            id: 'atom-one-dark',
            label: 'Atom One Dark',
            palette: atomOneDarkTheme,
          ),
          (id: 'dracula', label: 'Dracula', palette: draculaTheme),
          (id: 'darcula', label: 'Darcula', palette: darculaTheme),
          (
            id: 'github-dark-dimmed',
            label: 'GitHub Dark Dimmed',
            palette: githubDarkDimmedTheme,
          ),
          (
            id: 'gruvbox-light',
            label: 'Gruvbox Light',
            palette: gruvboxLightTheme,
          ),
          (
            id: 'gruvbox-dark',
            label: 'Gruvbox Dark',
            palette: gruvboxDarkTheme,
          ),
          (id: 'night-owl', label: 'Night Owl', palette: nightOwlTheme),
          (id: 'nord', label: 'Nord', palette: nordTheme),
          (
            id: 'tokyo-night-light',
            label: 'Tokyo Night Light',
            palette: tokyoNightLightTheme,
          ),
          (
            id: 'tokyo-night-dark',
            label: 'Tokyo Night Dark',
            palette: tokyoNightDarkTheme,
          ),
          (id: 'xcode', label: 'Xcode', palette: xcodeTheme),
        ])
      _fixed(
        id: contribution.id,
        label: contribution.label,
        palette: contribution.palette,
        description: (context) =>
            context.l10n.communityCodeThemeDescription(contribution.label),
      ),
  ];
}

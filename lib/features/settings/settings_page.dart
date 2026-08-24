import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:moyue_application/services/app_restart_service.dart';
import 'package:moyue_application/services/app_storage_maintenance_service.dart';
import 'package:moyue_application/services/app_version_service.dart';
import 'package:moyue_application/services/debug_service.dart';
import 'package:moyue_application/widgets/floating_page_shell.dart';
import 'package:moyue_application/widgets/expandable_glass_search.dart';
import 'package:moyue_application/widgets/moyue_create_menu.dart';
import 'package:moyue_application/widgets/section_label.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  static const _fontScales = <double>[0.85, 0.95, 1.0, 1.1, 1.2, 1.3, 1.4];
  static const _customColors = <int>[
    0xFF6D7967,
    0xFF5B6F8F,
    0xFF7B5F87,
    0xFF9A624B,
    0xFF3E7D73,
  ];
  String _query = '';
  final _searchKey = GlobalKey<ExpandableGlassSearchState>();

  AnimationStyle? get _sheetAnimationStyle =>
      DisplayPreferencesScope.maybeOf(context)?.reduceMotion ?? false
      ? AnimationStyle.noAnimation
      : null;

  void openSearch() => _searchKey.currentState?.open();

  Future<void> showAbout() {
    final version = AppVersionService.displayVersion();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      sheetAnimationStyle: _sheetAnimationStyle,
      builder: (sheetContext) => _AboutSheet(version: version),
    );
  }

  Future<void> _showSettingDetail({
    required WidgetBuilder contentBuilder,
    Listenable? listenable,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    sheetAnimationStyle: _sheetAnimationStyle,
    builder: (sheetContext) => MoyueMaterialSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
        ),
        child: SingleChildScrollView(
          child: listenable == null
              ? Builder(builder: contentBuilder)
              : ListenableBuilder(
                  listenable: listenable,
                  builder: (context, _) => contentBuilder(context),
                ),
        ),
      ),
    ),
  );

  Future<void> _showSwitchDetail({
    required Listenable listenable,
    required IconData icon,
    required String title,
    required String description,
    required bool Function() value,
    required ValueChanged<bool>? onChanged,
    String Function(bool value)? statusBuilder,
  }) => _showSettingDetail(
    listenable: listenable,
    contentBuilder: (context) {
      final l10n = context.l10n;
      final current = value();
      return _SettingDetailSheet(
        key: ValueKey('$title-setting-detail'),
        icon: icon,
        title: title,
        description: description,
        status:
            statusBuilder?.call(current) ??
            (current ? l10n.enabled : l10n.disabled),
        control: Align(
          alignment: Alignment.centerRight,
          child: _GlassSwitchControl(
            touchAreaKey: ValueKey('$title-detail-switch-touch-area'),
            value: current,
            onChanged: onChanged,
            semanticLabel: title,
          ),
        ),
      );
    },
  );

  Future<void> _showContrastDetail(DisplayModeController display) =>
      _showSettingDetail(
        listenable: display,
        contentBuilder: (context) => _SettingDetailSheet(
          key: const ValueKey('对比度-setting-detail'),
          icon: Icons.contrast_rounded,
          title: context.l10n.contrast,
          description: context.l10n.contrastDescription,
          status: '${(display.contrast * 100).round()}%',
          control: _ExpandedGlassSlider(
            touchAreaKey: const ValueKey('contrast-slider-touch-area'),
            value: display.contrast,
            onChanged: display.setContrast,
          ),
        ),
      );

  Future<void> _showNativeEngineDetail(DisplayModeController display) =>
      _showSettingDetail(
        listenable: display,
        contentBuilder: (context) {
          final l10n = context.l10n;
          final htmlUsesWebView = display.htmlWebViewEnabled;
          return _SettingDetailSheet(
            key: const ValueKey('原生排版引擎-setting-detail'),
            icon: Icons.auto_awesome_motion_outlined,
            title: l10n.nativeLayoutEngine,
            description: htmlUsesWebView
                ? l10n.nativeEngineWebViewDescription
                : l10n.nativeEngineAllDescription,
            status: htmlUsesWebView ? l10n.markdownOnly : l10n.markdownAndHtml,
          );
        },
      );

  Future<void> _chooseFontSize(DisplayModeController display) async {
    final l10n = context.l10n;
    final initialIndex = _nearestFontScaleIndex(display.appFontScale);
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      sheetAnimationStyle: _sheetAnimationStyle,
      builder: (sheetContext) => _FontScalePickerSheet(
        scales: _fontScales,
        initialIndex: initialIndex,
      ),
    );
    if (selected == null || selected == display.appFontScale || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.restartRequired),
        content: Text(dialogContext.l10n.restartRequiredDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.applyAndRestart),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await display.setAppFontScale(selected);
    final restarted = await AppRestartService.restart();
    if (!restarted && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.fontSavedRestartManually)));
    }
  }

  Future<void> _chooseThemePreference(DisplayModeController display) async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<MoyueThemePreference>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      sheetAnimationStyle: _sheetAnimationStyle,
      builder: (sheetContext) => _OptionPickerSheet<MoyueThemePreference>(
        title: l10n.nightMode,
        selected: display.themePreference,
        options: [
          _PickerOption(
            value: MoyueThemePreference.system,
            icon: Icons.brightness_auto_rounded,
            title: l10n.followSystem,
            subtitle: l10n.followSystemThemeDescription,
          ),
          _PickerOption(
            value: MoyueThemePreference.light,
            icon: Icons.light_mode_outlined,
            title: l10n.lightMode,
            subtitle: l10n.lightModeDescription,
          ),
          _PickerOption(
            value: MoyueThemePreference.dark,
            icon: Icons.dark_mode_outlined,
            title: l10n.darkMode,
            subtitle: l10n.darkModeDescription,
          ),
        ],
      ),
    );
    if (selected != null) display.setThemePreference(selected);
  }

  Future<void> _chooseLocalePreference(DisplayModeController display) async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<MoyueLocalePreference>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      sheetAnimationStyle: _sheetAnimationStyle,
      builder: (sheetContext) => _OptionPickerSheet<MoyueLocalePreference>(
        title: l10n.language,
        selected: display.localePreference,
        options: [
          _PickerOption(
            value: MoyueLocalePreference.system,
            icon: Icons.language_rounded,
            title: l10n.followSystem,
            subtitle: l10n.systemPreferredLanguage,
          ),
          _PickerOption(
            value: MoyueLocalePreference.chinese,
            icon: Icons.translate_rounded,
            title: l10n.chinese,
            subtitle: l10n.simplifiedChinese,
          ),
          _PickerOption(
            value: MoyueLocalePreference.english,
            icon: Icons.translate_rounded,
            title: l10n.english,
            subtitle: l10n.english,
          ),
        ],
      ),
    );
    if (selected != null) display.setLocalePreference(selected);
  }

  Future<void> _chooseFontFamily(DisplayModeController display) async {
    final selected = await showModalBottomSheet<MoyueFontFamily>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      sheetAnimationStyle: _sheetAnimationStyle,
      builder: (sheetContext) =>
          _FontFamilyPickerSheet(initialValue: display.appFontFamily),
    );
    if (selected != null) display.setAppFontFamily(selected);
  }

  Future<void> _showColorSettings(DisplayModeController display) =>
      _showSettingDetail(
        listenable: display,
        contentBuilder: (context) {
          final l10n = context.l10n;
          final systemAvailable = display.dynamicColorSupported;
          return _SettingDetailSheet(
            key: const ValueKey('应用配色-setting-detail'),
            icon: Icons.palette_outlined,
            title: l10n.appColors,
            description: l10n.appColorsDescription,
            status: display.useDynamicColor && systemAvailable
                ? l10n.monetColors
                : l10n.customColor,
            control: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.useSystemMonet)),
                    _GlassSwitchControl(
                      touchAreaKey: const ValueKey(
                        'dynamic-color-switch-touch-area',
                      ),
                      value: display.useDynamicColor && systemAvailable,
                      onChanged: systemAvailable
                          ? display.setUseDynamicColor
                          : null,
                      semanticLabel: l10n.monetColors,
                    ),
                  ],
                ),
                if (!systemAvailable)
                  Text(
                    l10n.monetUnavailable,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final value in _customColors)
                      _ColorChoice(
                        color: Color(value),
                        selected:
                            !display.useDynamicColor &&
                            display.customSeedArgb == value,
                        onTap: () => display.setCustomSeedArgb(value),
                      ),
                    _CustomColorButton(
                      color: Color(display.customSeedArgb),
                      onTap: () => _chooseCustomColor(display),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

  Future<void> _chooseCustomColor(DisplayModeController display) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) =>
          _ColorWheelDialog(initialArgb: display.customSeedArgb),
    );
    if (selected != null) display.setCustomSeedArgb(selected);
  }

  Future<bool> _confirmDangerousAction({
    required String title,
    required String message,
    required String actionLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            icon: Icon(Icons.warning_amber_rounded, color: colors.error),
            title: Text(title, textAlign: TextAlign.center),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(actionLabel),
              ),
            ],
          );
        },
      ) ??
      false;

  Future<void> _clearCache() async {
    final l10n = context.l10n;
    final confirmed = await _confirmDangerousAction(
      title: l10n.clearCacheQuestion,
      message: l10n.clearCacheWarning,
      actionLabel: l10n.clearCache,
    );
    if (!confirmed || !mounted) return;
    final cleared = await AppStorageMaintenanceService.clearCache();
    if (!mounted) return;
    await _showStorageResult(
      succeeded: cleared,
      message: cleared ? l10n.cacheCleared : l10n.storageOperationFailed,
    );
  }

  Future<void> _clearApplicationData() async {
    final l10n = context.l10n;
    final confirmed = await _confirmDangerousAction(
      title: l10n.clearApplicationDataQuestion,
      message: l10n.clearApplicationDataWarning,
      actionLabel: l10n.clearApplicationData,
    );
    if (!confirmed || !mounted) return;
    final started = await AppStorageMaintenanceService.clearApplicationData();
    if (!started && mounted) {
      await _showStorageResult(
        succeeded: false,
        message: l10n.storageOperationFailed,
      );
    }
  }

  Future<void> _showStorageResult({
    required bool succeeded,
    required String message,
  }) => showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        icon: Icon(
          succeeded ? Icons.check_circle_outline_rounded : Icons.error_outline,
          color: succeeded ? colors.primary : colors.error,
        ),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.gotIt),
          ),
        ],
      );
    },
  );

  String _themePreferenceLabel(
    BuildContext context,
    MoyueThemePreference value,
  ) => switch (value) {
    MoyueThemePreference.system => context.l10n.followSystem,
    MoyueThemePreference.light => context.l10n.lightMode,
    MoyueThemePreference.dark => context.l10n.darkMode,
  };

  String _localePreferenceLabel(
    BuildContext context,
    MoyueLocalePreference value,
  ) => switch (value) {
    MoyueLocalePreference.system => context.l10n.followSystem,
    MoyueLocalePreference.chinese => context.l10n.chinese,
    MoyueLocalePreference.english => context.l10n.english,
  };

  String _fontFamilyLabel(BuildContext context, MoyueFontFamily value) =>
      switch (value) {
        MoyueFontFamily.system => context.l10n.systemSans,
        MoyueFontFamily.claude => context.l10n.claudeStyleSans,
        MoyueFontFamily.rounded => context.l10n.roundedSans,
      };

  int _nearestFontScaleIndex(double value) {
    var result = 0;
    var distance = double.infinity;
    for (var index = 0; index < _fontScales.length; index++) {
      final next = (_fontScales[index] - value).abs();
      if (next < distance) {
        result = index;
        distance = next;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final display = DisplayPreferencesScope.of(context);
    final debug = DebugService.instance;
    final query = _query.trim().toLowerCase();
    final displayTerms = [
      '显示主题配色莫奈自定义颜色夜间深色墨模式对比度护眼字体衬线Claude字号大小',
      l10n.displaySection,
      l10n.appColors,
      l10n.monetColors,
      l10n.customColor,
      l10n.nightMode,
      l10n.inkMode,
      l10n.contrast,
      l10n.sansSerifFont,
      l10n.softwareFontSize,
    ].join(' ').toLowerCase();
    final generalTerms = [
      '通用语言中文英文国际化i18n',
      l10n.generalSection,
      l10n.language,
      l10n.chinese,
      l10n.english,
    ].join(' ').toLowerCase();
    final readingTerms = [
      '阅读动画翻页动效HTML WebView网页原生预见性返回手势',
      l10n.readingSection,
      l10n.reduceMotion,
      l10n.predictiveBack,
      l10n.webReader,
      l10n.nativeLayoutEngine,
    ].join(' ').toLowerCase();
    final debugTerms = [
      '调试帧率实时显示',
      l10n.debugSection,
      l10n.fpsDisplay,
    ].join(' ').toLowerCase();
    final storageTerms = [
      '存储缓存数据危险操作清空重置',
      l10n.storageSection,
      l10n.clearCache,
      l10n.clearApplicationData,
    ].join(' ').toLowerCase();
    final showDisplay = query.isEmpty || displayTerms.contains(query);
    final showGeneral = query.isEmpty || generalTerms.contains(query);
    final showReading = query.isEmpty || readingTerms.contains(query);
    final showDebug = query.isEmpty || debugTerms.contains(query);
    final showStorage = query.isEmpty || storageTerms.contains(query);
    final debugVisible = debug.enabled && showDebug;

    // 标题随页面滚动正常收起；搜索按钮固定在视口之外的浮层里
    // （与阅读页浮动头部一致），获得完全相同的 premium 按压效果。
    return ListenableBuilder(
      listenable: debug,
      builder: (context, _) => FloatingPageShell(
        searchHint: l10n.searchSettings,
        searchKey: _searchKey,
        onSearch: (value) => setState(() => _query = value),
        child: CustomScrollView(
          key: const PageStorageKey('settings-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: FloatingPageTitle(
                title: l10n.settingsTitle,
                subtitle: l10n.settingsSubtitle,
              ),
            ),
            if (showDisplay) ...[
              SliverToBoxAdapter(child: SectionLabel(l10n.displaySection)),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    _SettingSummaryTile(
                      icon: Icons.palette_outlined,
                      title: l10n.appColors,
                      status:
                          display.useDynamicColor &&
                              display.dynamicColorSupported
                          ? l10n.monetColors
                          : l10n.customColor,
                      onTap: () => _showColorSettings(display),
                    ),
                    const Divider(indent: 56),
                    _SettingSummaryTile(
                      icon: Icons.dark_mode_outlined,
                      title: l10n.nightMode,
                      status: _themePreferenceLabel(
                        context,
                        display.themePreference,
                      ),
                      onTap: () => _chooseThemePreference(display),
                    ),
                    const Divider(indent: 56),
                    _SettingSummaryTile(
                      icon: Icons.font_download_outlined,
                      title: l10n.sansSerifFont,
                      status: _fontFamilyLabel(context, display.appFontFamily),
                      onTap: () => _chooseFontFamily(display),
                    ),
                    const Divider(indent: 56),
                    _GlassSwitchTile(
                      value: false,
                      onChanged: null,
                      icon: Icons.water_drop_outlined,
                      title: l10n.inkMode,
                      subtitle: l10n.unavailable,
                      onDetails: () => _showSwitchDetail(
                        listenable: display,
                        icon: Icons.water_drop_outlined,
                        title: l10n.inkMode,
                        description: l10n.inkModeDescription,
                        value: () => false,
                        onChanged: null,
                        statusBuilder: (_) => l10n.unavailable,
                      ),
                    ),
                    const Divider(indent: 56),
                    _ContrastSettingTile(
                      icon: Icons.contrast_rounded,
                      title: l10n.contrast,
                      value: display.contrast,
                      onChanged: display.setContrast,
                      onDetails: () => _showContrastDetail(display),
                    ),
                    const Divider(indent: 56),
                    _SettingSummaryTile(
                      icon: Icons.text_fields_rounded,
                      title: l10n.softwareFontSize,
                      status: '${(display.appFontScale * 100).round()}%',
                      onTap: () => _chooseFontSize(display),
                    ),
                  ],
                ),
              ),
            ],
            if (showGeneral) ...[
              SliverToBoxAdapter(child: SectionLabel(l10n.generalSection)),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    _SettingSummaryTile(
                      icon: Icons.translate_rounded,
                      title: l10n.language,
                      status: _localePreferenceLabel(
                        context,
                        display.localePreference,
                      ),
                      onTap: () => _chooseLocalePreference(display),
                    ),
                  ],
                ),
              ),
            ],
            if (showReading) ...[
              SliverToBoxAdapter(child: SectionLabel(l10n.readingSection)),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    _GlassSwitchTile(
                      value: display.reduceMotion,
                      onChanged: display.setReduceMotion,
                      icon: Icons.motion_photos_off_outlined,
                      title: l10n.reduceMotion,
                      subtitle: display.reduceMotion
                          ? l10n.enabled
                          : l10n.disabled,
                      onDetails: () => _showSwitchDetail(
                        listenable: display,
                        icon: Icons.motion_photos_off_outlined,
                        title: l10n.reduceMotion,
                        description: l10n.reduceMotionDescription,
                        value: () => display.reduceMotion,
                        onChanged: display.setReduceMotion,
                      ),
                    ),
                    const Divider(indent: 56),
                    _GlassSwitchTile(
                      value: display.predictiveBackEnabled,
                      onChanged: display.setPredictiveBackEnabled,
                      icon: Icons.swipe_left_alt_rounded,
                      title: l10n.predictiveBack,
                      subtitle: display.predictiveBackEnabled
                          ? l10n.predictiveBack
                          : l10n.standardBack,
                      onDetails: () => _showSwitchDetail(
                        listenable: display,
                        icon: Icons.swipe_left_alt_rounded,
                        title: l10n.predictiveBack,
                        description: l10n.predictiveBackDescription,
                        value: () => display.predictiveBackEnabled,
                        onChanged: display.setPredictiveBackEnabled,
                        statusBuilder: (value) =>
                            value ? l10n.predictiveBack : l10n.standardBack,
                      ),
                    ),
                    const Divider(indent: 56),
                    _GlassSwitchTile(
                      value: display.htmlWebViewEnabled,
                      onChanged: display.setHtmlWebViewEnabled,
                      icon: Icons.language_rounded,
                      title: l10n.webReader,
                      subtitle: display.htmlWebViewEnabled
                          ? 'WebView'
                          : l10n.nativeFlutter,
                      onDetails: () => _showSwitchDetail(
                        listenable: display,
                        icon: Icons.language_rounded,
                        title: l10n.webReader,
                        description: l10n.webReaderDescription,
                        value: () => display.htmlWebViewEnabled,
                        onChanged: display.setHtmlWebViewEnabled,
                        statusBuilder: (value) =>
                            value ? 'WebView' : l10n.nativeFlutter,
                      ),
                    ),
                    const Divider(indent: 56),
                    _SettingSummaryTile(
                      icon: Icons.auto_awesome_motion_outlined,
                      title: l10n.nativeLayoutEngine,
                      status: display.htmlWebViewEnabled
                          ? l10n.markdownOnly
                          : l10n.markdownAndHtml,
                      onTap: () => _showNativeEngineDetail(display),
                    ),
                  ],
                ),
              ),
            ],
            if (showStorage) ...[
              SliverToBoxAdapter(child: SectionLabel(l10n.storageSection)),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    _SettingSummaryTile(
                      icon: Icons.cleaning_services_outlined,
                      title: l10n.clearCache,
                      status: l10n.clearCacheSummary,
                      onTap: _clearCache,
                    ),
                    const Divider(indent: 56),
                    _DangerSettingTile(
                      title: l10n.clearApplicationData,
                      status: l10n.clearApplicationDataSummary,
                      onTap: _clearApplicationData,
                    ),
                  ],
                ),
              ),
            ],
            if (debugVisible) ...[
              SliverToBoxAdapter(child: SectionLabel(l10n.debugSection)),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    _GlassSwitchTile(
                      value: debug.fpsBadgeVisible,
                      onChanged: (value) => debug.fpsBadgeVisible = value,
                      icon: Icons.speed_rounded,
                      title: l10n.fpsDisplay,
                      subtitle: debug.fpsBadgeVisible
                          ? l10n.showing
                          : l10n.hidden,
                      onDetails: () => _showSwitchDetail(
                        listenable: debug,
                        icon: Icons.speed_rounded,
                        title: l10n.fpsDisplay,
                        description: l10n.fpsDisplayDescription,
                        value: () => debug.fpsBadgeVisible,
                        onChanged: (value) => debug.fpsBadgeVisible = value,
                        statusBuilder: (value) =>
                            value ? l10n.showing : l10n.hidden,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!showDisplay &&
                !showGeneral &&
                !showReading &&
                !showStorage &&
                !debugVisible)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(l10n.noMatchingSettings)),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.version});

  final Future<String> version;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(l10n.aboutTagline),
          const SizedBox(height: 22),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(l10n.author),
            subtitle: const Text('Magneto'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.version),
            subtitle: FutureBuilder<String>(
              future: version,
              builder: (context, snapshot) {
                if (snapshot.hasData) return Text(snapshot.data!);
                if (snapshot.hasError) return Text(l10n.versionUnavailable);
                return Text(l10n.versionLoading);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingDetailSheet extends StatelessWidget {
  const _SettingDetailSheet({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    this.control,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final Widget? control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(
                  context.l10n.currentStatus,
                  style: theme.textTheme.labelLarge,
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (control != null) ...[const SizedBox(height: 8), control!],
        ],
      ),
    );
  }
}

class _FontScalePickerSheet extends StatefulWidget {
  const _FontScalePickerSheet({
    required this.scales,
    required this.initialIndex,
  });

  final List<double> scales;
  final int initialIndex;

  @override
  State<_FontScalePickerSheet> createState() => _FontScalePickerSheetState();
}

class _FontScalePickerSheetState extends State<_FontScalePickerSheet> {
  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return SizedBox(
      height: 380,
      child: Column(
        children: [
          Text(l10n.softwareFontSize, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.fontSizeDescription(
                (widget.scales[_selectedIndex] * 100).round(),
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              key: const ValueKey('app-font-size-wheel'),
              controller: _controller,
              itemExtent: 54,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              overAndUnderCenterOpacity: 0.48,
              onSelectedItemChanged: (value) {
                if (_selectedIndex == value) return;
                setState(() => _selectedIndex = value);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.scales.length,
                builder: (context, index) {
                  final selected = index == _selectedIndex;
                  final label = '${(widget.scales[index] * 100).round()}%';
                  return Center(
                    child: Semantics(
                      selected: selected,
                      label: label,
                      child: Material(
                        key: selected
                            ? const ValueKey('app-font-size-selected-option')
                            : ValueKey('app-font-size-option-$index'),
                        color: selected
                            ? colors.secondaryContainer
                            : Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        elevation: selected ? 1 : 0,
                        shadowColor: colors.shadow.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedSize(
                          duration: moyueMotionDuration(
                            context,
                            const Duration(milliseconds: 160),
                          ),
                          curve: Curves.easeOutCubic,
                          child: SizedBox(
                            width: selected ? 156 : 112,
                            height: 44,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  label,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: selected
                                        ? colors.onSecondaryContainer
                                        : colors.onSurfaceVariant,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: colors.onSecondaryContainer,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(context, widget.scales[_selectedIndex]),
                child: Text(l10n.apply),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerOption<T> {
  const _PickerOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final T value;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _OptionPickerSheet<T> extends StatelessWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.selected,
    required this.options,
  });

  final String title;
  final T selected;
  final List<_PickerOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: option.value == selected
                    ? colors.secondaryContainer
                    : colors.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: Icon(option.icon),
                  title: Text(option.title),
                  subtitle: Text(option.subtitle),
                  trailing: option.value == selected
                      ? Icon(Icons.check_circle_rounded, color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, option.value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FontFamilyPickerSheet extends StatefulWidget {
  const _FontFamilyPickerSheet({required this.initialValue});

  final MoyueFontFamily initialValue;

  @override
  State<_FontFamilyPickerSheet> createState() => _FontFamilyPickerSheetState();
}

class _FontFamilyPickerSheetState extends State<_FontFamilyPickerSheet> {
  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  static const _values = MoyueFontFamily.values;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _values.indexOf(widget.initialValue);
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(BuildContext context, MoyueFontFamily value) => switch (value) {
    MoyueFontFamily.system => context.l10n.systemSans,
    MoyueFontFamily.claude => context.l10n.claudeStyleSans,
    MoyueFontFamily.rounded => context.l10n.roundedSans,
  };

  String? _previewFamily(MoyueFontFamily value) => switch (value) {
    MoyueFontFamily.system => null,
    MoyueFontFamily.claude => 'serif',
    MoyueFontFamily.rounded => 'sans-serif-rounded',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return SizedBox(
      height: 380,
      child: Column(
        children: [
          Text(l10n.sansSerifFont, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            l10n.chooseSansSerif,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              key: const ValueKey('app-font-family-wheel'),
              controller: _controller,
              itemExtent: 58,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              overAndUnderCenterOpacity: 0.45,
              onSelectedItemChanged: (value) {
                if (_selectedIndex != value) {
                  setState(() => _selectedIndex = value);
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _values.length,
                builder: (context, index) {
                  final value = _values[index];
                  final selected = index == _selectedIndex;
                  return Center(
                    child: Material(
                      key: selected
                          ? const ValueKey('app-font-family-selected-option')
                          : ValueKey('app-font-family-option-$index'),
                      color: selected
                          ? colors.secondaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: selected ? 250 : 220,
                        height: 46,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _label(context, value),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: _previewFamily(value),
                                color: selected
                                    ? colors.onSecondaryContainer
                                    : colors.onSurfaceVariant,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: colors.onSecondaryContainer,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(context, _values[_selectedIndex]),
                child: Text(l10n.apply),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: AnimatedContainer(
        duration: moyueMotionDuration(
          context,
          const Duration(milliseconds: 160),
        ),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                color:
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : null,
      ),
    ),
  );
}

class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.customColor,
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              color,
              const Color(0xFFEF5350),
              const Color(0xFFFFCA28),
              const Color(0xFF66BB6A),
              const Color(0xFF42A5F5),
              const Color(0xFFAB47BC),
              color,
            ],
          ),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
      ),
    ),
  );
}

class _ColorWheelDialog extends StatefulWidget {
  const _ColorWheelDialog({required this.initialArgb});

  final int initialArgb;

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  late HSVColor _color;

  @override
  void initState() {
    super.initState();
    _color = HSVColor.fromColor(Color(widget.initialArgb));
  }

  void _updateWheel(Offset position, double size) {
    final center = Offset(size / 2, size / 2);
    final vector = position - center;
    final radius = size / 2;
    final saturation = (vector.distance / radius).clamp(0.0, 1.0);
    final radians = math.atan2(vector.dy, vector.dx);
    final hue = (radians * 180 / math.pi + 360) % 360;
    setState(() => _color = _color.withHue(hue).withSaturation(saturation));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.customAppColor),
    content: SizedBox(
      width: 292,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, 252.0);
              return Semantics(
                label: context.l10n.customAppColor,
                value: _color.toColor().toARGB32().toRadixString(16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _updateWheel(details.localPosition, size),
                  onPanStart: (details) =>
                      _updateWheel(details.localPosition, size),
                  onPanUpdate: (details) =>
                      _updateWheel(details.localPosition, size),
                  child: CustomPaint(
                    key: const ValueKey('custom-color-wheel'),
                    size: Size.square(size),
                    painter: _HsvColorWheelPainter(_color),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.brightness_low_rounded, size: 20),
              Expanded(
                child: Slider(
                  key: const ValueKey('custom-color-value-slider'),
                  value: _color.value,
                  min: 0.15,
                  onChanged: (value) =>
                      setState(() => _color = _color.withValue(value)),
                ),
              ),
              const Icon(Icons.brightness_high_rounded, size: 20),
            ],
          ),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: _color.toColor(),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _color.toColor().toARGB32()),
        child: Text(context.l10n.apply),
      ),
    ],
  );
}

class _HsvColorWheelPainter extends CustomPainter {
  const _HsvColorWheelPainter(this.color);

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(bounds),
    );
    if (color.value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 1 - color.value),
      );
    }

    final angle = color.hue * math.pi / 180;
    final selector =
        center +
        Offset(math.cos(angle), math.sin(angle)) * radius * color.saturation;
    canvas.drawCircle(
      selector,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white,
    );
    canvas.drawCircle(
      selector,
      12.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(_HsvColorWheelPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SettingSummaryTile extends StatelessWidget {
  const _SettingSummaryTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('$title-setting-summary'),
      minTileHeight: 66,
      leading: Icon(icon, size: 21),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

class _DangerSettingTile extends StatelessWidget {
  const _DangerSettingTile({
    required this.title,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return ListTile(
      key: ValueKey('$title-danger-setting'),
      minTileHeight: 66,
      leading: Icon(Icons.delete_forever_outlined, size: 21, color: error),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: error,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: error),
      onTap: onTap,
    );
  }
}

class _GlassSwitchTile extends StatelessWidget {
  const _GlassSwitchTile({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onDetails,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('$title-switch-row-touch-area'),
      minTileHeight: 80,
      horizontalTitleGap: 8,
      leading: Icon(icon, size: 21),
      title: Semantics(
        button: true,
        label: context.l10n.viewSettingDescription(title),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onDetails,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      trailing: _GlassSwitchControl(
        touchAreaKey: ValueKey('$title-switch-touch-area'),
        value: value,
        onChanged: onChanged,
        semanticLabel: title,
      ),
    );
  }
}

class _ContrastSettingTile extends StatelessWidget {
  const _ContrastSettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onDetails,
  });

  final IconData icon;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('contrast-setting-row-touch-area'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(icon, size: 21),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: context.l10n.viewSettingDescription(title),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onDetails,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const Spacer(),
                          Text(
                            '${(value * 100).round()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _ExpandedGlassSlider(
                  touchAreaKey: const ValueKey('contrast-slider-touch-area'),
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSwitchControl extends StatelessWidget {
  const _GlassSwitchControl({
    required this.touchAreaKey,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final Key touchAreaKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: onChanged != null,
    toggled: value,
    label: semanticLabel,
    child: SizedBox(
      key: touchAreaKey,
      width: 104,
      height: 56,
      child: IgnorePointer(
        ignoring: onChanged == null,
        child: Opacity(
          opacity: onChanged == null ? 0.45 : 1,
          child: Stack(
            // Keep the 104×56 hit target while placing the visible control
            // against its right edge. Previously centering it left a large
            // invisible margin on the right and made every switch look inset.
            alignment: Alignment.centerRight,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged?.call(!value),
                ),
              ),
              ExcludeSemantics(
                child: GlassSwitch(
                  value: value,
                  onChanged: onChanged ?? (_) {},
                  useOwnLayer: true,
                  quality: GlassQuality.premium,
                  settings: moyueGlassSettings(context),
                  activeColor: Theme.of(context).colorScheme.primary,
                  semanticLabel: semanticLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ExpandedGlassSlider extends StatelessWidget {
  const _ExpandedGlassSlider({
    required this.touchAreaKey,
    required this.value,
    required this.onChanged,
  });

  final Key touchAreaKey;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: touchAreaKey,
    height: 56,
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _update(details.localPosition.dx, constraints.maxWidth),
              onHorizontalDragUpdate: (details) =>
                  _update(details.localPosition.dx, constraints.maxWidth),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 5,
            height: 46,
            child: GlassSlider(
              value: value,
              onChanged: onChanged,
              useOwnLayer: true,
              quality: GlassQuality.premium,
              settings: moyueGlassSettings(context),
            ),
          ),
        ],
      ),
    ),
  );

  void _update(double dx, double width) {
    if (width <= 0) return;
    onChanged((dx / width).clamp(0.0, 1.0));
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Card(child: Column(children: children)),
  );
}

import 'package:flutter/widgets.dart';
import 'package:moyue_application/l10n/app_localizations.dart';

/// Stable boundary for future feature-level localization.
///
/// Screens can depend on this interface when translations are introduced,
/// without coupling feature code to the generated localization class.
abstract interface class MoyueI18n {
  String get appName;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('zh'));
}

typedef MoyueI18nResolver = MoyueI18n Function(BuildContext context);

extension MoyueI18nContext on BuildContext {
  AppLocalizations get l10n => MoyueI18n.of(this);
}

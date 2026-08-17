import 'package:flutter/widgets.dart';

/// Stable boundary for future feature-level localization.
///
/// Screens can depend on this interface when translations are introduced,
/// without coupling feature code to the generated localization class.
abstract interface class MoyueI18n {
  String get appName;
}

typedef MoyueI18nResolver = MoyueI18n Function(BuildContext context);

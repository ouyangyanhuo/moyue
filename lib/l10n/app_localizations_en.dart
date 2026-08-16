// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Moyue';

  @override
  String get homeTab => 'Home';

  @override
  String get libraryTab => 'Library';

  @override
  String get notesTab => 'Notes';

  @override
  String get profileTab => 'Profile';

  @override
  String get homeMessage => 'Welcome back to your reading space';

  @override
  String get libraryMessage => 'Your books will appear here';

  @override
  String get notesMessage => 'Capture thoughts from every page';

  @override
  String get profileMessage => 'Reading preferences and account';
}

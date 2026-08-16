// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '墨阅';

  @override
  String get homeTab => '首页';

  @override
  String get libraryTab => '书架';

  @override
  String get notesTab => '笔记';

  @override
  String get profileTab => '我的';

  @override
  String get homeMessage => '欢迎回到你的阅读空间';

  @override
  String get libraryMessage => '你的书籍会陈列在这里';

  @override
  String get notesMessage => '记录每一页带来的想法';

  @override
  String get profileMessage => '管理阅读偏好与账户';
}

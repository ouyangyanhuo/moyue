import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<Database> openIndexDatabase(String path, OpenDatabaseOptions options) =>
    databaseFactoryFfiWeb.openDatabase('moyue_index.db', options: options);

import 'package:sqflite/sqflite.dart';

Future<Database> openIndexDatabase(String path, OpenDatabaseOptions options) =>
    openDatabase(path, options: options);

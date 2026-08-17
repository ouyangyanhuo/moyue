import 'package:moyue_application/services/database/database_connection.dart';
import 'package:moyue_application/services/database/index_models.dart';
import 'package:sqflite/sqflite.dart';

class MoyueIndexDatabase {
  MoyueIndexDatabase(this.databasePath);
  final String databasePath;
  Database? _database;

  Future<Database> get _db async => _database ??= await openIndexDatabase(
    databasePath,
    OpenDatabaseOptions(
      version: 3,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
      onUpgrade: _upgrade,
    ),
  );

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL CHECK(category IN ('markdown','html','rss')),
        name TEXT NOT NULL,
        single INTEGER NOT NULL CHECK(single IN (0,1)),
        marker TEXT NOT NULL,
        relative_path TEXT NOT NULL UNIQUE,
        entry_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        kind TEXT NOT NULL CHECK(kind IN ('markdown','html','rss')),
        relative_path TEXT NOT NULL UNIQUE,
        is_primary INTEGER NOT NULL DEFAULT 0 CHECK(is_primary IN (0,1)),
        content_hash TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        source_url TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE resources (
        id TEXT PRIMARY KEY,
        folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
        document_id TEXT REFERENCES documents(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        relative_path TEXT NOT NULL UNIQUE,
        content_hash TEXT NOT NULL,
        size_bytes INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_documents_folder ON documents(folder_id)',
    );
    await db.execute(
      'CREATE INDEX idx_resources_folder ON resources(folder_id)',
    );
    await db.execute('CREATE INDEX idx_folders_category ON folders(category)');
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE documents ADD COLUMN source_url TEXT');
    }
    if (oldVersion < 3) {
      final columns = await db.rawQuery('PRAGMA table_info(documents)');
      final hasSourceUrl = columns.any(
        (column) => column['name'] == 'source_url',
      );
      if (!hasSourceUrl) {
        await db.execute('ALTER TABLE documents ADD COLUMN source_url TEXT');
      }
    }
  }

  Future<void> insertPackage({
    required FolderRecord folder,
    required List<DocumentRecord> documents,
    required List<ResourceRecord> resources,
    required Future<void> Function() writeFiles,
  }) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.insert('folders', folder.toMap());
      for (final document in documents) {
        await transaction.insert('documents', document.toMap());
      }
      for (final resource in resources) {
        await transaction.insert('resources', resource.toMap());
      }
      // SQL rows are staged first; a disk failure throws and rolls back them.
      await writeFiles();
    });
  }

  Future<List<Map<String, Object?>>> primaryDocuments() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT d.*, f.name AS folder_name, f.single, f.marker,
             f.relative_path AS folder_path,
             (SELECT COUNT(*) FROM documents dc
              WHERE dc.folder_id = f.id) AS document_count
      FROM documents d
      JOIN folders f ON f.id = d.folder_id
      WHERE d.kind IN ('markdown','html')
        AND (SELECT COUNT(*) FROM documents dc
             WHERE dc.folder_id = f.id) <= 2
      ORDER BY d.updated_at DESC
    ''');
  }

  Future<List<Map<String, Object?>>> libraryFolders() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT f.*, COUNT(d.id) AS document_count
      FROM folders f
      LEFT JOIN documents d
        ON d.folder_id = f.id AND d.kind IN ('markdown','html')
      WHERE f.category IN ('markdown','html')
      GROUP BY f.id
      HAVING f.marker = 'user-folder' OR COUNT(d.id) > 2
      ORDER BY f.updated_at DESC
    ''');
  }

  Future<List<Map<String, Object?>>> packageDocuments(String folderId) async {
    final db = await _db;
    return db.query('documents', where: 'folder_id = ?', whereArgs: [folderId]);
  }

  Future<List<Map<String, Object?>>> packageResources(String folderId) async {
    final db = await _db;
    return db.query('resources', where: 'folder_id = ?', whereArgs: [folderId]);
  }

  Future<List<Map<String, Object?>>> rssDocuments() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT d.*, f.name AS folder_name, f.marker,
             f.relative_path AS folder_path
      FROM documents d
      JOIN folders f ON f.id = d.folder_id
      WHERE d.kind = 'rss' AND d.is_primary = 1
      ORDER BY d.updated_at DESC
    ''');
  }

  Future<void> upsertRss({
    required FolderRecord folder,
    required DocumentRecord document,
    required Future<void> Function() writeFile,
  }) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.insert(
        'folders',
        folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.insert(
        'documents',
        document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await writeFile();
    });
  }

  Future<Map<String, Object?>?> folder(String folderId) async {
    final db = await _db;
    final rows = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateDocument(DocumentRecord document) async {
    final db = await _db;
    await db.update(
      'documents',
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
    await db.update(
      'folders',
      {
        'name': document.name,
        'updated_at': document.updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [document.folderId],
    );
  }

  Future<void> deleteFolder(String folderId) async {
    final db = await _db;
    await db.delete('folders', where: 'id = ?', whereArgs: [folderId]);
  }

  Future<Map<String, int>> audit() async {
    final db = await _db;
    final folderCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM folders'),
        ) ??
        0;
    final mismatches =
        Sqflite.firstIntValue(
          await db.rawQuery('''
      SELECT COUNT(*) FROM folders f
      WHERE f.entry_count != (
        SELECT COUNT(*) FROM documents d WHERE d.folder_id = f.id
      ) + (
        SELECT COUNT(*) FROM resources r WHERE r.folder_id = f.id
      )
    '''),
        ) ??
        0;
    return {'folders': folderCount, 'mismatches': mismatches};
  }
}

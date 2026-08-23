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
      version: 5,
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
        updated_at INTEGER NOT NULL,
        parent_id TEXT REFERENCES folders(id) ON DELETE CASCADE,
        logical_path TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        kind TEXT NOT NULL CHECK(kind IN ('markdown','html','rss')),
        relative_path TEXT NOT NULL UNIQUE,
        logical_path TEXT NOT NULL,
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
    await db.execute('CREATE INDEX idx_folders_parent ON folders(parent_id)');
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
    if (oldVersion < 4) {
      final columns = await db.rawQuery('PRAGMA table_info(documents)');
      final hasLogicalPath = columns.any(
        (column) => column['name'] == 'logical_path',
      );
      if (!hasLogicalPath) {
        await db.execute('ALTER TABLE documents ADD COLUMN logical_path TEXT');
      }
      await db.execute('''
        UPDATE documents
        SET logical_path = COALESCE(NULLIF(logical_path, ''),
          CASE kind
            WHEN 'markdown' THEN name || '.md'
            WHEN 'html' THEN name || '.html'
            ELSE name || '.xml'
          END)
      ''');
    }
    if (oldVersion < 5) {
      final columns = await db.rawQuery('PRAGMA table_info(folders)');
      if (!columns.any((column) => column['name'] == 'parent_id')) {
        await db.execute('ALTER TABLE folders ADD COLUMN parent_id TEXT');
      }
      if (!columns.any((column) => column['name'] == 'logical_path')) {
        await db.execute(
          "ALTER TABLE folders ADD COLUMN logical_path TEXT NOT NULL DEFAULT ''",
        );
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders(parent_id)',
      );
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

  Future<void> insertDocument({
    required DocumentRecord document,
    required Future<void> Function() writeFile,
  }) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.insert('documents', document.toMap());
      await transaction.rawUpdate(
        '''
        UPDATE folders
        SET entry_count = entry_count + 1, updated_at = ?
        WHERE id = ?
      ''',
        [document.updatedAt.millisecondsSinceEpoch, document.folderId],
      );
      await writeFile();
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
        AND f.marker != 'user-folder'
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
        AND f.parent_id IS NULL
      GROUP BY f.id
      HAVING f.marker = 'user-folder' OR COUNT(d.id) > 2
      ORDER BY f.updated_at DESC
    ''');
  }

  /// 返回根文件夹下所有显式创建的子目录。文档包原有的隐式目录仍由
  /// documents.logical_path 推导，两者会在界面层合并。
  Future<List<Map<String, Object?>>> nestedFolders(String rootId) async {
    final db = await _db;
    return db.rawQuery(
      '''
      WITH RECURSIVE descendants AS (
        SELECT * FROM folders WHERE parent_id = ?
        UNION ALL
        SELECT child.*
        FROM folders child
        JOIN descendants parent ON child.parent_id = parent.id
      )
      SELECT * FROM descendants ORDER BY logical_path COLLATE NOCASE
      ''',
      [rootId],
    );
  }

  Future<Map<String, Object?>?> nestedFolder(
    String rootId,
    String logicalPath,
  ) async {
    final rows = await nestedFolders(rootId);
    final matches = rows.where((row) => row['logical_path'] == logicalPath);
    return matches.isEmpty ? null : matches.first;
  }

  Future<bool> siblingFolderExists(String? parentId, String name) async {
    final db = await _db;
    final rows = parentId == null
        ? await db.query(
            'folders',
            columns: const ['id'],
            where: 'parent_id IS NULL AND name = ? COLLATE NOCASE',
            whereArgs: [name],
            limit: 1,
          )
        : await db.query(
            'folders',
            columns: const ['id'],
            where: 'parent_id = ? AND name = ? COLLATE NOCASE',
            whereArgs: [parentId, name],
            limit: 1,
          );
    return rows.isNotEmpty;
  }

  /// 批量写入或更新嵌套目录记录。[writeFolders] 与 SQL 变更处于同一
  /// 事务边界内，创建目标物理目录失败时不会留下半套层级索引。
  Future<void> upsertNestedFolders({
    required List<FolderRecord> folders,
    required Future<void> Function() writeFolders,
  }) async {
    final db = await _db;
    await db.transaction((transaction) async {
      for (final folder in folders) {
        final values = folder.toMap()..remove('id');
        final changed = await transaction.update(
          'folders',
          values,
          where: 'id = ?',
          whereArgs: [folder.id],
        );
        if (changed == 0) {
          await transaction.insert('folders', folder.toMap());
        }
      }
      await writeFolders();
    });
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
      where: 'id = ? AND single = 1',
      whereArgs: [document.folderId],
    );
  }

  /// 将文档索引切换到另一个文件夹。文件写入在同一事务回调中执行，
  /// 写盘失败时数据库修改会回滚。
  Future<void> moveDocument({
    required DocumentRecord document,
    required String sourceFolderId,
    required List<ResourceRecord> resources,
    required Future<void> Function() writeFiles,
  }) async {
    final db = await _db;
    await db.transaction((transaction) async {
      final oldResourceCount =
          Sqflite.firstIntValue(
            await transaction.rawQuery(
              'SELECT COUNT(*) FROM resources WHERE document_id = ?',
              [document.id],
            ),
          ) ??
          0;
      await transaction.update(
        'documents',
        document.toMap(),
        where: 'id = ?',
        whereArgs: [document.id],
      );
      await transaction.delete(
        'resources',
        where: 'document_id = ?',
        whereArgs: [document.id],
      );
      for (final resource in resources) {
        await transaction.insert('resources', resource.toMap());
      }
      await transaction.rawUpdate(
        '''
        UPDATE folders
        SET entry_count = MAX(0, entry_count - ?), updated_at = ?
        WHERE id = ?
        ''',
        [
          1 + oldResourceCount,
          document.updatedAt.millisecondsSinceEpoch,
          sourceFolderId,
        ],
      );
      await transaction.rawUpdate(
        '''
        UPDATE folders
        SET entry_count = entry_count + ?, updated_at = ?
        WHERE id = ?
        ''',
        [
          1 + resources.length,
          document.updatedAt.millisecondsSinceEpoch,
          document.folderId,
        ],
      );
      await writeFiles();
    });
  }

  /// 将一个未绑定文档的包资源切换到另一个根文件夹，并同步两侧计数。
  Future<void> moveResource({
    required ResourceRecord resource,
    required String sourceFolderId,
    required Future<void> Function() writeFile,
  }) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.update(
        'resources',
        resource.toMap(),
        where: 'id = ?',
        whereArgs: [resource.id],
      );
      if (sourceFolderId != resource.folderId) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await transaction.rawUpdate(
          '''
          UPDATE folders
          SET entry_count = MAX(0, entry_count - 1), updated_at = ?
          WHERE id = ?
          ''',
          [now, sourceFolderId],
        );
        await transaction.rawUpdate(
          '''
          UPDATE folders
          SET entry_count = entry_count + 1, updated_at = ?
          WHERE id = ?
          ''',
          [now, resource.folderId],
        );
      }
      await writeFile();
    });
  }

  Future<void> upsertResource(ResourceRecord resource) async {
    final db = await _db;
    await db.transaction((transaction) async {
      final previous = await transaction.query(
        'resources',
        columns: const ['id'],
        where: 'relative_path = ?',
        whereArgs: [resource.relativePath],
        limit: 1,
      );
      await transaction.insert(
        'resources',
        resource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (previous.isEmpty) {
        await transaction.rawUpdate(
          'UPDATE folders SET entry_count = entry_count + 1 WHERE id = ?',
          [resource.folderId],
        );
      }
    });
  }

  Future<void> deleteDocument(String documentId, String folderId) async {
    final db = await _db;
    await db.transaction((transaction) async {
      final resourceCount =
          Sqflite.firstIntValue(
            await transaction.rawQuery(
              'SELECT COUNT(*) FROM resources WHERE document_id = ?',
              [documentId],
            ),
          ) ??
          0;
      await transaction.delete(
        'resources',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      await transaction.delete(
        'documents',
        where: 'id = ?',
        whereArgs: [documentId],
      );
      await transaction.rawUpdate(
        '''
        UPDATE folders
        SET entry_count = MAX(0, entry_count - ?), updated_at = ?
        WHERE id = ?
      ''',
        [1 + resourceCount, DateTime.now().millisecondsSinceEpoch, folderId],
      );
    });
  }

  Future<void> renameFolder(String folderId, String name) async {
    final db = await _db;
    await db.update(
      'folders',
      {'name': name, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [folderId],
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

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

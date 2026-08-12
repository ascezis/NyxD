import 'package:sqlite3/sqlite3.dart';

const currentSchemaVersion = 4;

final class DatabaseMigrator {
  const DatabaseMigrator();

  void migrate(Database database) {
    final rows = database.select(
      'SELECT schema_version FROM vault_info WHERE id = 1',
    );
    if (rows.length != 1) {
      throw StateError('The vault schema metadata is missing.');
    }

    var version = rows.single['schema_version'] as int;
    if (version > currentSchemaVersion) {
      throw StateError('The vault was created by a newer NyxD version.');
    }

    while (version < currentSchemaVersion) {
      database.execute('BEGIN IMMEDIATE');
      try {
        switch (version) {
          case 1:
            _migrateFrom1To2(database);
            version = 2;
          case 2:
            _migrateFrom2To3(database);
            version = 3;
          case 3:
            _migrateFrom3To4(database);
            version = 4;
          default:
            throw StateError('No migration exists for schema $version.');
        }
        database.execute(
          'UPDATE vault_info SET schema_version = ? WHERE id = 1',
          [version],
        );
        database.execute('COMMIT');
      } catch (_) {
        database.execute('ROLLBACK');
        rethrow;
      }
    }
  }

  void _migrateFrom1To2(Database database) {
    database.execute(
      'CREATE TABLE entries ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'content TEXT NOT NULL, '
      'deleted_at INTEGER'
      ') STRICT',
    );
    database.execute(
      'CREATE INDEX entries_active_updated_idx '
      'ON entries (deleted_at, updated_at DESC)',
    );
  }

  void _migrateFrom2To3(Database database) {
    database.execute(
      'CREATE TABLE entry_tags ('
      'entry_id INTEGER NOT NULL, '
      'tag TEXT NOT NULL, '
      'PRIMARY KEY (entry_id, tag), '
      'FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE'
      ') STRICT',
    );
    database.execute('CREATE INDEX entry_tags_tag_idx ON entry_tags (tag)');
    final tagPattern = RegExp(
      r'(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]+)',
      unicode: true,
    );
    final statement = database.prepare(
      'INSERT OR IGNORE INTO entry_tags (entry_id, tag) VALUES (?, ?)',
    );
    try {
      for (final row in database.select('SELECT id, content FROM entries')) {
        for (final match in tagPattern.allMatches(row['content']! as String)) {
          statement.execute([row['id'], match.group(1)!.toLowerCase()]);
        }
      }
    } finally {
      statement.close();
    }
  }

  void _migrateFrom3To4(Database database) {
    database.execute(
      'ALTER TABLE entries ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
    );
  }
}

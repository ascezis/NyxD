import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/database/database_migrator.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates schema 1 to the current version idempotently', () {
    final database = sqlite3.openInMemory();
    addTearDown(database.close);
    database
      ..execute(
        'CREATE TABLE vault_info ('
        'id INTEGER PRIMARY KEY, schema_version INTEGER NOT NULL) STRICT',
      )
      ..execute('INSERT INTO vault_info VALUES (1, 1)');

    const migrator = DatabaseMigrator();
    migrator
      ..migrate(database)
      ..migrate(database);

    expect(
      database.select('SELECT schema_version FROM vault_info').single.values,
      [currentSchemaVersion],
    );
    expect(
      database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'entries'",
      ),
      hasLength(1),
    );
  });

  test('rejects a schema created by a newer application', () {
    final database = sqlite3.openInMemory();
    addTearDown(database.close);
    database
      ..execute(
        'CREATE TABLE vault_info ('
        'id INTEGER PRIMARY KEY, schema_version INTEGER NOT NULL) STRICT',
      )
      ..execute('INSERT INTO vault_info VALUES (1, 999)');

    expect(() => const DatabaseMigrator().migrate(database), throwsStateError);
  });
}

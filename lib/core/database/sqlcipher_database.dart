import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

final class SqlCipherDatabase {
  const SqlCipherDatabase();

  Database create({required String path, required Uint8List key}) {
    final database = _open(path: path, key: key);
    try {
      database.execute(
        'CREATE TABLE vault_info ('
        'id INTEGER PRIMARY KEY CHECK (id = 1), '
        'schema_version INTEGER NOT NULL'
        ') STRICT',
      );
      database.execute(
        'INSERT INTO vault_info (id, schema_version) VALUES (1, 1)',
      );
      return database;
    } catch (_) {
      database.close();
      rethrow;
    }
  }

  Database unlock({required String path, required Uint8List key}) {
    final database = _open(path: path, key: key);
    try {
      final rows = database.select(
        'SELECT schema_version FROM vault_info WHERE id = 1',
      );
      if (rows.length != 1) {
        throw StateError('The vault schema metadata is missing.');
      }
      return database;
    } catch (_) {
      database.close();
      rethrow;
    }
  }

  Database _open({required String path, required Uint8List key}) {
    final database = sqlite3.open(path);
    try {
      final keyHex = _hex(key);
      database.execute('PRAGMA key = "x\'$keyHex\'";');
      if (database.select('PRAGMA cipher_version;').isEmpty) {
        throw StateError('The bundled SQLite library is not SQLCipher.');
      }
      database.select('SELECT count(*) FROM sqlite_master;');
      return database;
    } catch (_) {
      database.close();
      rethrow;
    }
  }
}

String _hex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

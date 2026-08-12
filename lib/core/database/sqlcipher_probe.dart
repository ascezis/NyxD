import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

const _probeValue = 'nyxd-sqlcipher-probe';

final class SqlCipherProbe {
  const SqlCipherProbe();

  void create({required String path, required Uint8List key}) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }

    final database = _open(path: path, key: key);
    try {
      database
        ..execute(
          'CREATE TABLE probe ('
          'id INTEGER PRIMARY KEY, '
          'value TEXT NOT NULL'
          ') STRICT',
        )
        ..execute('INSERT INTO probe (id, value) VALUES (1, ?)', [_probeValue]);
    } finally {
      database.close();
    }
  }

  String read({required String path, required Uint8List key}) {
    final database = _open(path: path, key: key);
    try {
      final rows = database.select('SELECT value FROM probe WHERE id = 1');
      if (rows.length != 1) {
        throw StateError('SQLCipher probe row is missing.');
      }
      return rows.single['value'] as String;
    } finally {
      database.close();
    }
  }

  Database _open({required String path, required Uint8List key}) {
    final database = sqlite3.open(path);
    try {
      final keyHex = _hex(key);
      database.execute('PRAGMA key = "x\'$keyHex\'";');

      final cipherRows = database.select('PRAGMA cipher_version;');
      if (cipherRows.isEmpty) {
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

import 'dart:typed_data';

import 'package:nyxd/core/crypto/argon2_key_deriver.dart';
import 'package:sqlite3/sqlite3.dart';

final class VaultSession {
  VaultSession(this._database, this._key);

  Database? _database;
  Uint8List? _key;

  Database get database {
    return _database ?? (throw StateError('The vault session is closed.'));
  }

  void close() {
    _database?.close();
    _database = null;
    final key = _key;
    if (key != null) {
      zeroBytes(key);
      _key = null;
    }
  }
}

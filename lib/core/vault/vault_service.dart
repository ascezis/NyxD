import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nyxd/core/backup/backup_container.dart';
import 'package:nyxd/core/crypto/argon2_calibrator.dart';
import 'package:nyxd/core/crypto/argon2_key_deriver.dart';
import 'package:nyxd/core/crypto/secure_random.dart';
import 'package:nyxd/core/database/database_migrator.dart';
import 'package:nyxd/core/database/sqlcipher_database.dart';
import 'package:nyxd/core/vault/vault_exceptions.dart';
import 'package:nyxd/core/vault/vault_metadata.dart';
import 'package:nyxd/core/vault/vault_paths.dart';
import 'package:nyxd/core/vault/vault_session.dart';
import 'package:sqlite3/sqlite3.dart';

enum VaultStatus { uninitialized, locked, unlocked }

final class VaultService {
  VaultService({
    required this.paths,
    this.calibrator = const Argon2Calibrator(),
    this.metadataStore = const VaultMetadataStore(),
    this.sqlCipher = const SqlCipherDatabase(),
    this.migrator = const DatabaseMigrator(),
  });

  final VaultPaths paths;
  final Argon2Calibrator calibrator;
  final VaultMetadataStore metadataStore;
  final SqlCipherDatabase sqlCipher;
  final DatabaseMigrator migrator;

  VaultSession? _session;

  Database get database {
    final session = _session;
    if (session == null) {
      throw const VaultStateException('The vault is locked.');
    }
    return session.database;
  }

  VaultStatus get status {
    if (_session != null) {
      return VaultStatus.unlocked;
    }
    if (paths.database.existsSync() && paths.metadata.existsSync()) {
      return VaultStatus.locked;
    }
    return VaultStatus.uninitialized;
  }

  Future<void> createVault(String password) async {
    if (status != VaultStatus.uninitialized) {
      throw const VaultAlreadyExistsException();
    }
    paths.directory.createSync(recursive: true);
    final salt = generateSalt();
    Uint8List? key;
    try {
      final parameters = await calibrator.calibrate();
      key = await deriveKeyInBackground(
        password: password,
        salt: salt,
        parameters: parameters,
      );
      final database = sqlCipher.create(path: paths.database.path, key: key);
      migrator.migrate(database);
      _session = VaultSession(database, key);
      key = null;
      metadataStore.writeAtomically(
        paths.metadata,
        VaultMetadata(salt: salt, argon2: parameters),
      );
    } catch (_) {
      _session?.close();
      _session = null;
      _deleteIfExists(paths.database);
      _deleteIfExists(paths.metadata);
      rethrow;
    } finally {
      if (key != null) {
        zeroBytes(key);
      }
      zeroBytes(salt);
    }
  }

  Future<void> unlockVault(String password) async {
    if (status == VaultStatus.uninitialized) {
      throw const VaultNotFoundException();
    }
    if (status == VaultStatus.unlocked) {
      throw const VaultStateException('The vault is already unlocked.');
    }

    final metadata = metadataStore.read(paths.metadata);
    Uint8List? key;
    try {
      key = await deriveKeyInBackground(
        password: password,
        salt: metadata.salt,
        parameters: metadata.argon2,
      );
      final database = sqlCipher.unlock(path: paths.database.path, key: key);
      migrator.migrate(database);
      _session = VaultSession(database, key);
      key = null;
    } on SqliteException {
      throw const WrongPasswordException();
    } finally {
      if (key != null) {
        zeroBytes(key);
      }
      zeroBytes(metadata.salt);
    }
  }

  void lockVault() {
    _session?.close();
    _session = null;
  }

  Uint8List createBackup() {
    if (status != VaultStatus.unlocked) {
      throw const VaultStateException('The vault must be unlocked.');
    }
    final snapshot = File('${paths.directory.path}/nyxd.backup.tmp.db');
    _deleteIfExists(snapshot);
    try {
      final escaped = snapshot.path.replaceAll("'", "''");
      database.execute("VACUUM INTO '$escaped'");
      return BackupContainer.encode(
        BackupPayload(
          metadata: paths.metadata.readAsBytesSync(),
          database: snapshot.readAsBytesSync(),
        ),
      );
    } finally {
      _deleteIfExists(snapshot);
    }
  }

  Future<void> restoreBackup(Uint8List bytes, String password) async {
    final payload = BackupContainer.decode(bytes);
    final temporaryDatabase = File(
      '${paths.directory.path}/nyxd.restore.tmp.db',
    );
    final temporaryMetadata = File(
      '${paths.directory.path}/nyxd.restore.tmp.json',
    );
    _deleteIfExists(temporaryDatabase);
    _deleteIfExists(temporaryMetadata);
    temporaryDatabase.writeAsBytesSync(payload.database, flush: true);
    temporaryMetadata.writeAsBytesSync(payload.metadata, flush: true);

    Uint8List? key;
    VaultMetadata? candidateMetadata;
    try {
      candidateMetadata = VaultMetadata.fromJson(
        jsonDecode(utf8.decode(payload.metadata)) as Map<String, Object?>,
      );
      key = await deriveKeyInBackground(
        password: password,
        salt: candidateMetadata.salt,
        parameters: candidateMetadata.argon2,
      );
      final candidate = sqlCipher.unlock(
        path: temporaryDatabase.path,
        key: key,
      );
      try {
        migrator.migrate(candidate);
      } finally {
        candidate.close();
      }
    } catch (_) {
      _deleteIfExists(temporaryDatabase);
      _deleteIfExists(temporaryMetadata);
      rethrow;
    } finally {
      if (key != null) zeroBytes(key);
      if (candidateMetadata != null) zeroBytes(candidateMetadata.salt);
    }

    final oldDatabase = File('${paths.database.path}.restore-old');
    final oldMetadata = File('${paths.metadata.path}.restore-old');
    _deleteIfExists(oldDatabase);
    _deleteIfExists(oldMetadata);
    lockVault();
    try {
      paths.database.renameSync(oldDatabase.path);
      paths.metadata.renameSync(oldMetadata.path);
      temporaryDatabase.renameSync(paths.database.path);
      temporaryMetadata.renameSync(paths.metadata.path);
      await unlockVault(password);
      _deleteIfExists(oldDatabase);
      _deleteIfExists(oldMetadata);
    } catch (_) {
      lockVault();
      _deleteIfExists(paths.database);
      _deleteIfExists(paths.metadata);
      if (oldDatabase.existsSync()) oldDatabase.renameSync(paths.database.path);
      if (oldMetadata.existsSync()) oldMetadata.renameSync(paths.metadata.path);
      rethrow;
    } finally {
      _deleteIfExists(temporaryDatabase);
      _deleteIfExists(temporaryMetadata);
    }
  }

  void dispose() => lockVault();
}

void _deleteIfExists(File file) {
  if (file.existsSync()) {
    file.deleteSync();
  }
}

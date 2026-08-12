import 'dart:typed_data';

import 'package:nyxd/core/crypto/argon2_key_deriver.dart';
import 'package:nyxd/core/crypto/secure_random.dart';
import 'package:nyxd/core/database/sqlcipher_probe.dart';
import 'package:nyxd/features/crypto_probe/domain/crypto_probe_result.dart';
import 'package:path_provider/path_provider.dart';

final class CryptoProbeRunner {
  const CryptoProbeRunner({this.database = const SqlCipherProbe()});

  final SqlCipherProbe database;

  Future<CryptoProbeResult> run(String password) async {
    final directory = await getApplicationSupportDirectory();
    final databasePath = '${directory.path}/crypto-probe.db';
    final salt = generateSalt();
    final stopwatch = Stopwatch()..start();
    final key = await deriveKeyInBackground(password: password, salt: salt);
    stopwatch.stop();

    try {
      database.create(path: databasePath, key: key);
      final value = database.read(path: databasePath, key: key);
      final correctPasswordAccepted = value == 'nyxd-sqlcipher-probe';

      final wrongKey = await deriveKeyInBackground(
        password: '$password-wrong',
        salt: salt,
      );
      var wrongPasswordRejected = false;
      try {
        database.read(path: databasePath, key: wrongKey);
      } on Exception {
        wrongPasswordRejected = true;
      } finally {
        _zero(wrongKey);
      }

      return CryptoProbeResult(
        derivationDuration: stopwatch.elapsed,
        correctPasswordAccepted: correctPasswordAccepted,
        wrongPasswordRejected: wrongPasswordRejected,
        databasePath: databasePath,
      );
    } finally {
      _zero(key);
      _zero(salt);
    }
  }
}

void _zero(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);

import 'dart:typed_data';

import 'package:nyxd/core/crypto/argon2_key_deriver.dart';

final class Argon2Calibrator {
  const Argon2Calibrator({this.target = const Duration(milliseconds: 750)});

  final Duration target;

  Future<Argon2Parameters> calibrate() async {
    const probeMemoryKiB = 16 * 1024;
    const candidatesMiB = [16, 32, 64, 96, 128];
    final salt = Uint8List.fromList(List<int>.generate(16, (index) => index));
    final stopwatch = Stopwatch()..start();
    final key = await deriveKeyInBackground(
      password: 'NyxD calibration probe',
      salt: salt,
      parameters: const Argon2Parameters(
        memoryKiB: probeMemoryKiB,
        iterations: 2,
        parallelism: 2,
      ),
    );
    stopwatch.stop();
    zeroBytes(key);
    zeroBytes(salt);

    final elapsedMs = stopwatch.elapsedMilliseconds.clamp(1, 1 << 30);
    final estimatedMiB = (16 * target.inMilliseconds / elapsedMs).round();
    final selectedMiB = candidatesMiB.lastWhere(
      (candidate) => candidate <= estimatedMiB,
      orElse: () => candidatesMiB.first,
    );

    return Argon2Parameters(
      memoryKiB: selectedMiB * 1024,
      iterations: 2,
      parallelism: 2,
    );
  }
}

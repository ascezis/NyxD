import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nyxd/core/crypto/argon2_key_deriver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'benchmarks Dart Argon2id on a physical Android device',
    (tester) async {
      const candidatesMiB = [16, 32, 64, 96, 128];
      final salt = Uint8List.fromList(List<int>.generate(16, (index) => index));

      // This output is intentionally limited to a dedicated diagnostic test.
      // It is not compiled into or called by the production application.
      // ignore: avoid_print
      print('NYXD_ARGON2_BENCHMARK_BEGIN');
      try {
        for (final memoryMiB in candidatesMiB) {
          final parameters = Argon2Parameters(
            memoryKiB: memoryMiB * 1024,
            iterations: 2,
            parallelism: 2,
          );
          final warmup = await deriveKeyInBackground(
            password: 'NyxD benchmark password',
            salt: salt,
            parameters: parameters,
          );
          final expected = Uint8List.fromList(warmup);
          zeroBytes(warmup);

          final samples = <int>[];
          for (var run = 0; run < 3; run++) {
            final stopwatch = Stopwatch()..start();
            final key = await deriveKeyInBackground(
              password: 'NyxD benchmark password',
              salt: salt,
              parameters: parameters,
            );
            stopwatch.stop();
            expect(key, orderedEquals(expected));
            zeroBytes(key);
            samples.add(stopwatch.elapsedMilliseconds);
          }
          zeroBytes(expected);
          samples.sort();
          // ignore: avoid_print
          print(
            'NYXD_ARGON2 memoryMiB=$memoryMiB samplesMs=$samples '
            'medianMs=${samples[1]}',
          );
        }
      } finally {
        zeroBytes(salt);
      }
      // ignore: avoid_print
      print('NYXD_ARGON2_BENCHMARK_END');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

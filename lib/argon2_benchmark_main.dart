import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nyxd/core/crypto/argon2_key_deriver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BenchmarkApp());
  await _runBenchmark();
}

Future<void> _runBenchmark() async {
  const candidatesMiB = [16, 32, 64, 96, 128];
  final salt = Uint8List.fromList(List<int>.generate(16, (index) => index));
  // This file is a diagnostic entry point and is never used by lib/main.dart.
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
        if (!_sameBytes(key, expected)) {
          throw StateError('Argon2id returned inconsistent output.');
        }
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
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

class _BenchmarkApp extends StatelessWidget {
  const _BenchmarkApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Argon2id benchmark…'))),
    );
  }
}

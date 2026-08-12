import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

const derivedKeyLength = 32;

final class Argon2Parameters {
  const Argon2Parameters({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    this.keyLength = derivedKeyLength,
  });

  factory Argon2Parameters.fromJson(Map<String, Object?> json) {
    return Argon2Parameters(
      memoryKiB: json['memoryKiB']! as int,
      iterations: json['iterations']! as int,
      parallelism: json['parallelism']! as int,
      keyLength: json['keyLength']! as int,
    );
  }

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int keyLength;

  Map<String, int> toJson() => {
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'keyLength': keyLength,
  };
}

const defaultArgon2Parameters = Argon2Parameters(
  memoryKiB: 64 * 1024,
  iterations: 2,
  parallelism: 2,
);

String normalizeMasterPassword(String password) => unicode.nfkc(password);

Future<Uint8List> deriveKeyInBackground({
  required String password,
  required Uint8List salt,
  Argon2Parameters parameters = defaultArgon2Parameters,
}) {
  return Isolate.run(
    () => _deriveKey(password: password, salt: salt, parameters: parameters),
    debugName: 'nyxd-argon2id',
  );
}

Future<Uint8List> _deriveKey({
  required String password,
  required Uint8List salt,
  required Argon2Parameters parameters,
}) async {
  final normalizedPassword = normalizeMasterPassword(password);
  final passwordBytes = Uint8List.fromList(utf8.encode(normalizedPassword));
  try {
    final algorithm = Argon2id(
      parallelism: parameters.parallelism,
      memory: parameters.memoryKiB,
      iterations: parameters.iterations,
      hashLength: parameters.keyLength,
    );
    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKey(passwordBytes),
      nonce: salt,
    );
    return Uint8List.fromList(await secretKey.extractBytes());
  } finally {
    zeroBytes(passwordBytes);
  }
}

void zeroBytes(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);

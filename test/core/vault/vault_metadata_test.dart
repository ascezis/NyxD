import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/crypto/argon2_key_deriver.dart';
import 'package:nyxd/core/vault/vault_metadata.dart';

void main() {
  test('vault metadata round-trips without losing KDF parameters', () {
    final metadata = VaultMetadata(
      salt: Uint8List.fromList(List<int>.generate(16, (index) => index)),
      argon2: const Argon2Parameters(
        memoryKiB: 32768,
        iterations: 2,
        parallelism: 2,
      ),
    );

    final decoded = VaultMetadata.fromJson(
      (jsonDecode(jsonEncode(metadata.toJson())) as Map)
          .cast<String, Object?>(),
    );

    expect(decoded.formatVersion, 1);
    expect(decoded.salt, orderedEquals(metadata.salt));
    expect(decoded.argon2.memoryKiB, 32768);
    expect(decoded.argon2.iterations, 2);
    expect(decoded.argon2.parallelism, 2);
    expect(decoded.argon2.keyLength, 32);
  });
}

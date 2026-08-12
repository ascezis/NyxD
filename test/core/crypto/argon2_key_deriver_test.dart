import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/crypto/argon2_key_deriver.dart';

void main() {
  test('normalizes compatibility-equivalent passwords with NFKC', () {
    expect(normalizeMasterPassword('①'), '1');
    expect(normalizeMasterPassword('ＡＢＣ'), 'ABC');
  });

  test(
    'derivation is deterministic and produces a 256-bit key',
    () async {
      final salt = Uint8List.fromList(List<int>.generate(16, (index) => index));

      final first = await deriveKeyInBackground(
        password: 'password',
        salt: salt,
      );
      final second = await deriveKeyInBackground(
        password: 'password',
        salt: salt,
      );

      expect(first, hasLength(derivedKeyLength));
      expect(second, orderedEquals(first));

      first.fillRange(0, first.length, 0);
      second.fillRange(0, second.length, 0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

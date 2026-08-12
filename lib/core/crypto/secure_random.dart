import 'dart:math';
import 'dart:typed_data';

Uint8List generateSalt([int length = 16]) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/backup/backup_container.dart';

void main() {
  test(
    'backup container round-trips metadata and encrypted database bytes',
    () {
      final encoded = BackupContainer.encode(
        BackupPayload(
          metadata: Uint8List.fromList([1, 2, 3]),
          database: Uint8List.fromList([4, 5, 6, 7]),
        ),
      );

      final decoded = BackupContainer.decode(encoded);
      expect(decoded.metadata, [1, 2, 3]);
      expect(decoded.database, [4, 5, 6, 7]);
    },
  );

  test('invalid and truncated containers are rejected', () {
    expect(
      () => BackupContainer.decode(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    final valid = BackupContainer.encode(
      BackupPayload(
        metadata: Uint8List.fromList([1]),
        database: Uint8List.fromList([2]),
      ),
    );
    expect(
      () => BackupContainer.decode(Uint8List.sublistView(valid, 0, 12)),
      throwsFormatException,
    );
  });
}

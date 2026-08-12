import 'dart:convert';
import 'dart:typed_data';

final class BackupPayload {
  const BackupPayload({required this.metadata, required this.database});
  final Uint8List metadata;
  final Uint8List database;
}

abstract final class BackupContainer {
  static final _magic = ascii.encode('NYXDBK01');

  static Uint8List encode(BackupPayload payload) {
    final output = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(_uint32(payload.metadata.length))
      ..add(payload.metadata)
      ..add(payload.database);
    return output.takeBytes();
  }

  static BackupPayload decode(Uint8List bytes) {
    if (bytes.length < 12 || !_hasMagic(bytes)) {
      throw const FormatException('Это не резервная копия NyxD.');
    }
    final metadataLength = ByteData.sublistView(bytes, 8, 12).getUint32(0);
    if (metadataLength <= 0 || 12 + metadataLength >= bytes.length) {
      throw const FormatException('Резервная копия повреждена.');
    }
    return BackupPayload(
      metadata: Uint8List.sublistView(bytes, 12, 12 + metadataLength),
      database: Uint8List.sublistView(bytes, 12 + metadataLength),
    );
  }

  static Uint8List _uint32(int value) {
    final data = ByteData(4)..setUint32(0, value);
    return data.buffer.asUint8List();
  }

  static bool _hasMagic(Uint8List bytes) {
    for (var index = 0; index < _magic.length; index++) {
      if (bytes[index] != _magic[index]) return false;
    }
    return true;
  }
}

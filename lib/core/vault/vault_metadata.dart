import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nyxd/core/crypto/argon2_key_deriver.dart';

final class VaultMetadata {
  const VaultMetadata({
    required this.salt,
    required this.argon2,
    this.formatVersion = 1,
  });

  factory VaultMetadata.fromJson(Map<String, Object?> json) {
    final version = json['formatVersion']! as int;
    if (version != 1) {
      throw FormatException('Unsupported vault format version: $version');
    }
    return VaultMetadata(
      formatVersion: version,
      salt: base64Decode(json['salt']! as String),
      argon2: Argon2Parameters.fromJson(
        (json['argon2']! as Map).cast<String, Object?>(),
      ),
    );
  }

  final int formatVersion;
  final Uint8List salt;
  final Argon2Parameters argon2;

  Map<String, Object> toJson() => {
    'formatVersion': formatVersion,
    'salt': base64Encode(salt),
    'argon2': argon2.toJson(),
  };
}

final class VaultMetadataStore {
  const VaultMetadataStore();

  VaultMetadata read(File file) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    return VaultMetadata.fromJson(json);
  }

  void writeAtomically(File file, VaultMetadata metadata) {
    final temporary = File('${file.path}.tmp');
    temporary.writeAsStringSync(jsonEncode(metadata.toJson()), flush: true);
    temporary.renameSync(file.path);
  }
}

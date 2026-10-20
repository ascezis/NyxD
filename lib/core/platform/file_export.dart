import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';

bool get _isDesktop => switch (defaultTargetPlatform) {
  TargetPlatform.windows ||
  TargetPlatform.linux ||
  TargetPlatform.macOS => true,
  _ => false,
};

/// Replaces characters that are not allowed in file names on Windows (and are
/// problematic elsewhere) and keeps the name at a sane length.
String sanitizeFileName(String name, {String fallback = 'note'}) {
  final cleaned = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (cleaned.isEmpty) return fallback;
  return cleaned.length > 80 ? cleaned.substring(0, 80).trimRight() : cleaned;
}

/// Saves [bytes] to a file chosen by the user.
///
/// Returns `true` when the file was written and `false` when the user
/// cancelled the dialog. On desktop a native "Save as" dialog is used; on
/// mobile the platform file saver is used.
Future<bool> saveBytesToFile({
  required Uint8List bytes,
  required String fileName,
  String typeLabel = 'File',
  List<String> extensions = const [],
}) async {
  if (!_isDesktop) {
    await FlutterFileSaver().writeFileAsBytes(bytes: bytes, fileName: fileName);
    return true;
  }
  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: extensions.isEmpty
        ? const []
        : [XTypeGroup(label: typeLabel, extensions: extensions)],
  );
  if (location == null) return false;
  var path = location.path;
  if (extensions.isNotEmpty) {
    final lower = path.toLowerCase();
    final hasExtension = extensions.any((e) => lower.endsWith('.$e'));
    if (!hasExtension) path = '$path.${extensions.first}';
  }
  await File(path).writeAsBytes(bytes, flush: true);
  return true;
}

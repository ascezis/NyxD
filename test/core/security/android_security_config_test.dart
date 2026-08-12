import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest disables backups and defines extraction rules', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('Android activity enables FLAG_SECURE', () {
    final activity = File(
      'android/app/src/main/kotlin/dev/nyxd/nyxd/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
  });

  test('backup rules exclude all application data domains', () {
    for (final path in [
      'android/app/src/main/res/xml/backup_rules.xml',
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ]) {
      final rules = File(path).readAsStringSync();
      expect(rules, contains('domain="root" path="."'));
      expect(rules, contains('domain="file" path="."'));
      expect(rules, contains('domain="database" path="."'));
      expect(rules, contains('domain="sharedpref" path="."'));
      expect(rules, contains('domain="external" path="."'));
    }
  });
}

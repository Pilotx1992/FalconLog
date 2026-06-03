import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;

  setUp(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  test('allowBackup is explicitly false', () {
    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('fullBackupContent is disabled', () {
    expect(manifest, contains('android:fullBackupContent="false"'));
  });

  test('data extraction rules are referenced', () {
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('data extraction rules exclude app data', () {
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<exclude'));
  });
}

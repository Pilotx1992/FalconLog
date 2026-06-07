import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/backup/models/key_file_format.dart';
import 'package:falconlog/backup/utils/cloud_key_recovery.dart';

void main() {
  test('cloud key file round-trip supports new-device recovery', () {
    final masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i));

    final keyFile = KeyFileFormatNew.fromKey(
      userEmail: 'pilot@example.com',
      googleId: 'google-account-123',
      deviceId: 'Pixel-Test',
      masterKey: masterKey,
    );

    expect(keyFile.validateChecksum(), isTrue);
    expect(keyFile.belongsToUser('pilot@example.com', 'google-account-123'),
        isTrue);
    expect(keyFile.getMasterKey(), masterKey);

    final jsonRoundTrip = KeyFileFormatNew.fromJson(keyFile.toJson());
    expect(jsonRoundTrip.getMasterKey(), masterKey);
    expect(base64Decode(jsonRoundTrip.keyBytes).length, 32);
  });

  test('portable recovery documents Drive key file name', () {
    expect(CloudKeyRecovery.keyFileName, 'falconlog_backup_keys.json');
    expect(
      CloudKeyRecovery.portableRecoverySummary,
      contains('same Google account'),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/utils/backup_payload_codec.dart';
import 'package:falconlog/backup/utils/restore_dispatch.dart';

void main() {
  test('local restore route does not use Google Drive dispatch', () {
    final target = BackupInfo(
      id: 'local-1',
      metadataId: 'local-meta-1',
      fileName: 'falconlog_backup_1.crypt14',
      provider: BackupProvider.local,
      createdAt: DateTime.utc(2025, 1, 1),
      sizeBytes: 100,
      logsCount: 0,
      localPath: '/nonexistent/path/backup.crypt14',
    );

    expect(RestoreDispatch.routeForProvider(target.provider),
        RestoreRoute.local);
    expect(RestoreDispatch.isLocalBackup(target), isTrue);
    expect(RestoreDispatch.isCloudBackup(target), isFalse);
  });

  test('validatePayload runs before any Hive mutation would occur', () {
    final error = BackupPayloadCodec.validatePayload({
      'manifest': {
        'backup_format_version': '99.0',
        'schema_version': '4.0',
      },
      'flight_logs': {},
    });

    expect(
      error,
      'This backup was created by a newer app version. Please update the app first.',
    );
  });
}

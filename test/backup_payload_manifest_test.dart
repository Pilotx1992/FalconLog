import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/backup/models/backup_payload_manifest.dart';
import 'package:falconlog/backup/utils/pre_restore_snapshot_crypto.dart';
import 'package:falconlog/services/encryption_service.dart';

void main() {
  group('backup_format_version', () {
    test('current version is accepted', () {
      final error = BackupPayloadManifest.validateBackupFormatVersion({
        'backup_format_version': BackupPayloadManifest.currentBackupFormatVersion,
      });
      expect(error, isNull);
      expect(
        BackupPayloadManifest.isLegacyManifest({
          'backup_format_version': '2.0',
        }),
        isFalse,
      );
    });

    test('missing version is treated as legacy', () {
      expect(
        BackupPayloadManifest.validateBackupFormatVersion({
          'schema_version': '3.0',
        }),
        isNull,
      );
      expect(
        BackupPayloadManifest.isLegacyManifest({'schema_version': '3.0'}),
        isTrue,
      );
      expect(BackupPayloadManifest.isLegacyManifest(null), isTrue);
    });

    test('newer unsupported version fails safely', () {
      final error = BackupPayloadManifest.validateBackupFormatVersion({
        'backup_format_version': '99.0',
      });
      expect(error, BackupPayloadManifest.newerVersionErrorMessage);
    });
  });

  test('manifest hash is deterministic for same flight logs', () {
    final logs = {
      'b-id': {'id': 'b-id', 'date': '2025-02-01'},
      'a-id': {'id': 'a-id', 'date': '2025-01-01'},
    };

    final hash1 = BackupPayloadManifest.computePayloadHash(logs);
    final hash2 = BackupPayloadManifest.computePayloadHash(logs);
    expect(hash1, hash2);
  });

  test('manifest verifies matching payload when not legacy', () {
    final logs = {
      'a-id': {'id': 'a-id', 'date': '2025-01-01'},
    };
    final manifest = BackupPayloadManifest(
      backupId: 'test-backup',
      schemaVersion: BackupPayloadManifest.currentSchemaVersion,
      backupFormatVersion: '1.0',
      appVersion: '1.0.0',
      createdAt: DateTime.utc(2025, 6, 1),
      provider: 'googleDrive',
      location: 'cloud',
      payloadSha256: BackupPayloadManifest.computePayloadHash(logs),
      flightLogCount: 1,
    );

    expect(manifest.verifyPayload(flightLogs: logs), isTrue);
    expect(
      manifest.verifyPayload(
        flightLogs: {'other': {'id': 'x'}},
      ),
      isFalse,
    );
  });

  group('PreRestoreSnapshotCrypto', () {
    test('returns error when device key is unavailable', () async {
      final result = await PreRestoreSnapshotCrypto.encryptPayload(
        payload: {'manifest': {}, 'flight_logs': {}},
        snapshotId: 'snap-1',
        encryptionService: EncryptionService(),
        getDeviceKey: () async => null,
      );

      expect(result.bytes, isNull);
      expect(result.error, isNotNull);
      expect(result.error, contains('Device encryption key'));
    });

    test('encrypted snapshot uses dedicated file suffix', () {
      expect(PreRestoreSnapshotCrypto.fileSuffix, '.pre_restore.crypt14');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/utils/restore_dispatch.dart';

void main() {
  group('RestoreDispatch', () {
    test('routes Google Drive to googleDrive path', () {
      expect(
        RestoreDispatch.routeForProvider(BackupProvider.googleDrive),
        RestoreRoute.googleDrive,
      );
    });

    test('routes Local to local path', () {
      expect(
        RestoreDispatch.routeForProvider(BackupProvider.local),
        RestoreRoute.local,
      );
    });

    test('Firebase restore fails explicitly', () {
      expect(
        RestoreDispatch.routeForProvider(BackupProvider.firebase),
        RestoreRoute.unsupported,
      );
      expect(
        RestoreDispatch.unsupportedMessage(BackupProvider.firebase),
        contains('not supported'),
      );
    });

    test('local vs cloud backup detection', () {
      final local = BackupInfo(
        id: 'local-1',
        metadataId: 'local-1',
        localPath: '/data/local_backups/backup.crypt14',
        fileName: 'backup.crypt14',
        createdAt: _fixedDate,
        sizeBytes: 1024,
        logsCount: 3,
        provider: BackupProvider.local,
      );
      final cloud = BackupInfo(
        id: 'drive-abc',
        metadataId: 'hive-1',
        driveFileId: 'drive-abc',
        fileName: 'falconlog_backup_1.crypt14',
        createdAt: _fixedDate,
        sizeBytes: 2048,
        logsCount: 5,
        provider: BackupProvider.googleDrive,
      );

      expect(RestoreDispatch.isLocalBackup(local), isTrue);
      expect(RestoreDispatch.isCloudBackup(cloud), isTrue);
      expect(RestoreDispatch.isLocalBackup(cloud), isFalse);
    });
  });

  group('BackupInfo.fromMetadata', () {
    test('maps local metadata with path', () {
      final metadata = BackupMetadata(
        id: 'meta-local-1',
        fileName: 'falconlog_backup_local.crypt14',
        location: BackupLocation.local,
        createdAt: _fixedDate,
        sizeBytes: 512,
        flightLogsCount: 2,
        checksum: 'unknown',
        localPath: '/app/local_backups/falconlog_backup_local.crypt14',
        deviceId: 'device',
      );

      final info = BackupInfo.fromMetadata(metadata);
      expect(info.provider, BackupProvider.local);
      expect(info.localPath, metadata.localPath);
      expect(info.metadataId, 'meta-local-1');
    });

    test('maps cloud metadata with drive file id', () {
      final metadata = BackupMetadata(
        id: 'meta-cloud-1',
        fileName: 'falconlog_backup_cloud.crypt14',
        location: BackupLocation.cloud,
        createdAt: _fixedDate,
        sizeBytes: 1024,
        flightLogsCount: 4,
        checksum: 'unknown',
        driveFileId: 'drive-file-99',
        deviceId: 'user@example.com',
      );

      final info = BackupInfo.fromMetadata(metadata);
      expect(info.provider, BackupProvider.googleDrive);
      expect(info.driveFileId, 'drive-file-99');
      expect(info.id, 'drive-file-99');
    });
  });
}

final _fixedDate = DateTime(2025, 6, 15, 12, 0);

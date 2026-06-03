import 'dart:io';

import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_constants.dart';
import 'package:falconlog/core/services/hive_initialization_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = BackupService();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'falconlog_drive_cleanup_',
    );
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    await HiveInitializationService.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service.setCancelRequestedForTesting(false);
    service.setBackupInProgressForTesting(false);
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.clear();
  });

  BackupMetadata cloudMetadata({
    required String id,
    required String driveFileId,
  }) {
    return BackupMetadata(
      id: id,
      fileName: 'FLBKUP_20260601_120000.crypt14',
      location: BackupLocation.cloud,
      createdAt: DateTime.utc(2026, 6, 1, 12),
      sizeBytes: 128,
      flightLogsCount: 1,
      checksum: 'unknown',
      driveFileId: driveFileId,
      deviceId: 'test-device',
    );
  }

  test('drive_upload_is_deleted_when_metadata_save_fails', () async {
    final deleted = <String>[];

    final ok = await service.completeGoogleDriveBackupAfterUploadForTesting(
      uploadedDriveFileId: 'new-drive-file',
      getFileInfo: (id) async => drive.File(id: id, size: '128'),
      saveMetadata: () async => null,
      recordSuccessfulBackup: () async => fail('success must not be recorded'),
      deleteUploadedDriveFile: (id) async {
        deleted.add(id);
        return true;
      },
    );

    expect(ok, isFalse);
    expect(deleted, ['new-drive-file']);
  });

  test('drive_upload_is_deleted_when_success_recording_fails', () async {
    final deleted = <String>[];
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.put(
      'new-metadata',
      cloudMetadata(id: 'new-metadata', driveFileId: 'new-drive-file'),
    );

    final ok = await service.completeGoogleDriveBackupAfterUploadForTesting(
      uploadedDriveFileId: 'new-drive-file',
      getFileInfo: (id) async => drive.File(id: id, size: '128'),
      saveMetadata: () async => 'new-metadata',
      recordSuccessfulBackup: () async {
        throw StateError('prefs write failed');
      },
      deleteUploadedDriveFile: (id) async {
        deleted.add(id);
        return true;
      },
    );

    expect(ok, isFalse);
    expect(deleted, ['new-drive-file']);
    expect(box.containsKey('new-metadata'), isFalse);
  });

  test('drive_upload_is_deleted_when_cancelled_after_upload_before_success',
      () async {
    final deleted = <String>[];
    service.setCancelRequestedForTesting(true);

    await expectLater(
      service.completeGoogleDriveBackupAfterUploadForTesting(
        uploadedDriveFileId: 'new-drive-file',
        getFileInfo: (id) async => drive.File(id: id, size: '128'),
        saveMetadata: () async => fail('metadata must not be saved'),
        recordSuccessfulBackup: () async =>
            fail('success must not be recorded'),
        deleteUploadedDriveFile: (id) async {
          deleted.add(id);
          return true;
        },
      ),
      throwsA(isA<BackupCancelledException>()),
    );

    expect(deleted, ['new-drive-file']);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
      isNull,
    );
  });

  test('failed_post_upload_backup_does_not_update_last_backup_time', () async {
    await service.completeGoogleDriveBackupAfterUploadForTesting(
      uploadedDriveFileId: 'new-drive-file',
      getFileInfo: (id) async => drive.File(id: id, size: '128'),
      saveMetadata: () async => null,
      recordSuccessfulBackup: () async => fail('success must not be recorded'),
      deleteUploadedDriveFile: (_) async => true,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
      isNull,
    );
  });

  test('orphan_cleanup_does_not_delete_existing_valid_backups', () async {
    final deleted = <String>[];
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.put(
      'old-metadata',
      cloudMetadata(id: 'old-metadata', driveFileId: 'old-valid-drive-file'),
    );

    final ok = await service.completeGoogleDriveBackupAfterUploadForTesting(
      uploadedDriveFileId: 'new-drive-file',
      getFileInfo: (id) async => drive.File(id: id, size: '128'),
      saveMetadata: () async => null,
      recordSuccessfulBackup: () async => fail('success must not be recorded'),
      deleteUploadedDriveFile: (id) async {
        deleted.add(id);
        return true;
      },
    );

    expect(ok, isFalse);
    expect(deleted, ['new-drive-file']);
    expect(box.containsKey('old-metadata'), isTrue);
  });

  test('cleanup_failure_preserves_backup_failure_result', () async {
    final ok = await service.completeGoogleDriveBackupAfterUploadForTesting(
      uploadedDriveFileId: 'new-drive-file',
      getFileInfo: (id) async => drive.File(id: id, size: '128'),
      saveMetadata: () async => null,
      recordSuccessfulBackup: () async => fail('success must not be recorded'),
      deleteUploadedDriveFile: (_) async {
        throw StateError('drive delete failed');
      },
    );

    expect(ok, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
      isNull,
    );
  });

  test('successful_backup_keeps_uploaded_drive_file', () async {
    final deleted = <String>[];
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.put(
      'new-metadata',
      cloudMetadata(id: 'new-metadata', driveFileId: 'new-drive-file'),
    );

    final ok = await service.completeGoogleDriveBackupAfterUploadForTesting(
      uploadedDriveFileId: 'new-drive-file',
      getFileInfo: (id) async => drive.File(id: id, size: '128'),
      saveMetadata: () async => 'new-metadata',
      recordSuccessfulBackup: service.recordSuccessfulBackupForTesting,
      deleteUploadedDriveFile: (id) async {
        deleted.add(id);
        return true;
      },
    );

    expect(ok, isTrue);
    expect(deleted, isEmpty);
    expect(box.containsKey('new-metadata'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
      isNotNull,
    );
  });
}

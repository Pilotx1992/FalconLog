import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/models/backup_provider_enum.dart'
    hide BackupStatus;
import 'package:falconlog/backup/models/backup_status.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_constants.dart';
import 'package:falconlog/backup/utils/backup_provider_preferences.dart';
import 'package:falconlog/core/services/hive_initialization_service.dart';

void main() {
  late Directory tempDir;
  final service = BackupService();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('falcon_backup_cancel_');
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
    SharedPreferences.setMockInitialValues({
      backupSelectedProviderKey: BackupProvider.local.name,
    });
    service.setCancelRequestedForTesting(false);
    service.setBackupInProgressForTesting(false);
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.clear();
  });

  BackupMetadata localMetadata({
    required String id,
    required String localPath,
    required DateTime createdAt,
  }) =>
      BackupMetadata(
        id: id,
        fileName: 'falconlog_backup_test.crypt14',
        location: BackupLocation.local,
        createdAt: createdAt,
        sizeBytes: 10,
        flightLogsCount: 1,
        checksum: 'unknown',
        localPath: localPath,
        deviceId: 'test',
      );

  test('cancelled backup does not set last_backup_time', () async {
    service.setCancelRequestedForTesting(true);

    await expectLater(
      service.recordSuccessfulBackupForTesting(),
      throwsA(isA<BackupCancelledException>()),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
      isNull,
    );
  });

  test('rollback removes metadata row for cancelled backup', () async {
    const cancelledId = 'cancelled-backup-id';
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.put(
      cancelledId,
      localMetadata(
        id: cancelledId,
        localPath: '${tempDir.path}/ghost.crypt14',
        createdAt: DateTime.now(),
      ),
    );

    await service.rollbackCancelledBackupArtifactsForTesting(
      metadataBackupId: cancelledId,
    );

    expect(box.containsKey(cancelledId), isFalse);
  });

  test('cancelled local backup does not leave latest valid metadata', () async {
    final validPath = '${tempDir.path}/valid_backup.crypt14';
    await File(validPath).writeAsBytes([1, 2, 3]);

    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    final now = DateTime.now();
    await box.put(
      'orphan-cancelled',
      localMetadata(
        id: 'orphan-cancelled',
        localPath: '${tempDir.path}/missing.crypt14',
        createdAt: now,
      ),
    );
    await box.put(
      'valid-backup',
      localMetadata(
        id: 'valid-backup',
        localPath: validPath,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    );

    final latest = await service.findExistingBackup(
      provider: BackupProvider.local,
    );

    expect(latest, isNotNull);
    expect(latest!.id, 'valid-backup');
  });

  test('successful backup still records last_backup_time', () async {
    service.setCancelRequestedForTesting(false);
    await service.recordSuccessfulBackupForTesting();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
      isNotNull,
    );
  });

  test('cancelled backup does not broadcast completed progress', () {
    service.setBackupInProgressForTesting(true);
    service.setCancelRequestedForTesting(true);

    service.updateProgressForTesting(
      100,
      BackupStatus.completed,
      'Backup completed successfully!',
    );

    expect(service.currentProgress.isCompleted, isFalse);
    expect(service.currentProgress.backupStatus, isNot(BackupStatus.completed));
  });

  test('orphan local metadata without file is ignored even if delete fails',
      () async {
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.put(
      'orphan-only',
      localMetadata(
        id: 'orphan-only',
        localPath: '${tempDir.path}/does_not_exist.crypt14',
        createdAt: DateTime.now(),
      ),
    );

    final latest = await service.findExistingBackup(
      provider: BackupProvider.local,
    );

    expect(latest, isNull);
    expect(await service.deleteBackupMetadataForTesting('missing-id'), isFalse);
  });
}

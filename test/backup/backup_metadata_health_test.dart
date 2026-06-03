import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_operation_history.dart';
import 'package:falconlog/backup/utils/backup_operation_lock.dart';
import 'package:falconlog/core/services/hive_initialization_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = BackupService();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'falconlog_metadata_health_',
    );
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory' ||
          call.method == 'getApplicationSupportDirectory') {
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
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.clear();
    await BackupOperationHistory.clearForTesting();
  });

  test('storesRealChecksum', () async {
    final encryptedBytes = utf8.encode('encrypted-backup-envelope');
    final checksum = sha256.convert(encryptedBytes).toString();

    final savedId = await service.saveBackupMetadataForTesting(
      backupId: 'backup-real-checksum',
      fileName: 'FLBKUP_20260601_120000.crypt14',
      originalSize: 42,
      encryptedSize: encryptedBytes.length,
      flightLogsCount: 3,
      checksum: checksum,
      location: BackupLocation.local,
      localPath: '${tempDir.path}/FLBKUP_20260601_120000.crypt14',
    );

    expect(savedId, 'backup-real-checksum');
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    final metadata = box.get('backup-real-checksum');
    expect(metadata, isNotNull);
    expect(metadata!.checksum, checksum);
    expect(metadata.checksum, isNot('unknown'));
    expect(metadata.health, BackupHealth.verified);
    expect(metadata.lastVerified, isNotNull);
  });

  test('recordsCancelledFailedVerifiedStates', () async {
    final startedAt = DateTime.utc(2026, 6, 1, 12);

    await BackupOperationHistory.record(
      operationType: BackupOperationType.manualBackup,
      state: BackupOperationResultState.verified,
      startedAt: startedAt,
      message: 'Backup completed successfully.',
    );
    await BackupOperationHistory.record(
      operationType: BackupOperationType.scheduledBackup,
      state: BackupOperationResultState.failed,
      startedAt: startedAt,
      message: 'Backup failed',
      error: 'Failed for pilot@example.com at C:/Users/X/private/file.crypt14',
    );
    await BackupOperationHistory.record(
      operationType: BackupOperationType.restore,
      state: BackupOperationResultState.cancelled,
      startedAt: startedAt,
      message: 'Restore cancelled',
    );

    final records = await BackupOperationHistory.readAll();
    expect(
      records.map((record) => record.state),
      [
        BackupOperationResultState.verified,
        BackupOperationResultState.failed,
        BackupOperationResultState.cancelled,
      ],
    );
    expect(records[1].redactedError, isNot(contains('pilot@example.com')));
    expect(records[1].redactedError, isNot(contains('C:/Users/X')));
  });
}

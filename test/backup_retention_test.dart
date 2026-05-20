import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/models/backup_provider_enum.dart'
    hide BackupStatus;
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_filename.dart';
import 'package:falconlog/backup/utils/backup_provider_preferences.dart';
import 'package:falconlog/core/services/hive_initialization_service.dart';

void main() {
  late Directory tempDir;
  final service = BackupService();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('falcon_backup_retention_');
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
        fileName: BackupFilename.generate(at: createdAt),
        location: BackupLocation.local,
        createdAt: createdAt,
        sizeBytes: 10,
        flightLogsCount: 1,
        checksum: 'unknown',
        localPath: localPath,
        deviceId: 'test',
      );

  group('local retention', () {
    test('after successful backup prune keeps only latest local backup',
        () async {
      final olderPath = '${tempDir.path}/older.crypt14';
      final newerPath = '${tempDir.path}/newer.crypt14';
      await File(olderPath).writeAsBytes([1]);
      await File(newerPath).writeAsBytes([2]);

      final now = DateTime.now();
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      await box.put(
        'older-backup',
        localMetadata(
          id: 'older-backup',
          localPath: olderPath,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      );
      await box.put(
        'newer-backup',
        localMetadata(
          id: 'newer-backup',
          localPath: newerPath,
          createdAt: now,
        ),
      );

      await service.pruneLocalBackupsForTesting(
        retainBackupId: 'newer-backup',
      );

      expect(await File(olderPath).exists(), isFalse);
      expect(await File(newerPath).exists(), isTrue);
      expect(box.containsKey('older-backup'), isFalse);
      expect(box.containsKey('newer-backup'), isTrue);

      final latest = await service.findExistingBackup(
        provider: BackupProvider.local,
      );
      expect(latest?.id, 'newer-backup');
    });

    test('failed backup path does not prune when prune is not invoked',
        () async {
      final oldPath = '${tempDir.path}/only_valid.crypt14';
      await File(oldPath).writeAsBytes([9]);

      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      await box.put(
        'only-backup',
        localMetadata(
          id: 'only-backup',
          localPath: oldPath,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      // Simulates failure before metadata save / prune — no prune call.
      final latest = await service.findExistingBackup(
        provider: BackupProvider.local,
      );

      expect(await File(oldPath).exists(), isTrue);
      expect(latest?.id, 'only-backup');
    });
  });

  group('Drive retention selection', () {
    test('keeps only newest Drive backup id', () {
      final files = [
        drive.File(id: 'newest', modifiedTime: DateTime(2026, 5, 20, 12)),
        drive.File(id: 'older', modifiedTime: DateTime(2026, 5, 19, 12)),
        drive.File(id: 'oldest', modifiedTime: DateTime(2026, 5, 18, 12)),
      ];

      final toDelete = BackupService.selectDriveFileIdsToPrune(
        files,
        keep: BackupFilename.keepLatestSuccessfulCount,
        alwaysRetainDriveFileId: 'newest',
      );

      expect(toDelete, ['older', 'oldest']);
    });

    test('always retains explicit new upload id even if list order differs',
        () {
      final files = [
        drive.File(
            id: 'stale-newer-looking', modifiedTime: DateTime(2026, 5, 21)),
        drive.File(
            id: 'actual-new-upload', modifiedTime: DateTime(2026, 5, 20)),
      ];

      final toDelete = BackupService.selectDriveFileIdsToPrune(
        files,
        keep: BackupFilename.keepLatestSuccessfulCount,
        alwaysRetainDriveFileId: 'actual-new-upload',
      );

      expect(toDelete, ['stale-newer-looking']);
      expect(toDelete, isNot(contains('actual-new-upload')));
    });
  });

  group('cancel and orphan discovery', () {
    test('cancelled orphan metadata is not treated as latest', () async {
      final validPath = '${tempDir.path}/valid.crypt14';
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

      expect(latest?.id, 'valid-backup');
    });
  });
}

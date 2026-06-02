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
import 'package:falconlog/backup/utils/backup_account_identity_guard.dart';
import 'package:falconlog/backup/utils/backup_filename.dart';
import 'package:falconlog/backup/utils/backup_provider_preferences.dart';
import 'package:falconlog/backup/utils/drive_backup_discovery.dart';
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

  drive.File driveBackupFile(
    String id,
    DateTime modifiedTime, {
    Map<String, String>? appProperties,
  }) =>
      drive.File(
        id: id,
        name: BackupFilename.generate(at: modifiedTime),
        modifiedTime: modifiedTime,
        appProperties: appProperties,
      );

  BackupMetadata cloudMetadata({
    required String id,
    required String driveFileId,
    required DateTime createdAt,
    BackupHealth health = BackupHealth.verified,
  }) =>
      BackupMetadata(
        id: id,
        fileName: BackupFilename.generate(at: createdAt),
        location: BackupLocation.cloud,
        createdAt: createdAt,
        sizeBytes: 10,
        flightLogsCount: 1,
        checksum: 'sha256-$id',
        driveFileId: driveFileId,
        health: health,
        lastVerified: health == BackupHealth.verified ? createdAt : null,
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
        keep: 1,
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
        driveBackupFile('newest', DateTime(2026, 5, 20, 12)),
        driveBackupFile('older', DateTime(2026, 5, 19, 12)),
        driveBackupFile('oldest', DateTime(2026, 5, 18, 12)),
      ];
      final storedByDriveId = {
        for (final file in files)
          file.id!: cloudMetadata(
            id: 'metadata-${file.id}',
            driveFileId: file.id!,
            createdAt: file.modifiedTime!,
          ),
      };

      final toDelete = BackupService.selectDriveFileIdsToPrune(
        files,
        keep: 1,
        alwaysRetainDriveFileId: 'newest',
        storedByDriveId: storedByDriveId,
      );

      expect(toDelete, ['older', 'oldest']);
    });

    test('always retains explicit new upload id even if list order differs',
        () {
      final files = [
        driveBackupFile('stale-newer-looking', DateTime(2026, 5, 21)),
        driveBackupFile('actual-new-upload', DateTime(2026, 5, 20)),
      ];
      final storedByDriveId = {
        for (final file in files)
          file.id!: cloudMetadata(
            id: 'metadata-${file.id}',
            driveFileId: file.id!,
            createdAt: file.modifiedTime!,
          ),
      };

      final toDelete = BackupService.selectDriveFileIdsToPrune(
        files,
        keep: 1,
        alwaysRetainDriveFileId: 'actual-new-upload',
        storedByDriveId: storedByDriveId,
      );

      expect(toDelete, ['stale-newer-looking']);
      expect(toDelete, isNot(contains('actual-new-upload')));
    });

    test('unverified newer Drive files do not consume retention slots', () {
      final files = [
        driveBackupFile('unknown-newest', DateTime(2026, 5, 22)),
        driveBackupFile('verified-newer', DateTime(2026, 5, 21)),
        driveBackupFile('verified-older', DateTime(2026, 5, 20)),
        driveBackupFile('verified-oldest', DateTime(2026, 5, 19)),
      ];
      final storedByDriveId = {
        'verified-newer': cloudMetadata(
          id: 'metadata-newer',
          driveFileId: 'verified-newer',
          createdAt: DateTime(2026, 5, 21),
        ),
        'verified-older': cloudMetadata(
          id: 'metadata-older',
          driveFileId: 'verified-older',
          createdAt: DateTime(2026, 5, 20),
        ),
        'verified-oldest': cloudMetadata(
          id: 'metadata-oldest',
          driveFileId: 'verified-oldest',
          createdAt: DateTime(2026, 5, 19),
        ),
      };

      final toDelete = BackupService.selectDriveFileIdsToPrune(
        files,
        keep: 2,
        storedByDriveId: storedByDriveId,
      );

      expect(toDelete, ['verified-oldest']);
      expect(toDelete, isNot(contains('verified-older')));
      expect(toDelete, isNot(contains('unknown-newest')));
    });

    test('failed and cancelled Drive metadata are not retention candidates',
        () {
      final files = [
        driveBackupFile('failed-newer', DateTime(2026, 5, 22)),
        driveBackupFile('cancelled-newer', DateTime(2026, 5, 21)),
        driveBackupFile('verified-older', DateTime(2026, 5, 20)),
      ];
      final storedByDriveId = {
        'failed-newer': cloudMetadata(
          id: 'metadata-failed',
          driveFileId: 'failed-newer',
          createdAt: DateTime(2026, 5, 22),
          health: BackupHealth.failed,
        ),
        'cancelled-newer': cloudMetadata(
          id: 'metadata-cancelled',
          driveFileId: 'cancelled-newer',
          createdAt: DateTime(2026, 5, 21),
          health: BackupHealth.cancelled,
        ),
        'verified-older': cloudMetadata(
          id: 'metadata-verified',
          driveFileId: 'verified-older',
          createdAt: DateTime(2026, 5, 20),
        ),
      };

      final toDelete = BackupService.selectDriveFileIdsToPrune(
        files,
        keep: 1,
        storedByDriveId: storedByDriveId,
      );

      expect(toDelete, isEmpty);
    });

    test('legacy BackupHealth byte 2 remains restore-ineligible', () async {
      final legacyByte2Health = _backupHealthFromHiveByte(2);
      expect(legacyByte2Health, BackupHealth.failed);

      final files = [
        driveBackupFile('legacy-byte-2-newer', DateTime(2026, 5, 22)),
        driveBackupFile('verified-older', DateTime(2026, 5, 20)),
      ];

      final result = await service.resolveLatestRestorableDriveBackupForTesting(
        backupFiles: files,
        storedByDriveId: {
          'legacy-byte-2-newer': cloudMetadata(
            id: 'metadata-legacy-byte-2',
            driveFileId: 'legacy-byte-2-newer',
            createdAt: DateTime(2026, 5, 22),
            health: legacyByte2Health,
          ),
          'verified-older': cloudMetadata(
            id: 'metadata-verified',
            driveFileId: 'verified-older',
            createdAt: DateTime(2026, 5, 20),
          ),
        },
        identitySnapshot: const BackupAccountIdentitySnapshot(
          firebaseEmail: 'pilot@example.com',
          firebaseProviderIds: ['google.com'],
          googleDriveEmail: 'pilot@example.com',
          keyOwnerEmail: 'pilot@example.com',
        ),
        downloadFile: (_) async {
          fail('Stored metadata path should not need Drive download.');
        },
      );

      expect(result, isNotNull);
      expect(result!.driveFileId, 'verified-older');
      expect(result.health, BackupHealth.verified);
    });

    test(
        'verified Drive appProperties can prove success without local metadata',
        () {
      final files = [
        driveBackupFile(
          'verified-by-app-properties',
          DateTime(2026, 5, 21),
          appProperties: DriveBackupDiscovery.verifiedBackupAppProperties(
            backupId: 'backup-app-properties',
            checksum: 'sha256-app-properties',
          ),
        ),
        driveBackupFile('verified-by-metadata', DateTime(2026, 5, 20)),
      ];

      final toDelete = BackupService.selectDriveFileIdsToPrune(
        files,
        keep: 1,
        storedByDriveId: {
          'verified-by-metadata': cloudMetadata(
            id: 'metadata-verified',
            driveFileId: 'verified-by-metadata',
            createdAt: DateTime(2026, 5, 20),
          ),
        },
      );

      expect(toDelete, ['verified-by-metadata']);
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

BackupHealth _backupHealthFromHiveByte(int byte) {
  return BackupHealthAdapter().read(_SingleByteReader(byte));
}

class _SingleByteReader implements BinaryReader {
  _SingleByteReader(this._byte);

  final int _byte;
  var _used = false;

  @override
  int get availableBytes => _used ? 0 : 1;

  @override
  int get usedBytes => _used ? 1 : 0;

  @override
  int readByte() {
    if (_used) {
      throw RangeError('No unread bytes remain.');
    }
    _used = true;
    return _byte;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

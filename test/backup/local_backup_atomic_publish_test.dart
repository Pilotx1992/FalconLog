import 'dart:io';

import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_constants.dart';
import 'package:falconlog/core/services/hive_initialization_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

late Directory _testAppDir;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = BackupService();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'falconlog_local_atomic_',
    );
    _testAppDir = tempDir;
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
    service.resetPublishTestingHooks();
    service.setCancelRequestedForTesting(false);
    service.setBackupInProgressForTesting(false);
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.clear();
    final dir = _backupDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  tearDown(() {
    service.resetPublishTestingHooks();
  });

  test('local_backup_writes_temp_file_before_final_file', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    String? tempPathSeenBeforeRename;

    service.beforeLocalBackupRenameForTesting = (tempFile, finalFile) async {
      tempPathSeenBeforeRename = tempFile.path;
      expect(await tempFile.exists(), isTrue);
      expect(await tempFile.readAsBytes(), bytes);
      expect(await finalFile.exists(), isFalse);
      expect(finalFile.path.endsWith('.crypt14'), isTrue);
    };

    final finalPath = await service.writeLocalBackupFileForTesting(
      fileName: 'FLBKUP_atomic_success.crypt14',
      content: bytes,
    );

    expect(finalPath, isNotNull);
    expect(await File(finalPath!).readAsBytes(), bytes);
    expect(tempPathSeenBeforeRename, isNotNull);
    expect(await File(tempPathSeenBeforeRename!).exists(), isFalse);
  });

  test('local_backup_deletes_temp_file_when_write_fails', () async {
    service.localBackupTempWriterForTesting = (tempFile, content) async {
      await tempFile.writeAsBytes([99], flush: true);
      throw StateError('simulated disk write failure');
    };

    final finalPath = await service.writeLocalBackupFileForTesting(
      fileName: 'FLBKUP_write_failure.crypt14',
      content: Uint8List.fromList([1, 2, 3]),
    );

    expect(finalPath, isNull);
    expect(await _allBackupFiles(), isEmpty);
  });

  test('local_backup_deletes_temp_when_verification_fails', () async {
    service.localBackupTempWriterForTesting = (tempFile, content) async {
      await tempFile.writeAsBytes([1], flush: true);
    };

    final finalPath = await service.writeLocalBackupFileForTesting(
      fileName: 'FLBKUP_size_mismatch.crypt14',
      content: Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(finalPath, isNull);
    expect(await _allBackupFiles(), isEmpty);
  });

  test('local_backup_does_not_create_final_file_when_rename_fails', () async {
    service.beforeLocalBackupRenameForTesting = (tempFile, finalFile) async {
      await tempFile.delete();
    };

    final finalPath = await service.writeLocalBackupFileForTesting(
      fileName: 'FLBKUP_rename_failure.crypt14',
      content: Uint8List.fromList([1, 2, 3]),
    );

    expect(finalPath, isNull);
    expect(await _allBackupFiles(), isEmpty);
  });

  test('local_backup_deletes_new_final_file_when_metadata_save_fails',
      () async {
    final finalPath = await service.writeLocalBackupFileForTesting(
      fileName: 'FLBKUP_metadata_failure.crypt14',
      content: Uint8List.fromList([1, 2, 3]),
    );
    expect(finalPath, isNotNull);
    expect(await File(finalPath!).exists(), isTrue);

    final ok = await service.completeLocalBackupAfterWriteForTesting(
      writtenLocalPath: finalPath,
      saveMetadata: () async => null,
      recordSuccessfulBackup: () async => fail('success must not be recorded'),
    );

    expect(ok, isFalse);
    expect(await File(finalPath).exists(), isFalse);
  });

  test('local_backup_does_not_delete_existing_valid_backups', () async {
    final dir = _backupDir();
    await dir.create(recursive: true);
    final existing = File(p.join(dir.path, 'FLBKUP_existing_valid.crypt14'));
    await existing.writeAsBytes([7, 7, 7], flush: true);

    final finalPath = await service.writeLocalBackupFileForTesting(
      fileName: 'FLBKUP_new_failed.crypt14',
      content: Uint8List.fromList([1, 2, 3]),
    );
    expect(finalPath, isNotNull);

    final ok = await service.completeLocalBackupAfterWriteForTesting(
      writtenLocalPath: finalPath!,
      saveMetadata: () async => null,
      recordSuccessfulBackup: () async => fail('success must not be recorded'),
    );

    expect(ok, isFalse);
    expect(await File(finalPath).exists(), isFalse);
    expect(await existing.exists(), isTrue);
    expect(await existing.readAsBytes(), [7, 7, 7]);
  });

  test(
      'cancelled_local_backup_before_finalize_cleans_file_and_skips_last_backup',
      () async {
    final writtenPath = await service.writeLocalBackupFileForTesting(
      fileName: 'FLBKUP_cancelled_finalize.crypt14',
      content: Uint8List.fromList([1, 2, 3, 4]),
    );
    expect(writtenPath, isNotNull);
    final publishedPath = writtenPath!;

    service.setCancelRequestedForTesting(true);

    await expectLater(
      service.completeLocalBackupAfterWriteForTesting(
        writtenLocalPath: publishedPath,
        saveMetadata: () async => 'should-not-save',
        recordSuccessfulBackup: service.recordSuccessfulBackupForTesting,
      ),
      throwsA(isA<BackupCancelledException>()),
    );

    expect(await File(publishedPath).exists(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
      isNull,
    );
  });

  test('successful_local_backup_keeps_final_file_and_metadata', () async {
    final finalPath = await service.writeLocalBackupFileForTesting(
      fileName: 'FLBKUP_successful_local.crypt14',
      content: Uint8List.fromList([1, 2, 3, 4]),
    );
    expect(finalPath, isNotNull);

    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );

    final ok = await service.completeLocalBackupAfterWriteForTesting(
      writtenLocalPath: finalPath!,
      saveMetadata: () async {
        await box.put(
          'local-metadata',
          BackupMetadata(
            id: 'local-metadata',
            fileName: 'FLBKUP_successful_local.crypt14',
            location: BackupLocation.local,
            createdAt: DateTime.utc(2026, 6, 1, 12),
            sizeBytes: 4,
            flightLogsCount: 1,
            checksum: 'unknown',
            localPath: finalPath,
            deviceId: 'test-device',
          ),
        );
        return 'local-metadata';
      },
      recordSuccessfulBackup: service.recordSuccessfulBackupForTesting,
    );

    expect(ok, isTrue);
    expect(await File(finalPath).exists(), isTrue);
    expect(box.get('local-metadata')?.localPath, finalPath);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
      isNotNull,
    );
  });
}

Directory _backupDir() {
  return Directory(
    p.join(
      _testAppDir.path,
      BackupConstants.localBackupsFolder,
    ),
  );
}

Future<List<FileSystemEntity>> _allBackupFiles() async {
  final dir = _backupDir();
  if (!await dir.exists()) return [];
  return dir.list().toList();
}

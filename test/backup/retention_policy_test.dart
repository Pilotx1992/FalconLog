import 'dart:io';

import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_filename.dart';
import 'package:falconlog/core/services/hive_initialization_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = BackupService();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'falconlog_retention_policy_',
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
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    await box.clear();
    final dir = Directory(p.join(tempDir.path, 'policy_files'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  });

  test('keepsMultipleVerifiedBackups', () async {
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    final now = DateTime.utc(2026, 6, 1, 12);

    for (var i = 0; i < BackupFilename.keepLatestSuccessfulCount + 1; i++) {
      final id = 'verified-$i';
      final path = await _writeBackupFile(tempDir, '$id.crypt14', [i]);
      await box.put(
        id,
        _metadata(
          id: id,
          localPath: path,
          createdAt: now.subtract(Duration(minutes: i)),
          health: BackupHealth.verified,
        ),
      );
    }

    await service.pruneLocalBackupsForTesting();

    expect(box.length, BackupFilename.keepLatestSuccessfulCount);
    expect(box.containsKey('verified-0'), isTrue);
    expect(box.containsKey('verified-4'), isTrue);
    expect(box.containsKey('verified-5'), isFalse);
  });

  test('failedBackupDoesNotPruneGoodBackups', () async {
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    final now = DateTime.utc(2026, 6, 1, 12);

    for (var i = 0; i < BackupFilename.keepLatestSuccessfulCount; i++) {
      final id = 'good-$i';
      final path = await _writeBackupFile(tempDir, '$id.crypt14', [i]);
      await box.put(
        id,
        _metadata(
          id: id,
          localPath: path,
          createdAt: now.subtract(Duration(minutes: i)),
          health: BackupHealth.verified,
        ),
      );
    }

    final failedPath = await _writeBackupFile(tempDir, 'failed.crypt14', [99]);
    await box.put(
      'failed-new',
      _metadata(
        id: 'failed-new',
        localPath: failedPath,
        createdAt: now.add(const Duration(minutes: 1)),
        health: BackupHealth.failed,
      ),
    );

    await service.pruneLocalBackupsForTesting(retainBackupId: 'failed-new');

    for (var i = 0; i < BackupFilename.keepLatestSuccessfulCount; i++) {
      expect(box.containsKey('good-$i'), isTrue);
      expect(await File(box.get('good-$i')!.localPath!).exists(), isTrue);
    }
  });

  test('pruneRunsOnlyAfterSuccessfulVerification', () async {
    final box = await HiveInitializationService.openBox<BackupMetadata>(
      'backupMetadata',
    );
    final now = DateTime.utc(2026, 6, 1, 12);

    for (var i = 0; i < BackupFilename.keepLatestSuccessfulCount; i++) {
      final id = 'verified-good-$i';
      final path = await _writeBackupFile(tempDir, '$id.crypt14', [i]);
      await box.put(
        id,
        _metadata(
          id: id,
          localPath: path,
          createdAt: now.subtract(Duration(minutes: i)),
          health: BackupHealth.verified,
        ),
      );
    }

    final partialPath =
        await _writeBackupFile(tempDir, 'partial-unverified.crypt14', [7]);
    await box.put(
      'partial-new',
      _metadata(
        id: 'partial-new',
        localPath: partialPath,
        createdAt: now.add(const Duration(minutes: 1)),
        health: BackupHealth.unverified,
      ),
    );

    await service.pruneLocalBackupsForTesting(retainBackupId: 'partial-new');

    for (var i = 0; i < BackupFilename.keepLatestSuccessfulCount; i++) {
      expect(box.containsKey('verified-good-$i'), isTrue);
    }
  });
}

Future<String> _writeBackupFile(
  Directory tempDir,
  String fileName,
  List<int> bytes,
) async {
  final file = File(p.join(tempDir.path, 'policy_files', fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

BackupMetadata _metadata({
  required String id,
  required String localPath,
  required DateTime createdAt,
  required BackupHealth health,
}) {
  return BackupMetadata(
    id: id,
    fileName: BackupFilename.generate(at: createdAt),
    location: BackupLocation.local,
    createdAt: createdAt,
    sizeBytes: 1,
    flightLogsCount: 1,
    checksum: 'sha256-$id',
    localPath: localPath,
    health: health,
    lastVerified: health == BackupHealth.verified ? createdAt : null,
    deviceId: 'test-device',
  );
}

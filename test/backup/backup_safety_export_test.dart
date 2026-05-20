import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/models/backup_provider_enum.dart'
    hide BackupStatus;
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_constants.dart';
import 'package:falconlog/backup/utils/backup_filename.dart';
import 'package:falconlog/backup/utils/backup_provider_preferences.dart';
import 'package:falconlog/backup/utils/backup_safety_export_helper.dart';
import 'package:falconlog/core/services/hive_initialization_service.dart';

void main() {
  late Directory tempDir;
  final service = BackupService();

  Uint8List validEncryptedBackupBytes() {
    final payload = {
      'encrypted': true,
      'version': '1',
      'backup_id': 'export-test-backup',
      'data': base64.encode(List<int>.filled(32, 7)),
      'iv': base64.encode(List<int>.filled(12, 3)),
      'tag': base64.encode(List<int>.filled(16, 9)),
    };
    return Uint8List.fromList(utf8.encode(json.encode(payload)));
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir =
        await Directory.systemTemp.createTemp('falcon_backup_safety_export_');
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
    String? fileName,
  }) =>
      BackupMetadata(
        id: id,
        fileName: fileName ?? BackupFilename.generate(at: createdAt),
        location: BackupLocation.local,
        createdAt: createdAt,
        sizeBytes: 128,
        flightLogsCount: 1,
        checksum: 'unknown',
        localPath: localPath,
        deviceId: 'test',
      );

  group('BackupSafetyExportHelper', () {
    test('export blocked when no backup bytes are available', () async {
      final outcome = await BackupSafetyExportHelper.export(
        candidate: BackupSafetyExportCandidate(
          fileName: BackupFilename.generate(),
          localSourcePath: '${tempDir.path}/missing.crypt14',
        ),
        saveFile: ({required fileName, required bytes}) async => '/unused',
      );

      expect(outcome.isFailure, isTrue);
      expect(outcome.errorMessage, contains('could not be read'));
    });

    test('export copies encrypted .crypt14 file without modifying original',
        () async {
      final sourcePath = '${tempDir.path}/source_backup.crypt14';
      final fileName = BackupFilename.generate();
      final bytes = validEncryptedBackupBytes();
      await File(sourcePath).writeAsBytes(bytes);

      final exportDir =
          await Directory('${tempDir.path}/export_target').create();
      final exportPath = '${exportDir.path}/$fileName';

      final outcome = await BackupSafetyExportHelper.export(
        candidate: BackupSafetyExportCandidate(
          fileName: fileName,
          localSourcePath: sourcePath,
        ),
        saveFile: ({required fileName, required bytes}) async {
          await File(exportPath).writeAsBytes(bytes);
          return exportPath;
        },
      );

      expect(outcome.isSuccess, isTrue);
      expect(await File(sourcePath).readAsBytes(), bytes);
      expect(await File(exportPath).readAsBytes(), bytes);
      expect(fileName.endsWith('.crypt14'), isTrue);
    });

    test('export failure does not delete or alter existing backup', () async {
      final sourcePath = '${tempDir.path}/keep_me.crypt14';
      final bytes = validEncryptedBackupBytes();
      await File(sourcePath).writeAsBytes(bytes);

      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      final createdAt = DateTime(2026, 5, 20, 12, 0, 0);
      await box.put(
        'keep-backup',
        localMetadata(
          id: 'keep-backup',
          localPath: sourcePath,
          createdAt: createdAt,
        ),
      );

      final outcome = await BackupSafetyExportHelper.export(
        candidate: BackupSafetyExportCandidate(
          fileName: BackupFilename.generate(at: createdAt),
          localSourcePath: sourcePath,
        ),
        saveFile: ({required fileName, required bytes}) async {
          throw StateError('save dialog failed');
        },
      );

      expect(outcome.isFailure, isTrue);
      expect(await File(sourcePath).exists(), isTrue);
      expect(await File(sourcePath).readAsBytes(), bytes);
      expect(box.length, 1);
      expect(box.get('keep-backup')?.localPath, sourcePath);
    });

    test('export does not update last_backup_time', () async {
      final sourcePath = '${tempDir.path}/no_touch_time.crypt14';
      final fileName = BackupFilename.generate();
      await File(sourcePath).writeAsBytes(validEncryptedBackupBytes());

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
        isNull,
      );

      await BackupSafetyExportHelper.export(
        candidate: BackupSafetyExportCandidate(
          fileName: fileName,
          localSourcePath: sourcePath,
        ),
        saveFile: ({required fileName, required bytes}) async {
          return '${tempDir.path}/$fileName';
        },
      );

      expect(
        prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!),
        isNull,
      );
    });

    test('export does not create backup metadata', () async {
      final sourcePath = '${tempDir.path}/solo.crypt14';
      final fileName = BackupFilename.generate();
      await File(sourcePath).writeAsBytes(validEncryptedBackupBytes());

      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      expect(box.isEmpty, isTrue);

      await BackupSafetyExportHelper.export(
        candidate: BackupSafetyExportCandidate(
          fileName: fileName,
          localSourcePath: sourcePath,
        ),
        saveFile: ({required fileName, required bytes}) async {
          return '${tempDir.path}/exported/$fileName';
        },
      );

      expect(box.isEmpty, isTrue);
    });

    test('exported file keeps .crypt14 extension in save callback', () async {
      final sourcePath = '${tempDir.path}/ext.crypt14';
      final fileName = BackupFilename.generate();
      await File(sourcePath).writeAsBytes(validEncryptedBackupBytes());

      String? savedName;
      await BackupSafetyExportHelper.export(
        candidate: BackupSafetyExportCandidate(
          fileName: fileName,
          localSourcePath: sourcePath,
        ),
        saveFile: ({required fileName, required bytes}) async {
          savedName = fileName;
          return '${tempDir.path}/$fileName';
        },
      );

      expect(savedName, fileName);
      expect(savedName, endsWith('.crypt14'));
      expect(savedName, startsWith('FLBKUP_'));
    });
  });

  group('resolveLatestExportableBackupForSafetyCopy', () {
    test('returns null when no backup exists', () async {
      final candidate =
          await service.resolveLatestExportableBackupForSafetyCopy();
      expect(candidate, isNull);
    });

    test('returns latest local backup candidate when metadata exists',
        () async {
      final createdAt = DateTime(2026, 5, 20, 15, 30, 45);
      final fileName = BackupFilename.generate(at: createdAt);
      final sourcePath = '${tempDir.path}/$fileName';
      await File(sourcePath).writeAsBytes(validEncryptedBackupBytes());

      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      await box.put(
        'latest-local',
        localMetadata(
          id: 'latest-local',
          localPath: sourcePath,
          createdAt: createdAt,
          fileName: fileName,
        ),
      );

      final candidate =
          await service.resolveLatestExportableBackupForSafetyCopy();
      expect(candidate, isNotNull);
      expect(candidate!.fileName, fileName);
      expect(candidate.localSourcePath, sourcePath);
      expect(candidate.encryptedBytes, isNull);
    });
  });
}

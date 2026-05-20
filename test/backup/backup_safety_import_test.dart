import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:falconlog/backup/utils/backup_filename.dart';
import 'package:falconlog/backup/utils/backup_safety_import_helper.dart';

void main() {
  late Directory tempDir;

  Uint8List validEncryptedBackupBytes() {
    final payload = {
      'encrypted': true,
      'version': '1',
      'backup_id': 'import-test-backup',
      'data': base64.encode(List<int>.filled(32, 7)),
      'iv': base64.encode(List<int>.filled(12, 3)),
      'tag': base64.encode(List<int>.filled(16, 9)),
    };
    return Uint8List.fromList(utf8.encode(json.encode(payload)));
  }

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('falcon_backup_safety_import_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupSafetyImportHelper', () {
    test('loadFromPickerResult cancelled when result is null', () async {
      final outcome = await BackupSafetyImportHelper.loadFromPickerResult(null);
      expect(outcome.isCancelled, isTrue);
    });

    test('loadFromPickerResult cancelled when no files picked', () async {
      final outcome = await BackupSafetyImportHelper.loadFromPickerResult(
        FilePickerResult([]),
      );
      expect(outcome.isCancelled, isTrue);
    });

    test('validate rejects unrecognized backup file name', () {
      final outcome = BackupSafetyImportHelper.validate(
        fileName: 'notes.txt',
        encryptedBytes: validEncryptedBackupBytes(),
      );

      expect(outcome.isFailure, isTrue);
      expect(outcome.errorMessage, contains('not recognized'));
    });

    test('validate rejects empty bytes', () {
      final outcome = BackupSafetyImportHelper.validate(
        fileName: BackupFilename.generate(),
        encryptedBytes: Uint8List(0),
      );

      expect(outcome.isFailure, isTrue);
      expect(outcome.errorMessage, contains('could not be read'));
    });

    test('validate rejects invalid encrypted envelope', () {
      final outcome = BackupSafetyImportHelper.validate(
        fileName: BackupFilename.generate(),
        encryptedBytes: Uint8List.fromList(utf8.encode('not-json')),
      );

      expect(outcome.isFailure, isTrue);
      expect(outcome.errorMessage, contains('not a valid encrypted backup'));
    });

    test('validate accepts valid FLBKUP backup bytes', () {
      final fileName = BackupFilename.generate(
        at: DateTime(2026, 5, 20, 14, 30, 0),
      );
      final outcome = BackupSafetyImportHelper.validate(
        fileName: fileName,
        encryptedBytes: validEncryptedBackupBytes(),
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.candidate?.fileName, fileName);
      expect(outcome.candidate?.encryptedBytes, isNotEmpty);
    });

    test('loadFromPickerResult reads bytes from disk path', () async {
      final fileName = BackupFilename.generate();
      final path = '${tempDir.path}/$fileName';
      final bytes = validEncryptedBackupBytes();
      await File(path).writeAsBytes(bytes);

      final outcome = await BackupSafetyImportHelper.loadFromPickerResult(
        FilePickerResult([
          PlatformFile(path: path, name: fileName, size: bytes.length),
        ]),
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.candidate?.encryptedBytes, bytes);
    });

    test('loadFromPickerResult uses in-memory bytes when provided', () async {
      final fileName = BackupFilename.generate();
      final bytes = validEncryptedBackupBytes();

      final outcome = await BackupSafetyImportHelper.loadFromPickerResult(
        FilePickerResult([
          PlatformFile(
            name: fileName,
            size: bytes.length,
            bytes: bytes,
          ),
        ]),
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.candidate?.encryptedBytes, bytes);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_account_identity_guard.dart';
import 'package:falconlog/backup/utils/backup_filename.dart';
import 'package:googleapis/drive/v3.dart' as drive;

Uint8List _validEnvelopeBytes() {
  return Uint8List.fromList(
    utf8.encode(
      json.encode({
        'encrypted': true,
        'version': '1.0',
        'backup_id': 'backup-abc',
        'data': 'cipher',
        'iv': 'iv',
        'tag': 'tag',
      }),
    ),
  );
}

drive.File _driveFile({
  required String id,
  required String name,
  DateTime? modifiedTime,
}) {
  return drive.File(
    id: id,
    name: name,
    modifiedTime: modifiedTime ?? DateTime(2026, 5, 20, 12),
    size: '2048',
  );
}

void main() {
  final service = BackupService();
  var downloadCalls = 0;

  BackupAccountIdentitySnapshot alignedIdentity() {
    return const BackupAccountIdentitySnapshot(
      firebaseEmail: 'pilot@gmail.com',
      firebaseProviderIds: ['google.com'],
      googleDriveEmail: 'pilot@gmail.com',
      keyOwnerEmail: 'pilot@gmail.com',
    );
  }

  setUp(() {
    downloadCalls = 0;
  });

  group('resolveLatestRestorableDriveBackupForTesting', () {
    test('FLBKUP on Drive with empty local metadata is restorable', () async {
      final file = _driveFile(
        id: 'drive-new',
        name: BackupFilename.generate(at: DateTime(2026, 5, 20)),
      );

      final result = await service.resolveLatestRestorableDriveBackupForTesting(
        backupFiles: [file],
        storedByDriveId: const {},
        identitySnapshot: alignedIdentity(),
        downloadFile: (id) async {
          downloadCalls++;
          expect(id, 'drive-new');
          return _validEnvelopeBytes();
        },
      );

      expect(result, isNotNull);
      expect(result!.driveFileId, 'drive-new');
      expect(result.fileName, startsWith(BackupFilename.newPrefix));
      expect(downloadCalls, 1);
    });

    test('legacy falconlog_backup name without local metadata is restorable',
        () async {
      final file = _driveFile(
        id: 'drive-legacy',
        name: '${BackupFilename.legacyPrefix}1727654400.crypt14',
      );

      final result = await service.resolveLatestRestorableDriveBackupForTesting(
        backupFiles: [file],
        storedByDriveId: const {},
        identitySnapshot: alignedIdentity(),
        downloadFile: (_) async {
          downloadCalls++;
          return _validEnvelopeBytes();
        },
      );

      expect(result, isNotNull);
      expect(result!.fileName, contains(BackupFilename.legacyPrefix));
    });

    test('orphan Drive file without valid backup content is ignored', () async {
      final valid = _driveFile(
        id: 'valid',
        name: BackupFilename.generate(at: DateTime(2026, 5, 21)),
      );
      final orphan = _driveFile(
        id: 'orphan',
        name: BackupFilename.generate(at: DateTime(2026, 5, 22)),
      );

      final result = await service.resolveLatestRestorableDriveBackupForTesting(
        backupFiles: [orphan, valid],
        storedByDriveId: const {},
        identitySnapshot: alignedIdentity(),
        downloadFile: (id) async {
          downloadCalls++;
          if (id == 'orphan') {
            return Uint8List.fromList(utf8.encode('not-a-backup'));
          }
          return _validEnvelopeBytes();
        },
      );

      expect(result?.driveFileId, 'valid');
      expect(downloadCalls, 2);
    });

    test('key owner mismatch blocks cloud recovery discovery', () async {
      final file = _driveFile(
        id: 'drive-1',
        name: BackupFilename.generate(),
      );

      final result = await service.resolveLatestRestorableDriveBackupForTesting(
        backupFiles: [file],
        storedByDriveId: const {},
        identitySnapshot: const BackupAccountIdentitySnapshot(
          firebaseEmail: 'owner@gmail.com',
          googleDriveEmail: 'other@gmail.com',
          keyOwnerEmail: 'owner@gmail.com',
        ),
        downloadFile: (_) async {
          downloadCalls++;
          return _validEnvelopeBytes();
        },
      );

      expect(result, isNull);
      expect(downloadCalls, 0);
    });

    test('metadata-linked backup preferred without download when present',
        () async {
      final stored = BackupMetadata(
        id: 'meta-1',
        fileName: BackupFilename.generate(),
        location: BackupLocation.cloud,
        createdAt: DateTime(2026, 5, 19),
        sizeBytes: 100,
        flightLogsCount: 3,
        checksum: 'abc',
        driveFileId: 'drive-meta',
        deviceId: 'device',
      );

      final file = _driveFile(
        id: 'drive-meta',
        name: stored.fileName,
        modifiedTime: DateTime(2026, 5, 19),
      );

      final result = await service.resolveLatestRestorableDriveBackupForTesting(
        backupFiles: [file],
        storedByDriveId: {'drive-meta': stored},
        identitySnapshot: alignedIdentity(),
        downloadFile: (_) async {
          downloadCalls++;
          fail('Should not download when Hive metadata exists');
        },
      );

      expect(result?.id, 'meta-1');
      expect(result?.flightLogsCount, 3);
      expect(downloadCalls, 0);
    });
  });
}

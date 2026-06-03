import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/backup/utils/backup_filename.dart';
import 'package:falconlog/backup/utils/drive_backup_discovery.dart';
import 'package:googleapis/drive/v3.dart' as drive;

Uint8List _envelopeBytes() {
  return Uint8List.fromList(
    utf8.encode(
      json.encode({
        'encrypted': true,
        'version': '1.0',
        'backup_id': 'backup-123',
        'data': 'cipher',
        'iv': 'iv-value',
        'tag': 'tag-value',
      }),
    ),
  );
}

void main() {
  group('DriveBackupDiscovery', () {
    test('recognizes FLBKUP and legacy falconlog_backup names', () {
      expect(
        DriveBackupDiscovery.isRecognizedDriveFile(
          drive.File(id: '1', name: BackupFilename.generate()),
        ),
        isTrue,
      );
      expect(
        DriveBackupDiscovery.isRecognizedDriveFile(
          drive.File(
            id: '2',
            name: '${BackupFilename.legacyPrefix}1727654400.crypt14',
          ),
        ),
        isTrue,
      );
      expect(
        DriveBackupDiscovery.isRecognizedDriveFile(
          drive.File(id: '3', name: 'random_file.txt'),
        ),
        isFalse,
      );
    });

    test('validates backup envelope bytes', () {
      expect(DriveBackupDiscovery.validateBackupFileBytes(_envelopeBytes()),
          isTrue);
    });

    test('rejects orphan/incomplete envelope', () {
      final orphan = Uint8List.fromList(utf8.encode('{"encrypted":true}'));
      expect(DriveBackupDiscovery.validateBackupFileBytes(orphan), isFalse);
    });
  });
}

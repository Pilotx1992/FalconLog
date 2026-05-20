import 'package:flutter_test/flutter_test.dart';

import 'package:falconlog/backup/utils/backup_filename.dart';

void main() {
  group('BackupFilename', () {
    test('generate matches FLBKUP_YYYYMMDD_HHMMSS.crypt14', () {
      final name = BackupFilename.generate(
        at: DateTime(2026, 5, 20, 23, 14, 55),
      );

      expect(name, 'FLBKUP_20260520_231455.crypt14');
      expect(
        name,
        matches(RegExp(r'^FLBKUP_\d{8}_\d{6}\.crypt14$')),
      );
    });

    test('generate uses only safe filename characters', () {
      final name = BackupFilename.generate(
        at: DateTime(2026, 1, 2, 3, 4, 5),
      );

      expect(BackupFilename.hasOnlySafeCharacters(name), isTrue);
      expect(name.contains(' '), isFalse);
      expect(name.contains(':'), isFalse);
    });

    test('two backups same day different times produce different names', () {
      final morning = BackupFilename.generate(
        at: DateTime(2026, 5, 20, 8, 0, 0),
      );
      final evening = BackupFilename.generate(
        at: DateTime(2026, 5, 20, 20, 30, 45),
      );

      expect(morning, isNot(evening));
      expect(morning, 'FLBKUP_20260520_080000.crypt14');
      expect(evening, 'FLBKUP_20260520_203045.crypt14');
    });

    test('legacy backup filenames are still recognized', () {
      const legacy = 'falconlog_backup_1727654400.crypt14';

      expect(BackupFilename.isRecognizedBackupFileName(legacy), isTrue);
      expect(BackupFilename.hasOnlySafeCharacters(legacy), isTrue);
    });

    test('new backup filenames are recognized', () {
      const name = 'FLBKUP_20260520_231455.crypt14';

      expect(BackupFilename.isRecognizedBackupFileName(name), isTrue);
    });

    test('drive discovery query includes legacy and new prefixes', () {
      expect(
        BackupFilename.driveDiscoveryQuery,
        contains(BackupFilename.legacyPrefix),
      );
      expect(
        BackupFilename.driveDiscoveryQuery,
        contains(BackupFilename.newPrefix),
      );
      expect(
        BackupFilename.driveDiscoveryQuery,
        contains(BackupFilename.extension),
      );
    });

    test('non-backup files are not recognized', () {
      expect(
        BackupFilename.isRecognizedBackupFileName(
          'falconlog_backup_keys.json',
        ),
        isFalse,
      );
      expect(
        BackupFilename.isRecognizedBackupFileName('random_file.txt'),
        isFalse,
      );
    });
  });
}

import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/utils/scheduled_backup_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planScheduledBackup', () {
    test('disabled auto backup skips without running backup', () {
      final plan = planScheduledBackup(
        autoBackupEnabled: false,
        frequency: 'daily',
        provider: BackupProvider.googleDrive,
        hasFlightLogs: true,
      );

      expect(plan.shouldRunBackup, isFalse);
      expect(plan.reportWorkmanagerSuccess, isTrue);
      expect(plan.skipReason, ScheduledBackupSkipReason.disabled);
    });

    test('frequency off skips without running backup', () {
      final plan = planScheduledBackup(
        autoBackupEnabled: true,
        frequency: 'off',
        provider: BackupProvider.googleDrive,
        hasFlightLogs: true,
      );

      expect(plan.shouldRunBackup, isFalse);
      expect(plan.reportWorkmanagerSuccess, isTrue);
    });

    test('empty flight log box skips safely', () {
      final plan = planScheduledBackup(
        autoBackupEnabled: true,
        frequency: 'weekly',
        provider: BackupProvider.local,
        hasFlightLogs: false,
      );

      expect(plan.shouldRunBackup, isFalse);
      expect(plan.reportWorkmanagerSuccess, isTrue);
      expect(plan.skipReason, ScheduledBackupSkipReason.noFlightLogs);
    });

    test('firebase provider skips as unsupported', () {
      final plan = planScheduledBackup(
        autoBackupEnabled: true,
        frequency: 'daily',
        provider: BackupProvider.firebase,
        hasFlightLogs: true,
      );

      expect(plan.shouldRunBackup, isFalse);
      expect(plan.reportWorkmanagerSuccess, isTrue);
      expect(plan.skipReason, ScheduledBackupSkipReason.unsupportedProvider);
    });

    test('google drive with logs runs backup', () {
      final plan = planScheduledBackup(
        autoBackupEnabled: true,
        frequency: 'daily',
        provider: BackupProvider.googleDrive,
        hasFlightLogs: true,
      );

      expect(plan.shouldRunBackup, isTrue);
      expect(plan.reportWorkmanagerSuccess, isTrue);
    });
  });
}

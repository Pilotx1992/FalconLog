import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/utils/auto_backup_scheduler.dart';
import 'package:falconlog/backup/utils/backup_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  test('daily evaluator uses minimal constraints without network requirement', () {
    final constraints = AutoBackupScheduler.evaluatorConstraints();
    expect(constraints.networkType, NetworkType.notRequired);
    expect(constraints.requiresBatteryNotLow, isFalse);
    expect(constraints.requiresStorageNotLow, isFalse);
  });

  test('catch-up uses full backup constraints for drive wifi-only', () {
    final constraints = BackupScheduler.constraintsForProvider(
      BackupProvider.googleDrive,
      wifiOnly: true,
    );
    expect(constraints.networkType, NetworkType.unmetered);
    expect(constraints.requiresBatteryNotLow, isTrue);
    expect(constraints.requiresStorageNotLow, isTrue);
  });

  test('catch-up uses connected network when cellular backup On', () {
    final constraints = BackupScheduler.constraintsForProvider(
      BackupProvider.googleDrive,
      wifiOnly: false,
    );
    expect(constraints.networkType, NetworkType.connected);
  });
}

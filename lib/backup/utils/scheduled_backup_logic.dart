import '../models/backup_provider_enum.dart';

/// Pure decision logic for WorkManager scheduled backup runs (testable).
class ScheduledBackupPlan {
  const ScheduledBackupPlan._({
    required this.shouldRunBackup,
    required this.reportWorkmanagerSuccess,
    this.skipReason,
  });

  /// When false, [BackupService.startBackup] must not be invoked.
  final bool shouldRunBackup;

  /// When true, WorkManager should receive `true` (task handled, no retry storm).
  final bool reportWorkmanagerSuccess;

  final ScheduledBackupSkipReason? skipReason;

  factory ScheduledBackupPlan.runBackup() => const ScheduledBackupPlan._(
        shouldRunBackup: true,
        reportWorkmanagerSuccess: true,
      );

  factory ScheduledBackupPlan.skip({
    required ScheduledBackupSkipReason reason,
  }) =>
      ScheduledBackupPlan._(
        shouldRunBackup: false,
        reportWorkmanagerSuccess: true,
        skipReason: reason,
      );

  factory ScheduledBackupPlan.failed() => const ScheduledBackupPlan._(
        shouldRunBackup: false,
        reportWorkmanagerSuccess: false,
      );
}

enum ScheduledBackupSkipReason {
  disabled,
  noFlightLogs,
  unsupportedProvider,
}

/// Evaluates whether a background worker should invoke backup.
ScheduledBackupPlan planScheduledBackup({
  required bool autoBackupEnabled,
  required String frequency,
  required BackupProvider provider,
  required bool hasFlightLogs,
}) {
  if (!autoBackupEnabled || frequency == 'off') {
    return ScheduledBackupPlan.skip(reason: ScheduledBackupSkipReason.disabled);
  }

  if (!hasFlightLogs) {
    return ScheduledBackupPlan.skip(
      reason: ScheduledBackupSkipReason.noFlightLogs,
    );
  }

  if (provider == BackupProvider.firebase) {
    return ScheduledBackupPlan.skip(
      reason: ScheduledBackupSkipReason.unsupportedProvider,
    );
  }

  return ScheduledBackupPlan.runBackup();
}

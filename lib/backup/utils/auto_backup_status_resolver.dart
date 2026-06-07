import '../models/backup_provider_enum.dart';

/// Live pending status for daily auto backup (not persisted failure reasons).
class AutoBackupPendingContext {
  const AutoBackupPendingContext({
    required this.wifiOnly,
    required this.provider,
    required this.networkSatisfied,
    required this.driveReady,
    required this.operationLockFree,
  });

  final bool wifiOnly;
  final BackupProvider provider;
  final bool networkSatisfied;
  final bool driveReady;
  final bool operationLockFree;

  /// Cellular backup On when automatic backup may use mobile data.
  bool get allowCellularBackup => !wifiOnly;
}

/// Resolves user-facing Auto Backup pending text from current conditions.
class AutoBackupStatusResolver {
  AutoBackupStatusResolver._();

  static const String waitingForWifi = 'Backup pending — waiting for Wi-Fi.';
  static const String waitingForBattery =
      'Backup pending — waiting for sufficient battery.';
  static const String waitingForDriveAuth =
      'Backup pending — sign in to Google Drive.';
  static const String waitingForConditions =
      'Backup pending — waiting for conditions.';
  static const String scheduledWithAndroid =
      'Backup pending — will run when Android schedules it.';

  /// Evaluates [ctx] now — never reads stale persisted failure reasons.
  static String resolvePendingMessage(AutoBackupPendingContext ctx) {
    if (!ctx.allowCellularBackup && !ctx.networkSatisfied) {
      return waitingForWifi;
    }
    if (ctx.provider == BackupProvider.googleDrive && !ctx.driveReady) {
      return waitingForDriveAuth;
    }
    if (!ctx.operationLockFree) {
      return waitingForConditions;
    }
    return scheduledWithAndroid;
  }
}

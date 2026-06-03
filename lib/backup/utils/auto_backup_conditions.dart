import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/backup_provider_enum.dart';
import 'backup_operation_lock.dart';

/// Result of evaluating whether auto backup can run.
enum AutoBackupBlockReason {
  disabled,
  notDailyFrequency,
  unsupportedProvider,
  noFlightLogs,
  driveAuthNotReady,
  networkNotSatisfied,
  batteryLow,
  storageLow,
  operationLockHeld,
  alreadySucceededForDueDay,
  noPendingDueDay,
  restoreInProgress,
}

/// Input for catch-up / interval execution checks.
class AutoBackupExecutionContext {
  const AutoBackupExecutionContext({
    required this.autoBackupEnabled,
    required this.frequency,
    required this.provider,
    required this.hasFlightLogs,
    required this.pendingDueDay,
    required this.lastSuccessDueDay,
    required this.driveReady,
    required this.networkSatisfied,
    required this.batteryOk,
    required this.storageOk,
    required this.lockFree,
  });

  final bool autoBackupEnabled;
  final String frequency;
  final BackupProvider provider;
  final bool hasFlightLogs;
  final String? pendingDueDay;
  final String? lastSuccessDueDay;
  final bool driveReady;
  final bool networkSatisfied;
  final bool batteryOk;
  final bool storageOk;
  final bool lockFree;
}

class AutoBackupConditionsEvaluator {
  AutoBackupConditionsEvaluator._();

  static AutoBackupBlockReason? firstExecutionBlock(
    AutoBackupExecutionContext ctx,
  ) {
    if (!ctx.autoBackupEnabled) return AutoBackupBlockReason.disabled;
    if (ctx.frequency != 'daily') return AutoBackupBlockReason.notDailyFrequency;
    if (ctx.provider == BackupProvider.firebase) {
      return AutoBackupBlockReason.unsupportedProvider;
    }
    if (!ctx.hasFlightLogs) return AutoBackupBlockReason.noFlightLogs;
    if (ctx.pendingDueDay == null) {
      return AutoBackupBlockReason.noPendingDueDay;
    }
    if (ctx.lastSuccessDueDay != null &&
        ctx.lastSuccessDueDay == ctx.pendingDueDay) {
      return AutoBackupBlockReason.alreadySucceededForDueDay;
    }
    if (ctx.provider == BackupProvider.googleDrive && !ctx.driveReady) {
      return AutoBackupBlockReason.driveAuthNotReady;
    }
    if (!ctx.networkSatisfied) {
      return AutoBackupBlockReason.networkNotSatisfied;
    }
    if (!ctx.batteryOk) return AutoBackupBlockReason.batteryLow;
    if (!ctx.storageOk) return AutoBackupBlockReason.storageLow;
    if (!ctx.lockFree) return AutoBackupBlockReason.operationLockHeld;
    return null;
  }

  static String failureMessageFor(AutoBackupBlockReason reason) {
    switch (reason) {
      case AutoBackupBlockReason.disabled:
        return 'auto_backup_disabled';
      case AutoBackupBlockReason.notDailyFrequency:
        return 'not_daily_frequency';
      case AutoBackupBlockReason.unsupportedProvider:
        return 'unsupported_provider';
      case AutoBackupBlockReason.noFlightLogs:
        return 'no_flight_logs';
      case AutoBackupBlockReason.driveAuthNotReady:
        return 'drive_auth_not_ready';
      case AutoBackupBlockReason.networkNotSatisfied:
        return 'waiting_for_wifi';
      case AutoBackupBlockReason.batteryLow:
        return 'battery_low';
      case AutoBackupBlockReason.storageLow:
        return 'storage_low';
      case AutoBackupBlockReason.operationLockHeld:
        return 'operation_lock_held';
      case AutoBackupBlockReason.alreadySucceededForDueDay:
        return 'already_succeeded';
      case AutoBackupBlockReason.noPendingDueDay:
        return 'no_pending_due';
      case AutoBackupBlockReason.restoreInProgress:
        return 'restore_in_progress';
    }
  }

  static Future<bool> isOperationLockFree() async {
    final record = await BackupOperationLock.read();
    if (record == null) return true;
    return record.isStale(
      DateTime.now().toUtc(),
      BackupOperationLock.defaultStaleTimeout,
    );
  }

  /// Current network suitability for auto backup (not persisted state).
  static Future<bool> isNetworkSatisfiedForAutoBackup({
    required bool wifiOnly,
  }) async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (wifiOnly) {
        return results.contains(ConnectivityResult.wifi);
      }
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }
}

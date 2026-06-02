import 'package:flutter/foundation.dart';

import 'auto_backup_due_engine.dart';
import 'auto_backup_log.dart';
import 'auto_backup_reconciler.dart';
import 'auto_backup_state_store.dart';
import 'auto_backup_work_names.dart';
import 'backup_constants.dart';
import 'backup_provider_preferences.dart';
import 'backup_scheduler.dart';

/// Debug-only helpers for on-device auto backup QA (not available in release).
class AutoBackupDebugQa {
  AutoBackupDebugQa._();

  static void _assertDebug() {
    assert(() {
      if (!kDebugMode) {
        throw StateError('AutoBackupDebugQa is only available in debug builds');
      }
      return true;
    }());
  }

  static const String simulateWifiUnavailableKey =
      'falconlog_qa_simulate_wifi_unavailable';

  /// Debug-only: blocks catch-up execution without turning off device Wi-Fi
  /// (required for wireless ADB QA where `svc wifi disable` drops the session).
  static Future<void> setSimulateWifiUnavailable(bool blocked) async {
    _assertDebug();
    final prefs = await BackupScheduler.sharedPreferences();
    await prefs.setBool(simulateWifiUnavailableKey, blocked);
    AutoBackupLog.qa(
      blocked
          ? 'simulate Wi-Fi unavailable ON'
          : 'simulate Wi-Fi unavailable OFF',
    );
  }

  static Future<bool> isSimulateWifiUnavailable() async {
    if (!kDebugMode) return false;
    final prefs = await BackupScheduler.sharedPreferences();
    return prefs.getBool(simulateWifiUnavailableKey) ?? false;
  }

  static Future<DateTime> setDueTimeToNowPlusMinutes(int minutesFromNow) async {
    _assertDebug();
    final target = DateTime.now().add(Duration(minutes: minutesFromNow));
    final minuteOfDay = target.hour * 60 + target.minute;
    await AutoBackupStateStore().setDueMinuteOfDay(minuteOfDay);
    AutoBackupLog.qa(
      'set due time to ${target.hour}:${target.minute.toString().padLeft(2, '0')} '
      '(minuteOfDay=$minuteOfDay, +$minutesFromNow min)',
    );
    return target;
  }

  /// Scheduling only — calls [AutoBackupReconciler.reconcile], never [BackupService.startBackup].
  static Future<void> runReconcileNow() async {
    _assertDebug();
    AutoBackupLog.qa('run reconcile now');
    await AutoBackupReconciler().reconcile();
    AutoBackupLog.qa('reconcile finished');
  }

  /// Logs full daily auto-backup state for manual QA on device.
  static Future<void> dumpStateToLog() async {
    _assertDebug();
    final snapshot = await snapshotState();
    AutoBackupLog.qa('--- auto backup state dump ---');
    for (final entry in snapshot.entries) {
      AutoBackupLog.qa('${entry.key}=${entry.value}');
    }
    AutoBackupLog.qa('--- end dump ---');
  }

  /// Clears daily due-day tracking fields (pending/success/attempt/failure).
  static Future<void> clearDailyAutoBackupState() async {
    _assertDebug();
    await AutoBackupStateStore().clearDailyAutoBackupState();
    AutoBackupLog.qa('cleared daily auto backup state');
  }

  /// Restores production default 23:59 due minute.
  static Future<void> resetDueToProductionDefault() async {
    _assertDebug();
    await AutoBackupStateStore().setDueMinuteOfDay(
      AutoBackupDueEngine.defaultDueMinuteOfDay,
    );
    AutoBackupLog.qa('due reset to 23:59');
  }

  /// Human-readable snapshot for QA.
  static Future<Map<String, String>> snapshotState() async {
    _assertDebug();
    final prefs = await BackupScheduler.sharedPreferences();
    final store = AutoBackupStateStore(prefs: prefs);
    final frequency =
        prefs.getString(BackupConstants.settingsKeys['backup_frequency']!) ??
            'off';
    final enabled =
        prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
            false;
    final wifiOnly =
        prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ?? true;
    final provider = await BackupProviderPreferences.getSelectedProvider();
    final dueMinute = await store.getDueMinuteOfDay();
    final lastSuccessAt = await store.getLastSuccessAt();
    final lastAttemptAt = await store.getLastAttemptAt();

    bool dailyScheduled = false;
    bool catchupScheduled = false;
    bool intervalScheduled = false;
    try {
      dailyScheduled = await BackupScheduler.isScheduledByUniqueNameInternal(
        AutoBackupWorkNames.dailyEvaluatorUnique,
      );
      catchupScheduled = await BackupScheduler.isScheduledByUniqueNameInternal(
        AutoBackupWorkNames.catchupUnique,
      );
      intervalScheduled = await BackupScheduler.isScheduledByUniqueNameInternal(
        AutoBackupWorkNames.intervalPeriodicUnique,
      );
    } catch (_) {}

    return {
      'auto_backup_enabled': enabled.toString(),
      'frequency': frequency,
      'due_minute': dueMinute.toString(),
      'due_time_local': _formatMinute(dueMinute),
      'pending_due_day': await store.getPendingDueDay() ?? '(none)',
      'last_success_due_day': await store.getLastSuccessDueDay() ?? '(none)',
      'last_success_at': lastSuccessAt?.toIso8601String() ?? '(none)',
      'last_attempt_at': lastAttemptAt?.toIso8601String() ?? '(none)',
      'last_failure_reason': await store.getLastFailureReason() ?? '(none)',
      'selected_provider': provider.name,
      'wifi_only': wifiOnly.toString(),
      'qa_simulate_wifi_unavailable':
          (await isSimulateWifiUnavailable()).toString(),
      'wm_daily_evaluator': dailyScheduled.toString(),
      'wm_catchup': catchupScheduled.toString(),
      'wm_interval_periodic': intervalScheduled.toString(),
    };
  }

  static String _formatMinute(int minuteOfDay) {
    final h = minuteOfDay ~/ 60;
    final m = minuteOfDay % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // --- Optional debug helpers (not shown in minimal QA panel) ---

  static Future<bool> runEvaluatorNow() async {
    _assertDebug();
    AutoBackupLog.qa('evaluator now (manual, no startBackup)');
    return BackupScheduler().runDailyEvaluatorForTesting();
  }

  static Future<bool> runCatchupNow() async {
    _assertDebug();
    AutoBackupLog.qa('catch-up now (manual, may startBackup)');
    return BackupScheduler().runScheduledBackupForTesting();
  }

  static Future<String?> applyDueTickNow() async {
    _assertDebug();
    final store = AutoBackupStateStore();
    final dueMinute = await store.getDueMinuteOfDay();
    return store.applyDueTick(
      nowLocal: DateTime.now(),
      dueMinuteOfDay: dueMinute,
    );
  }

  @Deprecated('Use setDueTimeToNowPlusMinutes')
  static Future<DateTime> scheduleDueInMinutesFromNow(int minutes) =>
      setDueTimeToNowPlusMinutes(minutes);

  static String formatSnapshotForDisplay(Map<String, String> snapshot) {
    final keys = snapshot.keys.toList()..sort();
    return keys.map((k) => '$k: ${snapshot[k]}').join('\n');
  }
}

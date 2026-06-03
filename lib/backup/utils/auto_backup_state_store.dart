import 'package:shared_preferences/shared_preferences.dart';

import 'auto_backup_due_engine.dart';
import 'auto_backup_log.dart';
import 'backup_constants.dart';

/// Persisted state for daily 23:59 auto backup (ignored when frequency != daily).
class AutoBackupStateStore {
  AutoBackupStateStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static const String dueMinuteKey = 'falconlog_auto_backup_due_minute';
  static const String pendingDueDayKey = 'falconlog_auto_backup_pending_due_day';
  static const String lastSuccessDueDayKey =
      'falconlog_auto_backup_last_success_due_day';
  static const String lastSuccessAtKey = 'falconlog_auto_backup_last_success_at';
  static const String lastAttemptAtKey = 'falconlog_auto_backup_last_attempt_at';
  static const String lastFailureReasonKey =
      'falconlog_auto_backup_last_failure_reason';
  static const String scheduleGenKey = 'falconlog_auto_backup_schedule_gen';
  static const String qaSimulateWifiUnavailableKey =
      'falconlog_qa_simulate_wifi_unavailable';

  /// Device-local transient keys — never restored from backup bundles.
  static const Set<String> deviceLocalRuntimeKeys = {
    pendingDueDayKey,
    lastAttemptAtKey,
    lastFailureReasonKey,
    scheduleGenKey,
    qaSimulateWifiUnavailableKey,
  };

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<int> getDueMinuteOfDay() async {
    final prefs = await _ensurePrefs();
    return prefs.getInt(dueMinuteKey) ??
        AutoBackupDueEngine.defaultDueMinuteOfDay;
  }

  Future<void> setDueMinuteOfDay(int minute) async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(dueMinuteKey, minute);
  }

  Future<String?> getPendingDueDay() async {
    final prefs = await _ensurePrefs();
    return prefs.getString(pendingDueDayKey);
  }

  Future<String?> getLastSuccessDueDay() async {
    final prefs = await _ensurePrefs();
    return prefs.getString(lastSuccessDueDayKey);
  }

  Future<DateTime?> getLastSuccessAt() async {
    final prefs = await _ensurePrefs();
    final ms = prefs.getInt(lastSuccessAtKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<String?> getLastFailureReason() async {
    final prefs = await _ensurePrefs();
    return prefs.getString(lastFailureReasonKey);
  }

  Future<DateTime?> getLastAttemptAt() async {
    final prefs = await _ensurePrefs();
    final ms = prefs.getInt(lastAttemptAtKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setPendingDueDay(String? dayId) async {
    final prefs = await _ensurePrefs();
    if (dayId == null) {
      await prefs.remove(pendingDueDayKey);
    } else {
      await prefs.setString(pendingDueDayKey, dayId);
    }
  }

  /// Collapsed pending from due engine tick.
  Future<String?> applyDueTick({
    required DateTime nowLocal,
    required int dueMinuteOfDay,
  }) async {
    final lastSuccess = await getLastSuccessDueDay();
    final missed = AutoBackupDueEngine.latestMissedDueDay(
      nowLocal: nowLocal,
      dueMinuteOfDay: dueMinuteOfDay,
      lastSuccessDueDay: lastSuccess,
    );
    if (missed == null) {
      final pending = await getPendingDueDay();
      if (pending != null &&
          AutoBackupDueEngine.isDueDaySatisfied(
            lastSuccessDueDay: lastSuccess,
            pendingOrRunDueDay: pending,
          )) {
        await setPendingDueDay(null);
      }
      return null;
    }
    await setPendingDueDay(missed);
    AutoBackupLog.dueEngine('pending set dueDay=$missed');
    return missed;
  }

  /// After verified backup — uses captured [runDueDay], not a re-read of pending.
  Future<void> commitSuccess(String runDueDay, DateTime completedAt) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(lastSuccessDueDayKey, runDueDay);
    await prefs.setInt(lastSuccessAtKey, completedAt.millisecondsSinceEpoch);
    final pending = prefs.getString(pendingDueDayKey);
    if (pending == runDueDay) {
      await prefs.remove(pendingDueDayKey);
    }
    await prefs.remove(lastFailureReasonKey);
    await prefs.remove(lastAttemptAtKey);
    AutoBackupLog.stateStore('commitSuccess runDueDay=$runDueDay');
  }

  Future<void> recordAttemptFailure(String reason) async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(lastAttemptAtKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(lastFailureReasonKey, reason);
  }

  /// Clears stale attempt/failure after conditions become satisfiable again.
  Future<void> clearStaleFailureState() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(lastAttemptAtKey);
    await prefs.remove(lastFailureReasonKey);
    AutoBackupLog.stateStore('clearStaleFailureState');
  }

  /// Clears device-local runtime fields (restore / QA reset).
  Future<void> clearDeviceLocalRuntimeState() async {
    final prefs = await _ensurePrefs();
    for (final key in deviceLocalRuntimeKeys) {
      await prefs.remove(key);
    }
    await clearDailyAutoBackupState();
    AutoBackupLog.stateStore('clearDeviceLocalRuntimeState');
  }

  /// Clears daily-path pending/failure/success tracking (debug QA reset).
  Future<void> clearDailyAutoBackupState() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(pendingDueDayKey);
    await prefs.remove(lastSuccessDueDayKey);
    await prefs.remove(lastSuccessAtKey);
    await prefs.remove(lastAttemptAtKey);
    await prefs.remove(lastFailureReasonKey);
    AutoBackupLog.stateStore('clearDailyAutoBackupState');
  }

  @Deprecated('Use clearDailyAutoBackupState')
  Future<void> clearDailyState() => clearDailyAutoBackupState();

  /// One-time migration from legacy last_backup_time.
  Future<void> migrateFromLegacyLastBackupTimeIfNeeded() async {
    final prefs = await _ensurePrefs();
    if (prefs.containsKey(lastSuccessDueDayKey)) return;

    final legacyMs = prefs.getInt(
      BackupConstants.settingsKeys['last_backup_time']!,
    );
    if (legacyMs == null) return;

    final local = DateTime.fromMillisecondsSinceEpoch(legacyMs);
    final dueMinute = await getDueMinuteOfDay();
    final dayId = AutoBackupDueEngine.dueDayId(local);
    await prefs.setString(lastSuccessDueDayKey, dayId);
    await prefs.setInt(lastSuccessAtKey, legacyMs);
    final due = AutoBackupDueEngine.dueInstantForDay(dayId, dueMinute);
    if (local.isBefore(due)) {
      final prev = DateTime(local.year, local.month, local.day)
          .subtract(const Duration(days: 1));
      await prefs.setString(
        lastSuccessDueDayKey,
        AutoBackupDueEngine.dueDayId(prev),
      );
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../models/backup_provider_enum.dart';
import '../services/backup_service.dart';
import 'auto_backup_conditions.dart';
import 'auto_backup_log.dart';
import 'auto_backup_state_store.dart';
import 'auto_backup_work_names.dart';
import 'backup_constants.dart';
import 'backup_provider_preferences.dart';
import 'backup_scheduler.dart';
import 'auto_backup_scheduler.dart';

/// Aligns persisted auto backup state with WorkManager after startup / resume.
class AutoBackupReconciler {
  AutoBackupReconciler({
    AutoBackupStateStore? stateStore,
    AutoBackupScheduler? scheduler,
    Logger? logger,
    @visibleForTesting this.conditionsSatisfiableForTesting,
  })  : _stateStore = stateStore ?? AutoBackupStateStore(),
        _scheduler = scheduler ?? AutoBackupScheduler(),
        _logger = logger ?? Logger('AutoBackupReconciler');

  @visibleForTesting
  final Future<bool> Function({required bool wifiOnly})?
      conditionsSatisfiableForTesting;

  final AutoBackupStateStore _stateStore;
  final AutoBackupScheduler _scheduler;
  final Logger _logger;

  /// Reads persisted settings and aligns WorkManager with due state.
  Future<void> reconcile() async {
    final enabled = await isAutoBackupEnabled();
    final frequency = await readFrequency();
    final wifiOnly = await readWifiOnly();
    AutoBackupLog.reconciler(
      'reconcile start enabled=$enabled frequency=$frequency wifiOnly=$wifiOnly',
    );
    await reconcileOnStartup(
      enabled: enabled,
      frequency: frequency,
      wifiOnly: wifiOnly,
    );
    AutoBackupLog.reconciler('reconcile finished frequency=$frequency');
  }

  Future<void> reconcileOnStartup({
    required bool enabled,
    required String frequency,
    required bool wifiOnly,
  }) async {
    if (!enabled || frequency == 'off') {
      await _scheduler.cancelAllAutoBackupWork();
      return;
    }

    if (frequency == 'daily') {
      await _reconcileDaily(wifiOnly: wifiOnly);
      return;
    }

    if (frequency == 'weekly' || frequency == 'monthly') {
      await _reconcileInterval(frequency: frequency, wifiOnly: wifiOnly);
      return;
    }
  }

  Future<void> _reconcileDaily({required bool wifiOnly}) async {
    await _stateStore.migrateFromLegacyLastBackupTimeIfNeeded();
    final dueMinute = await _stateStore.getDueMinuteOfDay();
    await _stateStore.applyDueTick(
      nowLocal: DateTime.now(),
      dueMinuteOfDay: dueMinute,
    );

    await _scheduler.cancelIntervalPath();
    await _scheduler.cancelLegacyWork();

    var scheduled = false;
    try {
      scheduled = await BackupScheduler.isScheduledByUniqueNameInternal(
        AutoBackupWorkNames.dailyEvaluatorUnique,
      );
    } catch (_) {}

    if (!scheduled) {
      await _scheduler.registerDailyEvaluator();
    }

    final pending = await _stateStore.getPendingDueDay();
    if (pending != null) {
      AutoBackupLog.dueEngine('pending dueDay=$pending (reconcile daily)');
      if (await _conditionsSatisfiableForCatchup(wifiOnly: wifiOnly)) {
        await _stateStore.clearStaleFailureState();
      }
      await _enqueueCatchupIfNeeded(wifiOnly: wifiOnly);
    }
  }

  Future<bool> _conditionsSatisfiableForCatchup({
    required bool wifiOnly,
  }) async {
    final override = conditionsSatisfiableForTesting;
    if (override != null) {
      return override(wifiOnly: wifiOnly);
    }
    final networkOk =
        await AutoBackupConditionsEvaluator.isNetworkSatisfiedForAutoBackup(
      wifiOnly: wifiOnly,
    );
    if (!networkOk) return false;

    final provider = await BackupProviderPreferences.getSelectedProvider();
    if (provider == BackupProvider.googleDrive) {
      try {
        return await BackupService().initialize(interactive: false);
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<void> _reconcileInterval({
    required String frequency,
    required bool wifiOnly,
  }) async {
    await _scheduler.cancelDailyPath();
    await _stateStore.clearDailyAutoBackupState();

    var scheduled = false;
    try {
      scheduled = await BackupScheduler.isScheduledByUniqueNameInternal(
        AutoBackupWorkNames.intervalPeriodicUnique,
      );
    } catch (_) {}

    if (!scheduled) {
      final provider = await BackupProviderPreferences.getSelectedProvider();
      await _scheduler.registerIntervalPeriodic(
        frequency: frequency,
        provider: provider,
        wifiOnly: wifiOnly,
      );
    }
  }

  Future<void> _enqueueCatchupIfNeeded({required bool wifiOnly}) async {
    var catchupScheduled = false;
    try {
      catchupScheduled = await BackupScheduler.isScheduledByUniqueNameInternal(
        AutoBackupWorkNames.catchupUnique,
      );
    } catch (_) {}

    if (catchupScheduled) return;

    final provider = await BackupProviderPreferences.getSelectedProvider();
    await _scheduler.registerCatchup(provider: provider, wifiOnly: wifiOnly);
    AutoBackupLog.scheduler('enqueue catchup policy=KEEP (reconciler)');
    _logger.fine('Catch-up work enqueued from reconciler');
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await BackupScheduler.sharedPreferences();
    return prefs.getBool(
          BackupConstants.settingsKeys['auto_backup_enabled']!,
        ) ??
        false;
  }

  static Future<String> readFrequency() async {
    final prefs = await BackupScheduler.sharedPreferences();
    return prefs.getString(
          BackupConstants.settingsKeys['backup_frequency']!,
        ) ??
        'off';
  }

  static Future<bool> readWifiOnly() async {
    final prefs = await BackupScheduler.sharedPreferences();
    return prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ?? true;
  }
}

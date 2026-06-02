import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/hive_initialization_service.dart';
import '../../models/flight_log.dart';
import '../models/backup_provider_enum.dart';
import '../services/backup_service.dart';
import 'auto_backup_debug_qa.dart';
import 'auto_backup_conditions.dart';
import 'auto_backup_log.dart';
import 'auto_backup_run_planner.dart';
import 'auto_backup_scheduler.dart';
import 'auto_backup_state_store.dart';
import 'auto_backup_work_names.dart';
import 'backup_constants.dart';
import 'backup_provider_preferences.dart';
import 'backup_scheduler.dart';
import 'scheduled_backup_logic.dart';

/// WorkManager task handlers for daily evaluator, catch-up, and interval backup.
class AutoBackupWorker {
  AutoBackupWorker._();

  static Future<bool> handleTask(String task, Logger logger) async {
    if (task == AutoBackupWorkNames.dailyEvaluatorTask) {
      return _runDailyEvaluator(logger);
    }
    if (task == AutoBackupWorkNames.catchupTask) {
      return _runCatchup(logger);
    }
    if (task == AutoBackupWorkNames.intervalTask) {
      return _runIntervalBackup(logger);
    }
    logger.info('Ignoring unrelated backup task: $task');
    return true;
  }

  /// Evaluator only — never calls [BackupService.startBackup].
  static Future<bool> _runDailyEvaluator(Logger logger) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
            false;
    final frequency =
        prefs.getString(BackupConstants.settingsKeys['backup_frequency']!) ??
            'off';

    if (!enabled || frequency != 'daily') {
      logger.info('Daily evaluator skipped: disabled or not daily');
      return true;
    }

    final store = AutoBackupStateStore(prefs: prefs);
    final dueMinute = await store.getDueMinuteOfDay();
    final pending = await store.applyDueTick(
      nowLocal: DateTime.now(),
      dueMinuteOfDay: dueMinute,
    );

    final plan = AutoBackupRunPlanner.planEvaluatorTick(
      pendingAfterTick: pending,
    );

    if (plan.action == AutoBackupPlannerAction.enqueueCatchup &&
        plan.pendingDueDay != null) {
      final wifiOnly =
          prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ?? true;
      final provider = await BackupProviderPreferences.getSelectedProvider();
      await AutoBackupScheduler().registerCatchup(
        provider: provider,
        wifiOnly: wifiOnly,
      );
      AutoBackupLog.scheduler(
        'enqueue catchup dueDay=${plan.pendingDueDay} (evaluator)',
      );
      logger.info('Evaluator enqueued catch-up for ${plan.pendingDueDay}');
    }

    return true;
  }

  static Future<bool> _runCatchup(Logger logger) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
            false;
    final frequency =
        prefs.getString(BackupConstants.settingsKeys['backup_frequency']!) ??
            'off';

    if (!enabled || frequency != 'daily') {
      return true;
    }

    final store = AutoBackupStateStore(prefs: prefs);
    final pendingAtStart = await store.getPendingDueDay();
    if (pendingAtStart == null) {
      logger.info('Catch-up: no pending due day');
      return true;
    }

    final runDueDay = pendingAtStart;
    AutoBackupLog.worker('catchup start runDueDay=$runDueDay');

    await BackupScheduler.initializeBackgroundDependencies(logger);

    final flightLogsBox = await (BackupScheduler.openFlightLogsBoxForTesting ??
            () =>
                HiveInitializationService.openBox<FlightLog>('flightLogsBox'))();
    final hasFlightLogs = flightLogsBox.isNotEmpty;

    final provider = await BackupProviderPreferences.getSelectedProvider();

    final driveReady = provider != BackupProvider.googleDrive
        ? true
        : await _isDriveReady(interactive: false);

    final lockFree = await AutoBackupConditionsEvaluator.isOperationLockFree();

    final networkSatisfied = await _isNetworkSatisfied(prefs);

    final ctx = AutoBackupExecutionContext(
      autoBackupEnabled: enabled,
      frequency: frequency,
      provider: provider,
      hasFlightLogs: hasFlightLogs,
      pendingDueDay: pendingAtStart,
      lastSuccessDueDay: await store.getLastSuccessDueDay(),
      driveReady: driveReady,
      networkSatisfied: networkSatisfied,
      batteryOk: true,
      storageOk: true,
      lockFree: lockFree,
    );

    final plan = AutoBackupRunPlanner.planCatchupExecution(ctx);
    if (plan.action != AutoBackupPlannerAction.executeCatchup) {
      if (plan.blockReason != null) {
        final reason =
            AutoBackupConditionsEvaluator.failureMessageFor(plan.blockReason!);
        await store.recordAttemptFailure(reason);
        AutoBackupLog.worker('conditions blocked reason=$reason');
        logger.info('Catch-up blocked: ${plan.blockReason}');
      }
      return plan.reportWorkmanagerSuccess;
    }

    if (plan.runDueDay != runDueDay) {
      logger.warning('Catch-up runDueDay mismatch; aborting');
      return true;
    }

    final backupService = BackupService();
    final success = await backupService.startBackup(interactive: false);

    if (success) {
      await store.commitSuccess(runDueDay, DateTime.now());
      AutoBackupLog.worker('backup verified success runDueDay=$runDueDay');
      logger.info('Catch-up success for due day $runDueDay');
      return true;
    }

    await store.recordAttemptFailure('backup_failed');
    AutoBackupLog.worker('backup failed runDueDay=$runDueDay');
    return false;
  }

  static Future<bool> _runIntervalBackup(Logger logger) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
            false;
    final frequency =
        prefs.getString(BackupConstants.settingsKeys['backup_frequency']!) ??
            'off';

    if (frequency == 'daily') {
      logger.info('Interval worker ignored: frequency is daily');
      return true;
    }

    final provider = await BackupProviderPreferences.getSelectedProvider();
    final preInitPlan = planScheduledBackup(
      autoBackupEnabled: enabled,
      frequency: frequency,
      provider: provider,
      hasFlightLogs: true,
    );

    if (!preInitPlan.shouldRunBackup) {
      switch (preInitPlan.skipReason) {
        case ScheduledBackupSkipReason.disabled:
          logger.info('Interval backup disabled; skipping');
          break;
        case ScheduledBackupSkipReason.unsupportedProvider:
          logger.warning('Interval backup: unsupported provider');
          break;
        case ScheduledBackupSkipReason.noFlightLogs:
        case null:
          break;
      }
      return preInitPlan.reportWorkmanagerSuccess;
    }

    await BackupScheduler.initializeBackgroundDependencies(logger);

    final flightLogsBox = await (BackupScheduler.openFlightLogsBoxForTesting ??
            () =>
                HiveInitializationService.openBox<FlightLog>('flightLogsBox'))();
    if (flightLogsBox.isEmpty) {
      logger.info('No flight logs; skipping interval backup');
      return true;
    }

    final backupService = BackupService();
    final success = await backupService.startBackup(interactive: false);
    return success;
  }

  static Future<bool> _isNetworkSatisfied(SharedPreferences prefs) async {
    if (kDebugMode &&
        (prefs.getBool(AutoBackupDebugQa.simulateWifiUnavailableKey) ??
            false)) {
      return false;
    }
    return true;
  }

  static Future<bool> _isDriveReady({required bool interactive}) async {
    try {
      return BackupService().initialize(interactive: interactive);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Drive readiness check failed: $e');
      }
      return false;
    }
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/services/hive_initialization_service.dart';
import '../../firebase_options.dart';
import '../../models/flight_log.dart';
import '../models/backup_metadata.dart';
import '../models/backup_provider_enum.dart';
import '../services/backup_service.dart';
import 'auto_backup_conditions.dart';
import 'auto_backup_due_engine.dart';
import 'auto_backup_network_preference.dart';
import 'auto_backup_reconciler.dart';
import 'auto_backup_scheduler.dart';
import 'auto_backup_state_store.dart';
import 'auto_backup_status_resolver.dart';
import 'auto_backup_work_names.dart';
import 'auto_backup_worker.dart';
import 'backup_constants.dart';
import 'backup_provider_preferences.dart';

/// Test seam for WorkManager calls (set only in tests).
@visibleForTesting
class BackupSchedulerWorkmanager {
  static Future<void> Function(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required Constraints constraints,
    required Duration initialDelay,
    required BackoffPolicy backoffPolicy,
    required Duration backoffPolicyDelay,
    required ExistingPeriodicWorkPolicy existingWorkPolicy,
    String? tag,
  })? registerPeriodicTask;

  static Future<void> Function(
    String uniqueName,
    String taskName, {
    required Constraints constraints,
    required Duration initialDelay,
    required BackoffPolicy backoffPolicy,
    required Duration backoffPolicyDelay,
    required ExistingWorkPolicy existingWorkPolicy,
    String? tag,
  })? registerOneOffTask;

  static Future<void> Function(String uniqueName)? cancelByUniqueName;
  static Future<void> Function(String tag)? cancelByTag;
  static Future<bool> Function(String uniqueName)? isScheduledByUniqueName;

  static final List<String> cancelLog = [];
  static final List<String> registerLog = [];

  /// Tracks active unique work names for mutual-exclusion regression tests.
  static final Set<String> activeUniqueNames = {};

  @visibleForTesting
  static void resetTestHooks() {
    registerPeriodicTask = null;
    registerOneOffTask = null;
    cancelByUniqueName = null;
    cancelByTag = null;
    isScheduledByUniqueName = null;
    cancelLog.clear();
    registerLog.clear();
    activeUniqueNames.clear();
  }
}

/// Service for scheduling automatic backups using WorkManager.
class BackupScheduler {
  static final _logger = Logger('BackupScheduler');
  static final _wmScheduler = AutoBackupScheduler();
  static final _reconciler = AutoBackupReconciler();

  BackupScheduler();

  static Future<SharedPreferences> sharedPreferences() =>
      SharedPreferences.getInstance();

  static int? scheduleIntervalSeconds(String frequency) =>
      BackupConstants.scheduleIntervals[frequency];

  /// Initialize the backup scheduler.
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
      _logger.info('Backup scheduler initialized');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize backup scheduler', e, stackTrace);
    }
  }

  /// Restore the saved auto-backup schedule after app startup.
  static Future<void> restoreSavedSchedule() async {
    try {
      final prefs = await sharedPreferences();
      final enabled =
          prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
              false;
      final defaultFrequency =
          BackupConstants.defaultSettings['backup_frequency'] as String;
      final frequency = prefs.getString(
            BackupConstants.settingsKeys['backup_frequency']!,
          ) ??
          defaultFrequency;
      final wifiOnly =
          prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ??
              (BackupConstants.defaultSettings['wifi_only'] as bool);

      if (!enabled || frequency == 'off') {
        await BackupScheduler().cancelBackup(updateSettings: false);
        return;
      }

      await _reconciler.reconcileOnStartup(
        enabled: enabled,
        frequency: frequency,
        wifiOnly: wifiOnly,
      );
    } catch (e, stackTrace) {
      _logger.severe('Failed to restore backup schedule', e, stackTrace);
    }
  }

  /// Schedule automatic backup (dual path: daily vs weekly/monthly).
  Future<bool> scheduleBackup({
    required String frequency,
    bool wifiOnly = true,
  }) async {
    try {
      final prefs = await sharedPreferences();

      if (frequency == 'off') {
        await _wmScheduler.cancelAllAutoBackupWork();
        await prefs.setString(
          BackupConstants.settingsKeys['backup_frequency']!,
          frequency,
        );
        await prefs.setBool(
          BackupConstants.settingsKeys['wifi_only']!,
          wifiOnly,
        );
        await prefs.setBool(
          BackupConstants.settingsKeys['auto_backup_enabled']!,
          false,
        );
        _logger.info('Backup scheduling disabled');
        return true;
      }

      if (frequency == 'daily') {
        await _wmScheduler.cancelIntervalPath();
        await _wmScheduler.cancelLegacyWork();
        await _wmScheduler.registerDailyEvaluator();
        await prefs.setString(
          BackupConstants.settingsKeys['backup_frequency']!,
          frequency,
        );
        await prefs.setBool(
          BackupConstants.settingsKeys['wifi_only']!,
          wifiOnly,
        );
        await prefs.setBool(
          BackupConstants.settingsKeys['auto_backup_enabled']!,
          true,
        );
        await _reconciler.reconcileOnStartup(
          enabled: true,
          frequency: 'daily',
          wifiOnly: wifiOnly,
        );
        _logger.info('Daily auto backup scheduled (23:59 due anchor)');
        return true;
      }

      if (frequency == 'weekly' || frequency == 'monthly') {
        final interval = scheduleIntervalSeconds(frequency);
        if (interval == null || interval == 0) {
          _logger.warning('Invalid backup frequency: $frequency');
          return false;
        }

        await _wmScheduler.cancelDailyPath();
        await AutoBackupStateStore().clearDailyAutoBackupState();
        await _wmScheduler.cancelLegacyWork();

        final provider = await BackupProviderPreferences.getSelectedProvider();
        await _wmScheduler.registerIntervalPeriodic(
          frequency: frequency,
          provider: provider,
          wifiOnly: wifiOnly,
        );

        await prefs.setString(
          BackupConstants.settingsKeys['backup_frequency']!,
          frequency,
        );
        await prefs.setBool(
          BackupConstants.settingsKeys['wifi_only']!,
          wifiOnly,
        );
        await prefs.setBool(
          BackupConstants.settingsKeys['auto_backup_enabled']!,
          true,
        );
        _logger.info('Interval auto backup scheduled: $frequency');
        return true;
      }

      _logger.warning('Invalid backup frequency: $frequency');
      return false;
    } catch (e, stackTrace) {
      _logger.severe('Failed to schedule backup', e, stackTrace);
      return false;
    }
  }

  /// Cancel automatic backup.
  Future<bool> cancelBackup({bool updateSettings = true}) async {
    try {
      await _wmScheduler.cancelAllAutoBackupWork();

      if (updateSettings) {
        final prefs = await sharedPreferences();
        await prefs.setBool(
          BackupConstants.settingsKeys['auto_backup_enabled']!,
          false,
        );
        await prefs.setString(
          BackupConstants.settingsKeys['backup_frequency']!,
          'off',
        );
      }

      _logger.info('Backup schedule cancelled');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to cancel backup schedule', e, stackTrace);
      return false;
    }
  }

  /// Check if backup is scheduled for the current frequency mode.
  Future<bool> isBackupScheduled() async {
    try {
      final prefs = await sharedPreferences();
      final enabled =
          prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
              false;
      if (!enabled) return false;

      final frequency = await getBackupFrequency();
      if (frequency == 'daily') {
        try {
          return await isScheduledByUniqueNameInternal(
            AutoBackupWorkNames.dailyEvaluatorUnique,
          );
        } catch (_) {
          return enabled;
        }
      }

      try {
        return await isScheduledByUniqueNameInternal(
          AutoBackupWorkNames.intervalPeriodicUnique,
        );
      } catch (_) {
        return enabled;
      }
    } catch (e) {
      _logger.warning('Error checking backup schedule: $e');
      return false;
    }
  }

  Future<String> getBackupFrequency() async {
    try {
      final prefs = await sharedPreferences();
      return prefs
              .getString(BackupConstants.settingsKeys['backup_frequency']!) ??
          'off';
    } catch (e) {
      _logger.warning('Error getting backup frequency: $e');
      return 'off';
    }
  }

  Future<bool> isWifiOnly() async {
    try {
      final prefs = await sharedPreferences();
      return prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ??
          AutoBackupNetworkPreference.defaultWifiOnly;
    } catch (e) {
      _logger.warning('Error checking Wi-Fi only setting: $e');
      return true;
    }
  }

  /// Legacy immediate backup — interval path only; daily uses catch-up.
  Future<bool> scheduleImmediateBackup({bool? wifiOnly}) async {
    final frequency = await getBackupFrequency();
    if (frequency == 'daily') {
      final effectiveWifiOnly = wifiOnly ?? await isWifiOnly();
      final provider = await BackupProviderPreferences.getSelectedProvider();
      await _wmScheduler.registerCatchup(
        provider: provider,
        wifiOnly: effectiveWifiOnly,
      );
      return true;
    }

    try {
      final effectiveWifiOnly = wifiOnly ?? await isWifiOnly();
      final provider = await BackupProviderPreferences.getSelectedProvider();
      final constraints = constraintsForProvider(
        provider,
        wifiOnly: effectiveWifiOnly,
      );

      await registerOneOffTaskInternal(
        uniqueName: AutoBackupWorkNames.legacyImmediateUnique,
        taskName: AutoBackupWorkNames.intervalTask,
        constraints: constraints,
        initialDelay: const Duration(seconds: 10),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        tag: AutoBackupWorkNames.taskTag,
      );
      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to schedule immediate backup', e, stackTrace);
      return false;
    }
  }

  Future<bool> scheduleImmediateBackupIfOverdue() async {
    final frequency = await getBackupFrequency();
    if (frequency == 'daily') {
      final store = AutoBackupStateStore();
      final dueMinute = await store.getDueMinuteOfDay();
      await store.applyDueTick(
        nowLocal: DateTime.now(),
        dueMinuteOfDay: dueMinute,
      );
      final pending = await store.getPendingDueDay();
      if (pending == null) return false;
      return scheduleImmediateBackup(wifiOnly: await isWifiOnly());
    }

    try {
      final status = await getBackupStatus();
      if (!status.isScheduled || !status.isOverdue) {
        return false;
      }
      return scheduleImmediateBackup(wifiOnly: status.wifiOnly);
    } catch (e, stackTrace) {
      _logger.severe('Failed to schedule overdue backup', e, stackTrace);
      return false;
    }
  }

  Future<DateTime?> getNextBackupTime() async {
    try {
      final frequency = await getBackupFrequency();
      if (frequency == 'off') return null;

      if (frequency == 'daily') {
        final store = AutoBackupStateStore();
        final dueMinute = await store.getDueMinuteOfDay();
        return AutoBackupDueEngine.nextDueDateTime(
          nowLocal: DateTime.now(),
          dueMinuteOfDay: dueMinute,
        );
      }

      final interval = scheduleIntervalSeconds(frequency);
      if (interval == null || interval == 0) return null;

      final prefs = await sharedPreferences();
      final lastBackupTime =
          prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!);

      if (lastBackupTime == null) {
        return DateTime.now().add(Duration(seconds: interval));
      }

      final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupTime);
      return lastBackup.add(Duration(seconds: interval));
    } catch (e) {
      _logger.warning('Error getting next backup time: $e');
      return null;
    }
  }

  @Deprecated('Use BackupService verified success path only')
  Future<void> updateLastBackupTime() async {
    try {
      final prefs = await sharedPreferences();
      await prefs.setInt(
        BackupConstants.settingsKeys['last_backup_time']!,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      _logger.warning('Error updating last backup time: $e');
    }
  }

  Future<bool> isBackupOverdue() async {
    try {
      final frequency = await getBackupFrequency();
      if (frequency == 'daily') {
        final store = AutoBackupStateStore();
        final pending = await store.getPendingDueDay();
        return pending != null;
      }

      final nextBackupTime = await getNextBackupTime();
      if (nextBackupTime == null) return false;
      return DateTime.now().isAfter(nextBackupTime);
    } catch (e) {
      _logger.warning('Error checking if backup is overdue: $e');
      return false;
    }
  }

  Future<BackupScheduleStatus> reconcileAndGetBackupStatus() async {
    await _reconciler.reconcile();
    return getBackupStatus();
  }

  Future<BackupScheduleStatus> getBackupStatus() async {
    try {
      final isScheduled = await isBackupScheduled();
      final frequency = await getBackupFrequency();
      final wifiOnly = await isWifiOnly();
      final nextBackupTime = await getNextBackupTime();
      final isOverdue = await isBackupOverdue();
      final store = AutoBackupStateStore();
      final pendingDueDay = frequency == 'daily'
          ? await store.getPendingDueDay()
          : null;
      final lastSuccessAt = frequency == 'daily'
          ? await store.getLastSuccessAt()
          : null;

      String? pendingStatusMessage;
      if (pendingDueDay != null && frequency == 'daily') {
        pendingStatusMessage = await _resolvePendingStatusMessage(
          wifiOnly: wifiOnly,
        );
      }

      return BackupScheduleStatus(
        isScheduled: isScheduled,
        frequency: frequency,
        wifiOnly: wifiOnly,
        nextBackupTime: nextBackupTime,
        isOverdue: isOverdue,
        pendingDueDay: pendingDueDay,
        lastAutoBackupSuccessAt: lastSuccessAt,
        pendingStatusMessage: pendingStatusMessage,
      );
    } catch (e, stackTrace) {
      _logger.severe('Error getting backup status', e, stackTrace);
      return const BackupScheduleStatus(
        isScheduled: false,
        frequency: 'off',
        wifiOnly: true,
        nextBackupTime: null,
        isOverdue: false,
      );
    }
  }

  Future<String> _resolvePendingStatusMessage({
    required bool wifiOnly,
  }) async {
    final provider = await BackupProviderPreferences.getSelectedProvider();
    final networkSatisfied =
        await AutoBackupConditionsEvaluator.isNetworkSatisfiedForAutoBackup(
      wifiOnly: wifiOnly,
    );
    var driveReady = true;
    if (provider == BackupProvider.googleDrive) {
      try {
        driveReady = await BackupService().initialize(interactive: false);
      } catch (_) {
        driveReady = false;
      }
    }
    final lockFree = await AutoBackupConditionsEvaluator.isOperationLockFree();
    return AutoBackupStatusResolver.resolvePendingMessage(
      AutoBackupPendingContext(
        wifiOnly: wifiOnly,
        provider: provider,
        networkSatisfied: networkSatisfied,
        driveReady: driveReady,
        operationLockFree: lockFree,
      ),
    );
  }

  static Constraints constraintsForProvider(
    BackupProvider provider, {
    required bool wifiOnly,
  }) {
    final networkType = switch (provider) {
      BackupProvider.local => NetworkType.notRequired,
      BackupProvider.googleDrive =>
        wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      BackupProvider.firebase => NetworkType.connected,
    };

    return Constraints(
      networkType: networkType,
      requiresBatteryNotLow: true,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: true,
    );
  }

  static Future<void> registerPeriodicTaskInternal({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required Constraints constraints,
    required Duration initialDelay,
    required BackoffPolicy backoffPolicy,
    required Duration backoffPolicyDelay,
    required ExistingPeriodicWorkPolicy existingWorkPolicy,
    String? tag,
  }) async {
    final override = BackupSchedulerWorkmanager.registerPeriodicTask;
    if (override != null) {
      BackupSchedulerWorkmanager.registerLog.add(uniqueName);
      BackupSchedulerWorkmanager.activeUniqueNames.add(uniqueName);
      await override(
        uniqueName,
        taskName,
        frequency: frequency,
        constraints: constraints,
        initialDelay: initialDelay,
        backoffPolicy: backoffPolicy,
        backoffPolicyDelay: backoffPolicyDelay,
        existingWorkPolicy: existingWorkPolicy,
        tag: tag,
      );
      return;
    }

    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: frequency,
      constraints: constraints,
      initialDelay: initialDelay,
      backoffPolicy: backoffPolicy,
      backoffPolicyDelay: backoffPolicyDelay,
      existingWorkPolicy: existingWorkPolicy,
      tag: tag,
    );
  }

  static Future<void> registerOneOffTaskInternal({
    required String uniqueName,
    required String taskName,
    required Constraints constraints,
    required Duration initialDelay,
    required BackoffPolicy backoffPolicy,
    required Duration backoffPolicyDelay,
    required ExistingWorkPolicy existingWorkPolicy,
    String? tag,
  }) async {
    final override = BackupSchedulerWorkmanager.registerOneOffTask;
    if (override != null) {
      BackupSchedulerWorkmanager.registerLog.add(uniqueName);
      await override(
        uniqueName,
        taskName,
        constraints: constraints,
        initialDelay: initialDelay,
        backoffPolicy: backoffPolicy,
        backoffPolicyDelay: backoffPolicyDelay,
        existingWorkPolicy: existingWorkPolicy,
        tag: tag,
      );
      return;
    }

    await Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      constraints: constraints,
      initialDelay: initialDelay,
      backoffPolicy: backoffPolicy,
      backoffPolicyDelay: backoffPolicyDelay,
      existingWorkPolicy: existingWorkPolicy,
      tag: tag,
    );
  }

  static Future<void> cancelByUniqueNameInternal(String uniqueName) async {
    final override = BackupSchedulerWorkmanager.cancelByUniqueName;
    if (override != null) {
      BackupSchedulerWorkmanager.cancelLog.add(uniqueName);
      BackupSchedulerWorkmanager.activeUniqueNames.remove(uniqueName);
      await override(uniqueName);
      return;
    }
    await Workmanager().cancelByUniqueName(uniqueName);
  }

  static Future<void> cancelByTagInternal(String tag) async {
    final override = BackupSchedulerWorkmanager.cancelByTag;
    if (override != null) {
      BackupSchedulerWorkmanager.cancelLog.add('tag:$tag');
      await override(tag);
      return;
    }
    await Workmanager().cancelByTag(tag);
  }

  static Future<bool> isScheduledByUniqueNameInternal(String uniqueName) async {
    final override = BackupSchedulerWorkmanager.isScheduledByUniqueName;
    if (override != null) {
      return override(uniqueName);
    }
    return Workmanager().isScheduledByUniqueName(uniqueName);
  }

  Future<bool> runScheduledBackupForTesting() async {
    final frequency = await getBackupFrequency();
    if (frequency == 'daily') {
      return AutoBackupWorker.handleTask(
        AutoBackupWorkNames.catchupTask,
        _logger,
      );
    }
    return AutoBackupWorker.handleTask(
      AutoBackupWorkNames.intervalTask,
      _logger,
    );
  }

  Future<bool> runDailyEvaluatorForTesting() async {
    return AutoBackupWorker.handleTask(
      AutoBackupWorkNames.dailyEvaluatorTask,
      _logger,
    );
  }

  @visibleForTesting
  static Future<void> Function(Logger logger)?
      backgroundDependenciesInitializer;

  static Future<Box<FlightLog>> Function()? openFlightLogsBoxForTesting;

  static Future<void> initializeBackgroundDependencies(Logger logger) =>
      _initializeBackgroundBackupDependencies(logger);
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final logger = Logger('BackupTask');

    try {
      DartPluginRegistrant.ensureInitialized();
      logger.info('Starting backup task: $task');

      if (task == Workmanager.iOSBackgroundTask) {
        return AutoBackupWorker.handleTask(
          AutoBackupWorkNames.intervalTask,
          logger,
        );
      }

      return await AutoBackupWorker.handleTask(task, logger);
    } catch (e, stackTrace) {
      logger.severe('Backup task failed', e, stackTrace);
      return false;
    }
  });
}

Future<void> _initializeBackgroundBackupDependencies(Logger logger) async {
  final testInit = BackupScheduler.backgroundDependenciesInitializer;
  if (testInit != null) {
    await testInit(logger);
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await HiveInitializationService.initialize();
  await HiveInitializationService.openBox<FlightLog>('flightLogsBox');
  await HiveInitializationService.openBox<BackupMetadata>('backupMetadata');

  logger.info('Background backup dependencies initialized.');
}

class BackupScheduleStatus {
  final bool isScheduled;
  final String frequency;
  final bool wifiOnly;
  final DateTime? nextBackupTime;
  final bool isOverdue;
  final String? pendingDueDay;
  final DateTime? lastAutoBackupSuccessAt;
  final String? pendingStatusMessage;

  const BackupScheduleStatus({
    required this.isScheduled,
    required this.frequency,
    required this.wifiOnly,
    required this.nextBackupTime,
    required this.isOverdue,
    this.pendingDueDay,
    this.lastAutoBackupSuccessAt,
    this.pendingStatusMessage,
  });

  String get nextBackupTimeFormatted {
    if (nextBackupTime == null) {
      return 'Not scheduled';
    }

    final now = DateTime.now();
    final difference = nextBackupTime!.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'Soon';
    }
  }

  String get frequencyDisplayName {
    switch (frequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'off':
        return 'Off';
      default:
        return 'Unknown';
    }
  }
}

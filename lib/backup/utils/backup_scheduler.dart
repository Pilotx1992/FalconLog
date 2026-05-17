import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/services/hive_initialization_service.dart';
import '../../firebase_options.dart';
import '../../models/flight_log.dart';
import '../models/backup_metadata.dart';
import '../models/backup_provider_enum.dart';
import '../services/backup_service.dart';
import 'backup_constants.dart';
import 'backup_provider_preferences.dart';

/// Service for scheduling automatic backups using WorkManager.
class BackupScheduler {
  static const String _uniqueName = 'falconlog_auto_backup_periodic';
  static const String _taskName = 'falconlog_auto_backup';
  static const String _taskTag = 'falconlog_backup';

  static const String _immediateUniqueName = 'falconlog_auto_backup_immediate';

  // Names from older implementations. They are cancelled when rescheduling.
  static const String _legacyUniqueName = 'falconlog_backup_task';
  static const String _legacyBackgroundUniqueName = 'encrypted_local_backup';

  static final _logger = Logger('BackupScheduler');

  BackupScheduler();

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
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
              false;
      final defaultFrequency =
          BackupConstants.defaultSettings['backup_frequency'] as String;
      final frequency = prefs.getString(
            BackupConstants.settingsKeys['backup_frequency']!,
          ) ??
          defaultFrequency;

      if (!enabled || frequency == 'off') {
        return;
      }

      final wifiOnly =
          prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ??
              (BackupConstants.defaultSettings['wifi_only'] as bool);

      final scheduler = BackupScheduler();
      var scheduled = false;
      try {
        scheduled = await Workmanager().isScheduledByUniqueName(_uniqueName);
      } catch (_) {
        // Some platforms do not support schedule inspection.
      }

      if (!scheduled) {
        scheduled = await scheduler.scheduleBackup(
          frequency: frequency,
          wifiOnly: wifiOnly,
        );
      }

      if (scheduled) {
        await scheduler.scheduleImmediateBackupIfOverdue();
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to restore backup schedule', e, stackTrace);
    }
  }

  /// Schedule automatic backup.
  Future<bool> scheduleBackup({
    required String frequency,
    bool wifiOnly = true,
  }) async {
    try {
      await _cancelScheduledWork();

      final prefs = await SharedPreferences.getInstance();

      if (frequency == 'off') {
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

      final interval = BackupConstants.scheduleIntervals[frequency];
      if (interval == null || interval == 0) {
        _logger.warning('Invalid backup frequency: $frequency');
        return false;
      }

      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: Duration(seconds: interval),
        constraints: Constraints(
          networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: true,
        ),
        initialDelay: const Duration(minutes: 5),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        tag: _taskTag,
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

      _logger.info('Backup scheduled: $frequency (Wi-Fi only: $wifiOnly)');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to schedule backup', e, stackTrace);
      return false;
    }
  }

  /// Cancel automatic backup.
  Future<bool> cancelBackup({bool updateSettings = true}) async {
    try {
      await _cancelScheduledWork();

      if (updateSettings) {
        final prefs = await SharedPreferences.getInstance();
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

  /// Check if backup is scheduled.
  Future<bool> isBackupScheduled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
              false;
      if (!enabled) {
        return false;
      }

      try {
        return await Workmanager().isScheduledByUniqueName(_uniqueName);
      } catch (_) {
        return enabled;
      }
    } catch (e) {
      _logger.warning('Error checking backup schedule: $e');
      return false;
    }
  }

  /// Get current backup frequency.
  Future<String> getBackupFrequency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs
              .getString(BackupConstants.settingsKeys['backup_frequency']!) ??
          'off';
    } catch (e) {
      _logger.warning('Error getting backup frequency: $e');
      return 'off';
    }
  }

  /// Check if Wi-Fi only is enabled.
  Future<bool> isWifiOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ?? true;
    } catch (e) {
      _logger.warning('Error checking Wi-Fi only setting: $e');
      return true;
    }
  }

  /// Schedule immediate backup (for catch-up/testing).
  Future<bool> scheduleImmediateBackup({bool? wifiOnly}) async {
    try {
      final effectiveWifiOnly = wifiOnly ?? await isWifiOnly();
      await Workmanager().registerOneOffTask(
        _immediateUniqueName,
        _taskName,
        constraints: Constraints(
          networkType:
              effectiveWifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresStorageNotLow: true,
        ),
        initialDelay: const Duration(seconds: 10),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        tag: _taskTag,
      );

      _logger.info('Immediate backup scheduled');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to schedule immediate backup', e, stackTrace);
      return false;
    }
  }

  /// Schedule a catch-up backup if the saved schedule is overdue.
  Future<bool> scheduleImmediateBackupIfOverdue() async {
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

  /// Get next backup time estimate.
  Future<DateTime?> getNextBackupTime() async {
    try {
      final frequency = await getBackupFrequency();
      if (frequency == 'off') {
        return null;
      }

      final interval = BackupConstants.scheduleIntervals[frequency];
      if (interval == null || interval == 0) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
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

  /// Update last backup time.
  Future<void> updateLastBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        BackupConstants.settingsKeys['last_backup_time']!,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      _logger.warning('Error updating last backup time: $e');
    }
  }

  /// Check if backup is overdue.
  Future<bool> isBackupOverdue() async {
    try {
      final nextBackupTime = await getNextBackupTime();
      if (nextBackupTime == null) {
        return false;
      }

      return DateTime.now().isAfter(nextBackupTime);
    } catch (e) {
      _logger.warning('Error checking if backup is overdue: $e');
      return false;
    }
  }

  /// Get backup status information.
  Future<BackupScheduleStatus> getBackupStatus() async {
    try {
      final isScheduled = await isBackupScheduled();
      final frequency = await getBackupFrequency();
      final wifiOnly = await isWifiOnly();
      final nextBackupTime = await getNextBackupTime();
      final isOverdue = await isBackupOverdue();

      return BackupScheduleStatus(
        isScheduled: isScheduled,
        frequency: frequency,
        wifiOnly: wifiOnly,
        nextBackupTime: nextBackupTime,
        isOverdue: isOverdue,
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

  Future<void> _cancelScheduledWork() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
    await Workmanager().cancelByUniqueName(_immediateUniqueName);
    await Workmanager().cancelByUniqueName(_legacyUniqueName);
    await Workmanager().cancelByUniqueName(_legacyBackgroundUniqueName);
    await Workmanager().cancelByTag(_taskTag);
  }
}

/// Callback dispatcher for WorkManager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final logger = Logger('BackupTask');

    try {
      DartPluginRegistrant.ensureInitialized();
      logger.info('Starting scheduled backup task: $task');

      if (task != BackupScheduler._taskName &&
          task != Workmanager.iOSBackgroundTask) {
        logger.info('Ignoring unrelated task: $task');
        return true;
      }

      final success = await _runScheduledBackup(logger);
      logger.info('Scheduled backup task completed: $task success=$success');
      return success;
    } catch (e, stackTrace) {
      logger.severe('Scheduled backup task failed', e, stackTrace);
      return false;
    }
  });
}

Future<bool> _runScheduledBackup(Logger logger) async {
  final prefs = await SharedPreferences.getInstance();
  final enabled =
      prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
          false;
  final frequency =
      prefs.getString(BackupConstants.settingsKeys['backup_frequency']!) ??
          'off';

  if (!enabled || frequency == 'off') {
    logger.info('Auto backup is disabled; skipping task.');
    return true;
  }

  await _initializeBackgroundBackupDependencies(logger);

  final provider = await BackupProviderPreferences.getSelectedProvider();
  if (provider == BackupProvider.firebase) {
    logger.warning(
      'Scheduled backup skipped: Firebase provider is not supported.',
    );
    return false;
  }

  final flightLogsBox =
      await HiveInitializationService.openBox<FlightLog>('flightLogsBox');
  if (flightLogsBox.isEmpty) {
    logger.info('No flight logs to back up; skipping task.');
    return true;
  }

  final backupService = BackupService();
  final success = await backupService.startBackup(interactive: false);

  if (success) {
    await BackupScheduler().updateLastBackupTime();
  }

  return success;
}

Future<void> _initializeBackgroundBackupDependencies(Logger logger) async {
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

/// Backup schedule status information.
class BackupScheduleStatus {
  final bool isScheduled;
  final String frequency;
  final bool wifiOnly;
  final DateTime? nextBackupTime;
  final bool isOverdue;

  const BackupScheduleStatus({
    required this.isScheduled,
    required this.frequency,
    required this.wifiOnly,
    required this.nextBackupTime,
    required this.isOverdue,
  });

  /// Get formatted next backup time.
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

  /// Get frequency display name.
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

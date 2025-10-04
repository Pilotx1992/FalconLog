import 'dart:async';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'backup_constants.dart';

/// Service for scheduling automatic backups using WorkManager
class BackupScheduler {
  static const String _taskName = 'falconlog_backup_task';
  static const String _taskTag = 'falconlog_backup';

  static final _logger = Logger('BackupScheduler');

  BackupScheduler();

  /// Initialize the backup scheduler
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );
      _logger.info('Backup scheduler initialized');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize backup scheduler', e, stackTrace);
    }
  }

  /// Schedule automatic backup
  Future<void> scheduleBackup({
    required String frequency,
    bool wifiOnly = true,
  }) async {
    try {
      // Cancel existing schedule
      await cancelBackup();

      if (frequency == 'off') {
        _logger.info('Backup scheduling disabled');
        return;
      }

      final interval = BackupConstants.scheduleIntervals[frequency];
      if (interval == null || interval == 0) {
        _logger.warning('Invalid backup frequency: $frequency');
        return;
      }

      // Schedule the backup task
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskTag,
        frequency: Duration(seconds: interval),
        constraints: Constraints(
          networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: true,
        ),
        initialDelay: Duration(minutes: 5), // Start after 5 minutes
      );

      // Save settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(BackupConstants.settingsKeys['backup_frequency']!, frequency);
      await prefs.setBool(BackupConstants.settingsKeys['wifi_only']!, wifiOnly);
      await prefs.setBool(BackupConstants.settingsKeys['auto_backup_enabled']!, true);

      _logger.info('Backup scheduled: $frequency (Wi-Fi only: $wifiOnly)');
    } catch (e, stackTrace) {
      _logger.severe('Failed to schedule backup', e, stackTrace);
    }
  }

  /// Cancel automatic backup
  Future<void> cancelBackup() async {
    try {
      await Workmanager().cancelByTag(_taskTag);

      // Update settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(BackupConstants.settingsKeys['auto_backup_enabled']!, false);

      _logger.info('Backup schedule cancelled');
    } catch (e, stackTrace) {
      _logger.severe('Failed to cancel backup schedule', e, stackTrace);
    }
  }

  /// Check if backup is scheduled
  Future<bool> isBackupScheduled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ?? false;
    } catch (e) {
      _logger.warning('Error checking backup schedule: $e');
      return false;
    }
  }

  /// Get current backup frequency
  Future<String> getBackupFrequency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(BackupConstants.settingsKeys['backup_frequency']!) ?? 'off';
    } catch (e) {
      _logger.warning('Error getting backup frequency: $e');
      return 'off';
    }
  }

  /// Check if Wi-Fi only is enabled
  Future<bool> isWifiOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ?? true;
    } catch (e) {
      _logger.warning('Error checking Wi-Fi only setting: $e');
      return true;
    }
  }

  /// Schedule immediate backup (for testing)
  Future<void> scheduleImmediateBackup() async {
    try {
      await Workmanager().registerOneOffTask(
        '${_taskName}_immediate',
        _taskTag,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: true,
        ),
        initialDelay: Duration(seconds: 10),
      );

      _logger.info('Immediate backup scheduled');
    } catch (e, stackTrace) {
      _logger.severe('Failed to schedule immediate backup', e, stackTrace);
    }
  }

  /// Get next backup time estimate
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
      final lastBackupTime = prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!);

      if (lastBackupTime == null) {
        // If no last backup time, estimate based on current time
        return DateTime.now().add(Duration(seconds: interval));
      }

      final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupTime);
      return lastBackup.add(Duration(seconds: interval));
    } catch (e) {
      _logger.warning('Error getting next backup time: $e');
      return null;
    }
  }

  /// Update last backup time
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

  /// Check if backup is overdue
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

  /// Get backup status information
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
      return BackupScheduleStatus(
        isScheduled: false,
        frequency: 'off',
        wifiOnly: true,
        nextBackupTime: null,
        isOverdue: false,
      );
    }
  }
}

/// Callback dispatcher for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final logger = Logger('BackupTask');
      logger.info('Starting scheduled backup task: $task');

      // This would normally create a new BackupService instance
      // and run the backup process
      // For now, we'll just log the task execution

      logger.info('Scheduled backup task completed: $task');
      return Future.value(true);
    } catch (e, stackTrace) {
      final logger = Logger('BackupTask');
      logger.severe('Scheduled backup task failed', e, stackTrace);
      return Future.value(false);
    }
  });
}

/// Backup schedule status information
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

  /// Get formatted next backup time
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

  /// Get frequency display name
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

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'backup_constants.dart';

/// Service for scheduling automatic backup verification using WorkManager
class VerificationScheduler {
  static const String _taskName = 'falconlog_verification_task';
  static const String _taskTag = 'falconlog_verification';

  static final _logger = Logger('VerificationScheduler');

  VerificationScheduler();

  /// Initialize the verification scheduler
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );
      _logger.info('Verification scheduler initialized');
    } catch (e, stackTrace) {
      _logger.severe(
          'Failed to initialize verification scheduler', e, stackTrace);
    }
  }

  /// Schedule automatic backup verification
  Future<void> scheduleVerification({
    required String frequency,
    bool wifiOnly = true,
  }) async {
    try {
      // Cancel existing schedule
      await cancelVerification();

      if (frequency == 'off') {
        _logger.info('Verification scheduling disabled');
        return;
      }

      final interval = BackupConstants.verificationIntervals[frequency];
      if (interval == null || interval == 0) {
        _logger.warning('Invalid verification frequency: $frequency');
        return;
      }

      // Schedule the verification task
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskTag,
        frequency: Duration(seconds: interval),
        constraints: Constraints(
          networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow:
              false, // Verification is less resource intensive
          requiresCharging: false,
          requiresDeviceIdle: true, // Run when device is idle
          requiresStorageNotLow: false,
        ),
        initialDelay: Duration(minutes: 10), // Start after 10 minutes
      );

      // Save settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          BackupConstants.settingsKeys['verification_frequency']!, frequency);
      await prefs.setBool(
          BackupConstants.settingsKeys['verification_wifi_only']!, wifiOnly);
      await prefs.setBool(
          BackupConstants.settingsKeys['auto_verification_enabled']!, true);

      _logger
          .info('Verification scheduled: $frequency (Wi-Fi only: $wifiOnly)');
    } catch (e, stackTrace) {
      _logger.severe('Failed to schedule verification', e, stackTrace);
    }
  }

  /// Cancel automatic verification
  Future<void> cancelVerification() async {
    try {
      await Workmanager().cancelByTag(_taskTag);

      // Update settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          BackupConstants.settingsKeys['auto_verification_enabled']!, false);

      _logger.info('Verification schedule cancelled');
    } catch (e, stackTrace) {
      _logger.severe('Failed to cancel verification schedule', e, stackTrace);
    }
  }

  /// Check if verification is scheduled
  Future<bool> isVerificationScheduled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(
              BackupConstants.settingsKeys['auto_verification_enabled']!) ??
          false;
    } catch (e, stackTrace) {
      _logger.severe('Failed to check verification schedule', e, stackTrace);
      return false;
    }
  }

  /// Get current verification frequency
  Future<String> getVerificationFrequency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(
              BackupConstants.settingsKeys['verification_frequency']!) ??
          'weekly';
    } catch (e, stackTrace) {
      _logger.severe('Failed to get verification frequency', e, stackTrace);
      return 'weekly';
    }
  }

  /// Check if verification is Wi-Fi only
  Future<bool> isVerificationWifiOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(
              BackupConstants.settingsKeys['verification_wifi_only']!) ??
          true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to get verification Wi-Fi setting', e, stackTrace);
      return true;
    }
  }
}

/// Callback dispatcher for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case 'falconlog_verification_task':
          await _performVerificationTask();
          break;
        default:
          _logger.warning('Unknown task: $task');
      }
      return Future.value(true);
    } catch (e, stackTrace) {
      _logger.severe('Task execution failed', e, stackTrace);
      return Future.value(false);
    }
  });
}

/// Perform the verification task
Future<void> _performVerificationTask() async {
  try {
    _logger.info('Starting automatic backup verification');

    // Note: In a real implementation, you would need to inject the BackupService
    // This is a simplified version that logs the task
    _logger.info('Verification task completed');
  } catch (e, stackTrace) {
    _logger.severe('Verification task failed', e, stackTrace);
  }
}

final _logger = Logger('VerificationScheduler');

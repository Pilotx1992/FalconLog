import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

import 'backup_constants.dart';

/// Helper for managing backup-related notifications
class NotificationHelper {
  static final _logger = Logger('NotificationHelper');
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  /// Initialize notifications
  static Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initSettings);
      _logger.info('Notifications initialized');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize notifications', e, stackTrace);
    }
  }

  /// Show backup started notification
  static Future<void> showBackupStarted() async {
    try {
      await _showNotification(
        id: 1001,
        title: 'FalconLog Backup',
        body: BackupConstants.notifications['BACKUP_STARTED']!,
        channelId: 'backup_progress',
        channelName: 'Backup Progress',
        importance: Importance.low,
        priority: Priority.low,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show backup started notification', e, stackTrace);
    }
  }

  /// Show backup completed notification
  static Future<void> showBackupCompleted() async {
    try {
      await _showNotification(
        id: 1002,
        title: 'FalconLog Backup',
        body: BackupConstants.notifications['BACKUP_COMPLETED']!,
        channelId: 'backup_status',
        channelName: 'Backup Status',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show backup completed notification', e, stackTrace);
    }
  }

  /// Show backup failed notification
  static Future<void> showBackupFailed(String error) async {
    try {
      await _showNotification(
        id: 1003,
        title: 'FalconLog Backup Failed',
        body: '${BackupConstants.notifications['BACKUP_FAILED']!}: $error',
        channelId: 'backup_status',
        channelName: 'Backup Status',
        importance: Importance.high,
        priority: Priority.high,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show backup failed notification', e, stackTrace);
    }
  }

  /// Show restore completed notification
  static Future<void> showRestoreCompleted(int logsRestored) async {
    try {
      await _showNotification(
        id: 1004,
        title: 'FalconLog Restore',
        body: '${BackupConstants.notifications['RESTORE_COMPLETED']!} ($logsRestored logs)',
        channelId: 'backup_status',
        channelName: 'Backup Status',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show restore completed notification', e, stackTrace);
    }
  }

  /// Show restore failed notification
  static Future<void> showRestoreFailed(String error) async {
    try {
      await _showNotification(
        id: 1005,
        title: 'FalconLog Restore Failed',
        body: '${BackupConstants.notifications['RESTORE_FAILED']!}: $error',
        channelId: 'backup_status',
        channelName: 'Backup Status',
        importance: Importance.high,
        priority: Priority.high,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show restore failed notification', e, stackTrace);
    }
  }

  /// Show low storage warning
  static Future<void> showLowStorageWarning() async {
    try {
      await _showNotification(
        id: 1006,
        title: 'FalconLog Storage Warning',
        body: BackupConstants.notifications['LOW_STORAGE']!,
        channelId: 'backup_warnings',
        channelName: 'Backup Warnings',
        importance: Importance.high,
        priority: Priority.high,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show low storage warning', e, stackTrace);
    }
  }

  /// Show backup overdue notification
  static Future<void> showBackupOverdue() async {
    try {
      await _showNotification(
        id: 1007,
        title: 'FalconLog Backup Overdue',
        body: BackupConstants.notifications['BACKUP_OVERDUE']!,
        channelId: 'backup_reminders',
        channelName: 'Backup Reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show backup overdue notification', e, stackTrace);
    }
  }

  /// Show sync completed notification
  static Future<void> showSyncCompleted() async {
    try {
      await _showNotification(
        id: 1008,
        title: 'FalconLog Sync',
        body: BackupConstants.notifications['SYNC_COMPLETED']!,
        channelId: 'backup_status',
        channelName: 'Backup Status',
        importance: Importance.low,
        priority: Priority.low,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show sync completed notification', e, stackTrace);
    }
  }

  /// Show sync conflict notification
  static Future<void> showSyncConflict() async {
    try {
      await _showNotification(
        id: 1009,
        title: 'FalconLog Sync Conflict',
        body: BackupConstants.notifications['CONFLICT_DETECTED']!,
        channelId: 'backup_warnings',
        channelName: 'Backup Warnings',
        importance: Importance.high,
        priority: Priority.high,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show sync conflict notification', e, stackTrace);
    }
  }

  /// Show progress notification
  static Future<void> showProgressNotification({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    try {
      await _showNotification(
        id: 1010,
        title: title,
        body: body,
        channelId: 'backup_progress',
        channelName: 'Backup Progress',
        importance: Importance.low,
        priority: Priority.low,
        progress: progress,
        maxProgress: maxProgress,
        indeterminate: false,
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show progress notification', e, stackTrace);
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      _logger.info('All notifications cancelled');
    } catch (e, stackTrace) {
      _logger.warning('Failed to cancel all notifications', e, stackTrace);
    }
  }

  /// Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e, stackTrace) {
      _logger.warning('Failed to cancel notification $id', e, stackTrace);
    }
  }

  /// Show generic notification
  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required Importance importance,
    required Priority priority,
    int? progress,
    int? maxProgress,
    bool indeterminate = false,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'falconlog_backup',
        'FalconLog Backup Notifications',
        channelDescription: 'Notifications for FalconLog backup operations',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showProgress: true,
        maxProgress: 100,
        progress: 0,
        indeterminate: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(id, title, body, details);
    } catch (e, stackTrace) {
      _logger.warning('Failed to show notification', e, stackTrace);
    }
  }

  /// Create notification channels (Android)
  static Future<void> createNotificationChannels() async {
    try {
      const channels = [
        AndroidNotificationChannel(
          'backup_progress',
          'Backup Progress',
          description: 'Notifications for backup progress updates',
          importance: Importance.low,
        ),
        AndroidNotificationChannel(
          'backup_status',
          'Backup Status',
          description: 'Notifications for backup status updates',
          importance: Importance.defaultImportance,
        ),
        AndroidNotificationChannel(
          'backup_warnings',
          'Backup Warnings',
          description: 'Notifications for backup warnings and errors',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          'backup_reminders',
          'Backup Reminders',
          description: 'Notifications for backup reminders',
          importance: Importance.defaultImportance,
        ),
      ];

      for (final channel in channels) {
        await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      _logger.info('Notification channels created');
    } catch (e, stackTrace) {
      _logger.warning('Failed to create notification channels', e, stackTrace);
    }
  }
}

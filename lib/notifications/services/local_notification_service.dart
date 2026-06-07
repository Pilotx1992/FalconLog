import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:logging/logging.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification_channels.dart';
import '../domain/notification_payload.dart';
import 'notification_route_handler.dart';

/// System local notifications (not in-app SnackBars).
class LocalNotificationService {
  LocalNotificationService._();

  static const _notificationColor = Color(0xFF3949AB);

  static final _logger = Logger('LocalNotificationService');
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _timeZonesReady = false;

  @visibleForTesting
  static FlutterLocalNotificationsPlugin? pluginOverride;

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _timeZonesReady = false;
    pluginOverride = null;
  }

  static FlutterLocalNotificationsPlugin get _notifications =>
      pluginOverride ?? _plugin;

  static Future<void> initialize({
    required bool isBackground,
  }) async {
    if (_initialized) return;
    try {
      await _ensureTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse:
            NotificationRouteHandler.onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            onBackgroundNotificationResponse,
      );

      await _createAndroidChannels();
      _initialized = true;
      _logger.info(
        'Local notifications initialized (background=$isBackground)',
      );
    } catch (e, stackTrace) {
      _logger.warning(
          'Failed to initialize local notifications', e, stackTrace);
    }
  }

  static Future<void> _ensureTimeZones() async {
    if (_timeZonesReady) return;
    try {
      tz_data.initializeTimeZones();
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      _timeZonesReady = true;
    } catch (e, stackTrace) {
      _logger.warning('Failed to initialize time zones', e, stackTrace);
    }
  }

  static Future<void> _createAndroidChannels() async {
    try {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      for (final channel in NotificationChannels.androidChannels) {
        await android.createNotificationChannel(channel);
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to create notification channels', e, stackTrace);
    }
  }

  static Future<void> showBackupCompleted() async {
    try {
      await _show(
        id: NotificationIds.backupCompleted,
        title: 'FalconLog Backup',
        body: 'Your latest backup was saved successfully.',
        channelId: NotificationChannels.backupStatusId,
        channelName: NotificationChannels.backupStatusName,
        channelDescription: NotificationChannels.backupStatusDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        payload: NotificationPayload.backupSettings,
      );
    } catch (e, stackTrace) {
      _logger.warning('showBackupCompleted failed', e, stackTrace);
    }
  }

  static Future<void> showBackupFailed(String reason) async {
    try {
      final detail =
          reason.trim().isEmpty ? 'Tap to review backup settings.' : reason;
      await _show(
        id: NotificationIds.backupFailed,
        title: 'Backup failed',
        body: detail,
        channelId: NotificationChannels.backupFailureId,
        channelName: NotificationChannels.backupFailureName,
        channelDescription: NotificationChannels.backupFailureDescription,
        importance: Importance.high,
        priority: Priority.high,
        payload: NotificationPayload.backupSettings,
      );
    } catch (e, stackTrace) {
      _logger.warning('showBackupFailed failed', e, stackTrace);
    }
  }

  static Future<void> showCombinedCurrencyDailyReminder({
    required String title,
    required String body,
  }) async {
    try {
      await _show(
        id: NotificationIds.currencyDailyCombined,
        title: title,
        body: body,
        channelId: NotificationChannels.currencyExpiryId,
        channelName: NotificationChannels.currencyExpiryName,
        channelDescription: NotificationChannels.currencyExpiryDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        payload: NotificationPayload.currencyAlertSettings,
      );
    } catch (e, stackTrace) {
      _logger.warning('showCombinedCurrencyDailyReminder failed', e, stackTrace);
    }
  }

  static Future<void> cancelLegacyCurrencyReminders() async {
    await cancelAllCurrencyReminders();
  }

  static Future<void> cancelAllCurrencyReminders() async {
    try {
      await _notifications.cancel(NotificationIds.currencyDailyCombined);
      await _notifications.cancel(NotificationIds.currencyDayReminder);
      await _notifications.cancel(NotificationIds.currencyNightReminder);
    } catch (e, stackTrace) {
      _logger.warning('cancelAllCurrencyReminders failed', e, stackTrace);
    }
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required Importance importance,
    required Priority priority,
    String? payload,
    int? progress,
    int? maxProgress,
    bool indeterminate = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      icon: '@drawable/ic_notification',
      color: _notificationColor,
      showProgress: progress != null,
      progress: progress ?? 0,
      maxProgress: maxProgress ?? 0,
      indeterminate: indeterminate,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}

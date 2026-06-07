import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/services/hive_initialization_service.dart';
import '../../models/flight_log.dart';
import '../../settings/currency_alert_settings.dart';
import '../../settings/currency_alert_settings_repository.dart';
import '../domain/currency_daily_notification.dart';
import '../domain/currency_reminder_last_shown_store.dart';
import '../domain/notification_channels.dart';
import '../domain/notification_preferences.dart';
import '../services/local_notification_service.dart';
import '../services/notification_permission_service.dart';
import 'currency_daily_scheduler.dart';

/// Schedules and shows daily combined currency expiry countdown notifications.
class CurrencyExpiryScheduler {
  CurrencyExpiryScheduler._();

  static final _logger = Logger('CurrencyExpiryScheduler');

  @visibleForTesting
  static Future<NotificationPreferences> Function()? loadPreferencesOverride;

  @visibleForTesting
  static Future<CurrencyAlertSettings> Function()? loadCurrencySettingsOverride;

  @visibleForTesting
  static Future<List<FlightLog>> Function()? loadFlightLogsOverride;

  /// Re-register work and optionally show today's countdown after app resume.
  static Future<void> rescheduleOnAppResume() async {
    final allowShowNow = isPastDailyNotificationHour(DateTime.now());
    await rescheduleFromHive(allowShowNow: allowShowNow);
  }

  static Future<void> rescheduleFromHive({bool allowShowNow = true}) async {
    try {
      await LocalNotificationService.initialize(isBackground: false);
      final prefs = await _loadPreferences();

      if (!prefs.shouldShowCurrencyNotifications) {
        await _disableCurrencyNotifications();
        return;
      }

      if (!await NotificationPermissionService.areNotificationsEnabled()) {
        await CurrencyDailyScheduler.cancelDailyTask();
        return;
      }

      await CurrencyDailyScheduler.registerDailyTask();
      await runDailyCurrencyNotificationFromHive(allowShowNow: allowShowNow);
    } catch (e, stackTrace) {
      _logger.warning('rescheduleFromHive failed', e, stackTrace);
    }
  }

  static Future<void> runDailyCurrencyNotificationFromHive({
    bool allowShowNow = true,
  }) async {
    try {
      final prefs = await _loadPreferences();
      if (!prefs.shouldShowCurrencyNotifications) {
        await _disableCurrencyNotifications();
        return;
      }

      if (!await NotificationPermissionService.areNotificationsEnabled()) {
        return;
      }

      final currencySettings = await _loadCurrencySettings();
      final logs = await _loadFlightLogs();
      await runDailyCurrencyNotification(
        logs: logs,
        dayAlertDays: currencySettings.dayAlertDays,
        nightAlertDays: currencySettings.nightAlertDays,
        allowShowNow: allowShowNow,
      );
    } catch (e, stackTrace) {
      _logger.warning('runDailyCurrencyNotificationFromHive failed', e, stackTrace);
    }
  }

  @visibleForTesting
  static Future<void> runDailyCurrencyNotification({
    required List<FlightLog> logs,
    required int dayAlertDays,
    required int nightAlertDays,
    bool allowShowNow = true,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();

    await LocalNotificationService.cancelLegacyCurrencyReminders();

    final content = buildCombinedCurrencyDailyNotification(
      logs: logs,
      dayAlertDays: dayAlertDays,
      nightAlertDays: nightAlertDays,
      now: effectiveNow,
    );

    if (content == null || !allowShowNow) {
      return;
    }

    final alreadyShown = await CurrencyReminderLastShownStore.wasShownToday(
      notificationId: NotificationIds.currencyDailyCombined,
      now: effectiveNow,
    );
    if (alreadyShown) return;

    await LocalNotificationService.showCombinedCurrencyDailyReminder(
      title: content.title,
      body: content.body,
    );
    await CurrencyReminderLastShownStore.recordShown(
      notificationId: NotificationIds.currencyDailyCombined,
      now: effectiveNow,
    );
  }

  static Future<void> _disableCurrencyNotifications() async {
    await CurrencyDailyScheduler.cancelDailyTask();
    await LocalNotificationService.cancelAllCurrencyReminders();
  }

  static Future<NotificationPreferences> _loadPreferences() async {
    final override = loadPreferencesOverride;
    if (override != null) return override();
    return NotificationPreferencesRepository().load();
  }

  static Future<CurrencyAlertSettings> _loadCurrencySettings() async {
    final override = loadCurrencySettingsOverride;
    if (override != null) return override();
    return CurrencyAlertSettingsRepository().load();
  }

  static Future<List<FlightLog>> _loadFlightLogs() async {
    final override = loadFlightLogsOverride;
    if (override != null) return override();
    final box =
        await HiveInitializationService.openBox<FlightLog>('flightLogsBox');
    return box.values.toList();
  }
}

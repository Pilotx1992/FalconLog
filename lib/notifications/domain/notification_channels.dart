import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android notification channel identifiers for FalconLog local notifications.
class NotificationChannels {
  NotificationChannels._();

  static const String backupStatusId = 'backup_status_channel';
  static const String backupStatusName = 'Backup status';
  static const String backupStatusDescription =
      'Auto backup result notifications';

  static const String backupFailureId = 'backup_failure_channel';
  static const String backupFailureName = 'Backup failures';
  static const String backupFailureDescription =
      'Important backup failure alerts';

  static const String currencyExpiryId = 'currency_expiry_channel';
  static const String currencyExpiryName = 'Currency reminders';
  static const String currencyExpiryDescription =
      'Currency validity expiry reminders';

  static const List<AndroidNotificationChannel> androidChannels = [
    AndroidNotificationChannel(
      backupStatusId,
      backupStatusName,
      description: backupStatusDescription,
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      backupFailureId,
      backupFailureName,
      description: backupFailureDescription,
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      currencyExpiryId,
      currencyExpiryName,
      description: currencyExpiryDescription,
      importance: Importance.defaultImportance,
    ),
  ];
}

/// Deterministic notification IDs.
class NotificationIds {
  NotificationIds._();

  static const int backupCompleted = 1002;
  static const int backupFailed = 1003;
  /// Combined daily day + night currency countdown notification.
  static const int currencyDailyCombined = 2000;

  /// Legacy per-kind IDs (cancelled on reschedule).
  static const int currencyDayReminder = 2001;
  static const int currencyNightReminder = 2002;
}

enum CurrencyKind {
  day,
  night,
}

int notificationIdForCurrency(CurrencyKind kind) {
  switch (kind) {
    case CurrencyKind.day:
      return NotificationIds.currencyDayReminder;
    case CurrencyKind.night:
      return NotificationIds.currencyNightReminder;
  }
}

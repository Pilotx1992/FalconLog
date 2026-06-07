/// Notification tap payload strings and pending-route persistence keys.
class NotificationPayload {
  NotificationPayload._();

  static const String backupSettings = 'backup_settings';
  static const String currencyAlertSettings = 'currency_alert_settings';

  /// SharedPreferences key for payload deferred until app startup.
  static const String pendingPayloadKey =
      'falconlog_pending_notification_payload';

  /// Attempt counter for cold-start navigation retries.
  static const String pendingAttemptCountKey =
      'falconlog_pending_notification_attempt_count';

  static const int maxPendingNavigationAttempts = 3;
}

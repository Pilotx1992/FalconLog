import 'package:shared_preferences/shared_preferences.dart';

/// User-facing notification settings (backed up via [AppSettingsBackup] keys).
class NotificationPreferences {
  final bool enableNotifications;
  final bool backupNotificationsEnabled;
  final bool currencyExpiryNotificationsEnabled;
  /// Deprecated: kept for backup/restore only. Scheduling uses dynamic countdown.
  @Deprecated('Use daily currency countdown from flight logs; not user-configurable.')
  final int currencyReminderDays;

  const NotificationPreferences({
    required this.enableNotifications,
    required this.backupNotificationsEnabled,
    required this.currencyExpiryNotificationsEnabled,
    required this.currencyReminderDays,
  });

  static const NotificationPreferences defaults = NotificationPreferences(
    enableNotifications: false,
    backupNotificationsEnabled: true,
    currencyExpiryNotificationsEnabled: true,
    currencyReminderDays: 5,
  );

  static const String prefKeyEnableNotifications =
      'falconlog_notifications_enabled';
  static const String prefKeyBackupNotifications =
      'falconlog_backup_notifications_enabled';
  static const String prefKeyCurrencyExpiryNotifications =
      'falconlog_currency_expiry_notifications_enabled';
  static const String prefKeyCurrencyReminderDays =
      'falconlog_currency_reminder_days';

  static const List<String> backupablePreferenceKeys = [
    prefKeyEnableNotifications,
    prefKeyBackupNotifications,
    prefKeyCurrencyExpiryNotifications,
    prefKeyCurrencyReminderDays,
  ];

  bool get shouldShowBackupNotifications =>
      enableNotifications && backupNotificationsEnabled;

  bool get shouldShowCurrencyNotifications =>
      enableNotifications && currencyExpiryNotificationsEnabled;

  NotificationPreferences copyWith({
    bool? enableNotifications,
    bool? backupNotificationsEnabled,
    bool? currencyExpiryNotificationsEnabled,
    int? currencyReminderDays,
  }) {
    return NotificationPreferences(
      enableNotifications: enableNotifications ?? this.enableNotifications,
      backupNotificationsEnabled:
          backupNotificationsEnabled ?? this.backupNotificationsEnabled,
      currencyExpiryNotificationsEnabled: currencyExpiryNotificationsEnabled ??
          this.currencyExpiryNotificationsEnabled,
      currencyReminderDays: currencyReminderDays ?? this.currencyReminderDays,
    );
  }
}

class NotificationPreferencesRepository {
  Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      enableNotifications:
          prefs.getBool(NotificationPreferences.prefKeyEnableNotifications) ??
              NotificationPreferences.defaults.enableNotifications,
      backupNotificationsEnabled: prefs.getBool(
            NotificationPreferences.prefKeyBackupNotifications,
          ) ??
          NotificationPreferences.defaults.backupNotificationsEnabled,
      currencyExpiryNotificationsEnabled: prefs.getBool(
            NotificationPreferences.prefKeyCurrencyExpiryNotifications,
          ) ??
          NotificationPreferences.defaults.currencyExpiryNotificationsEnabled,
      currencyReminderDays: prefs.getInt(
            NotificationPreferences.prefKeyCurrencyReminderDays,
          ) ??
          NotificationPreferences.defaults.currencyReminderDays,
    );
  }

  Future<void> save(NotificationPreferences settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      NotificationPreferences.prefKeyEnableNotifications,
      settings.enableNotifications,
    );
    await prefs.setBool(
      NotificationPreferences.prefKeyBackupNotifications,
      settings.backupNotificationsEnabled,
    );
    await prefs.setBool(
      NotificationPreferences.prefKeyCurrencyExpiryNotifications,
      settings.currencyExpiryNotificationsEnabled,
    );
    await prefs.setInt(
      NotificationPreferences.prefKeyCurrencyReminderDays,
      settings.currencyReminderDays,
    );
  }
}

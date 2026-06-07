import 'package:falconlog/notifications/domain/notification_preferences.dart';
import 'package:falconlog/notifications/schedulers/backup_notification_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    BackupNotificationDispatcher.loadPreferencesOverride = null;
    BackupNotificationDispatcher.areNotificationsEnabledOverride = null;
    BackupNotificationDispatcher.showCompletedOverride = null;
    BackupNotificationDispatcher.showFailedOverride = null;
  });

  test('onBackupSuccess shows when enabled', () async {
    var completed = false;
    BackupNotificationDispatcher.loadPreferencesOverride =
        () async => const NotificationPreferences(
              enableNotifications: true,
              backupNotificationsEnabled: true,
              currencyExpiryNotificationsEnabled: true,
              currencyReminderDays: 7,
            );
    BackupNotificationDispatcher.areNotificationsEnabledOverride =
        () async => true;
    BackupNotificationDispatcher.showCompletedOverride = () async {
      completed = true;
    };

    await BackupNotificationDispatcher.onBackupSuccess();
    expect(completed, isTrue);
  });

  test('onBackupSuccess silent when backup notifications disabled', () async {
    var completed = false;
    BackupNotificationDispatcher.loadPreferencesOverride =
        () async => const NotificationPreferences(
              enableNotifications: true,
              backupNotificationsEnabled: false,
              currencyExpiryNotificationsEnabled: true,
              currencyReminderDays: 7,
            );
    BackupNotificationDispatcher.showCompletedOverride = () async {
      completed = true;
    };

    await BackupNotificationDispatcher.onBackupSuccess();
    expect(completed, isFalse);
  });

  test('onBackupFailure shows when enabled', () async {
    var failed = false;
    BackupNotificationDispatcher.loadPreferencesOverride = () async =>
        NotificationPreferences.defaults.copyWith(enableNotifications: true);
    BackupNotificationDispatcher.areNotificationsEnabledOverride =
        () async => true;
    BackupNotificationDispatcher.showFailedOverride = (_) async {
      failed = true;
    };

    await BackupNotificationDispatcher.onBackupFailure();
    expect(failed, isTrue);
  });

  test('dispatcher does not throw when show fails', () async {
    BackupNotificationDispatcher.loadPreferencesOverride = () async =>
        NotificationPreferences.defaults.copyWith(enableNotifications: true);
    BackupNotificationDispatcher.areNotificationsEnabledOverride =
        () async => true;
    BackupNotificationDispatcher.showCompletedOverride = () async {
      throw Exception('platform error');
    };

    await BackupNotificationDispatcher.onBackupSuccess();
  });
}

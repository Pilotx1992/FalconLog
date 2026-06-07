import 'package:falconlog/notifications/domain/notification_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationPreferencesRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = NotificationPreferencesRepository();
  });

  test('load returns defaults when prefs missing', () async {
    final prefs = await repository.load();
    expect(prefs.enableNotifications, false);
    expect(prefs.backupNotificationsEnabled, true);
    expect(prefs.currencyExpiryNotificationsEnabled, true);
    expect(prefs.currencyReminderDays, 5);
  });

  test('save and load round-trip', () async {
    const settings = NotificationPreferences(
      enableNotifications: true,
      backupNotificationsEnabled: false,
      currencyExpiryNotificationsEnabled: true,
      currencyReminderDays: 3,
    );
    await repository.save(settings);
    final loaded = await repository.load();
    expect(loaded.enableNotifications, true);
    expect(loaded.backupNotificationsEnabled, false);
    expect(loaded.currencyReminderDays, 3);
  });
}

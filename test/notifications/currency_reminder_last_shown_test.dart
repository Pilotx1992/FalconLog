import 'package:falconlog/notifications/domain/currency_reminder_last_shown_store.dart';
import 'package:falconlog/notifications/domain/notification_channels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('wasShownToday false before record', () async {
    final shown = await CurrencyReminderLastShownStore.wasShownToday(
      notificationId: NotificationIds.currencyDayReminder,
      daysLeft: 3,
      now: DateTime(2025, 6, 10),
    );
    expect(shown, isFalse);
  });

  test('wasShownToday true after record same day', () async {
    final now = DateTime(2025, 6, 10, 15);
    await CurrencyReminderLastShownStore.recordShown(
      notificationId: NotificationIds.currencyDayReminder,
      daysLeft: 3,
      now: now,
    );
    final shown = await CurrencyReminderLastShownStore.wasShownToday(
      notificationId: NotificationIds.currencyDayReminder,
      daysLeft: 3,
      now: now,
    );
    expect(shown, isTrue);
  });
}

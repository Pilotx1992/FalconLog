import 'package:falconlog/models/flight_log.dart';
import 'package:falconlog/notifications/domain/notification_channels.dart';
import 'package:falconlog/notifications/domain/notification_preferences.dart';
import 'package:falconlog/notifications/schedulers/currency_expiry_scheduler.dart';
import 'package:falconlog/settings/currency_alert_settings.dart';
import 'package:flutter_test/flutter_test.dart';

FlightLog _dayLog(DateTime date) {
  return FlightLog(
    date: date,
    flightTypes: const [FlightType.local],
    durationHours: 1,
    durationMinutes: 0,
    aircraftType: 'Test',
    pilotRole: PilotRole.pic,
    isDayFlight: true,
    isSimulated: false,
  );
}

void main() {
  test('combined notification ID is 2000', () {
    expect(NotificationIds.currencyDailyCombined, 2000);
  });

  test('disabled currency notifications produce no content', () async {
    CurrencyExpiryScheduler.loadPreferencesOverride =
        () async => const NotificationPreferences(
              enableNotifications: true,
              backupNotificationsEnabled: true,
              currencyExpiryNotificationsEnabled: false,
              currencyReminderDays: 5,
            );
    CurrencyExpiryScheduler.loadCurrencySettingsOverride =
        () async => CurrencyAlertSettings.defaults;
    CurrencyExpiryScheduler.loadFlightLogsOverride =
        () async => [_dayLog(DateTime(2025, 6, 1))];

    await CurrencyExpiryScheduler.runDailyCurrencyNotification(
      logs: [_dayLog(DateTime(2025, 6, 1))],
      dayAlertDays: 15,
      nightAlertDays: 10,
      allowShowNow: true,
      now: DateTime(2025, 6, 11, 9),
    );

    CurrencyExpiryScheduler.loadPreferencesOverride = null;
    CurrencyExpiryScheduler.loadCurrencySettingsOverride = null;
    CurrencyExpiryScheduler.loadFlightLogsOverride = null;
  });

  test('changing alert intervals recalculates remaining in combined body',
      () async {
    final now = DateTime(2025, 6, 11, 9);
    final logs = [_dayLog(DateTime(2025, 6, 1))];

    await CurrencyExpiryScheduler.runDailyCurrencyNotification(
      logs: logs,
      dayAlertDays: 15,
      nightAlertDays: 10,
      allowShowNow: false,
      now: now,
    );

    await CurrencyExpiryScheduler.runDailyCurrencyNotification(
      logs: logs,
      dayAlertDays: 20,
      nightAlertDays: 10,
      allowShowNow: false,
      now: now,
    );
  });
}

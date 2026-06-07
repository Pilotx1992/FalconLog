import 'package:falconlog/models/flight_log.dart';
import 'package:falconlog/notifications/domain/currency_daily_notification.dart';
import 'package:flutter_test/flutter_test.dart';

FlightLog _log({
  required DateTime date,
  required bool isDay,
  DateTime? createdAt,
}) {
  return FlightLog(
    date: date,
    flightTypes: const [FlightType.local],
    durationHours: 1,
    durationMinutes: 0,
    aircraftType: 'Test',
    pilotRole: PilotRole.pic,
    isDayFlight: isDay,
    isSimulated: false,
    createdAt: createdAt ?? DateTime(2099, 1, 1),
  );
}

void main() {
  group('computeRemainingCalendarDays', () {
    test('day: last flight + dayAlertDays', () {
      final remaining = computeRemainingCalendarDays(
        lastFlightDate: DateTime(2025, 6, 1),
        alertIntervalDays: 15,
        now: DateTime(2025, 6, 10),
      );
      expect(remaining, 6);
    });

    test('night: last flight + nightAlertDays', () {
      final remaining = computeRemainingCalendarDays(
        lastFlightDate: DateTime(2025, 6, 1),
        alertIntervalDays: 10,
        now: DateTime(2025, 6, 11),
      );
      expect(remaining, 0);
    });

    test('uses flight date not createdAt', () {
      final logs = [
        _log(
          date: DateTime(2025, 6, 1),
          isDay: true,
          createdAt: DateTime(2025, 1, 1),
        ),
      ];
      final last = findLastFlightDate(logs, isDay: true);
      expect(last, DateTime(2025, 6, 1));

      final remaining = computeRemainingCalendarDays(
        lastFlightDate: last!,
        alertIntervalDays: 15,
        now: DateTime(2025, 6, 10),
      );
      expect(remaining, 6);
    });
  });

  group('shouldNotifyAfterLastFlight', () {
    test('no notification on flight day', () {
      expect(
        shouldNotifyAfterLastFlight(
          lastFlightDate: DateTime(2025, 6, 10),
          now: DateTime(2025, 6, 10, 15),
        ),
        isFalse,
      );
    });

    test('notification starts day after last flight', () {
      expect(
        shouldNotifyAfterLastFlight(
          lastFlightDate: DateTime(2025, 6, 10),
          now: DateTime(2025, 6, 11, 9),
        ),
        isTrue,
      );
    });
  });

  group('formatCurrencyKindStatusLine', () {
    test('remaining > 0', () {
      expect(formatCurrencyKindStatusLine(3), '3 days remaining');
    });

    test('remaining == 0', () {
      expect(formatCurrencyKindStatusLine(0), 'expires today');
    });

    test('remaining < 0', () {
      expect(formatCurrencyKindStatusLine(-2), 'expired 2 days ago');
    });
  });

  group('buildCombinedCurrencyDailyNotification', () {
    final now = DateTime(2025, 6, 11, 9);

    test('combined day and night lines', () {
      final content = buildCombinedCurrencyDailyNotification(
        logs: [
          _log(date: DateTime(2025, 6, 1), isDay: true),
          _log(date: DateTime(2025, 6, 1), isDay: false),
        ],
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );

      expect(content, isNotNull);
      expect(content!.lines.length, 2);
      expect(content.lines[0], 'Day currency: 5 days remaining');
      expect(content.lines[1], 'Night currency: expires today');
    });

    test('null when only on flight day', () {
      final content = buildCombinedCurrencyDailyNotification(
        logs: [_log(date: DateTime(2025, 6, 11), isDay: true)],
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(content, isNull);
    });

    test('day only when no night flights', () {
      final content = buildCombinedCurrencyDailyNotification(
        logs: [_log(date: DateTime(2025, 6, 1), isDay: true)],
        dayAlertDays: 30,
        nightAlertDays: 10,
        now: DateTime(2025, 6, 2, 9),
      );
      expect(content?.lines.length, 1);
      expect(content!.lines.first, contains('Day currency'));
    });
  });

  group('QA matrix — remaining copy', () {
    test('last day flight yesterday alert 30 → 29 days remaining', () {
      final content = buildCombinedCurrencyDailyNotification(
        logs: [_log(date: DateTime(2025, 6, 10), isDay: true)],
        dayAlertDays: 30,
        nightAlertDays: 10,
        now: DateTime(2025, 6, 11, 9),
      );
      expect(content?.lines.first, 'Day currency: 29 days remaining');
    });

    test('last day flight 30 days ago alert 30 → expires today', () {
      final content = buildCombinedCurrencyDailyNotification(
        logs: [_log(date: DateTime(2025, 5, 12), isDay: true)],
        dayAlertDays: 30,
        nightAlertDays: 10,
        now: DateTime(2025, 6, 11, 9),
      );
      expect(content?.lines.first, 'Day currency: expires today');
    });

    test('last day flight 31 days ago alert 30 → expired 1 day ago', () {
      final content = buildCombinedCurrencyDailyNotification(
        logs: [_log(date: DateTime(2025, 5, 11), isDay: true)],
        dayAlertDays: 30,
        nightAlertDays: 10,
        now: DateTime(2025, 6, 11, 9),
      );
      expect(content?.lines.first, 'Day currency: expired 1 day ago');
    });
  });

  group('isPastDailyNotificationHour', () {
    test('before 9:00 is false', () {
      expect(isPastDailyNotificationHour(DateTime(2025, 6, 11, 8, 59)), isFalse);
    });

    test('at 9:00 is true', () {
      expect(isPastDailyNotificationHour(DateTime(2025, 6, 11, 9)), isTrue);
    });
  });
}

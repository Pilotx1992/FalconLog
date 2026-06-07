import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/models/flight_log.dart';
import 'package:falconlog/providers/currency_status_provider.dart';

FlightLog _flight({
  required DateTime date,
  required bool isDay,
  double hours = 1,
}) {
  final whole = hours.floor();
  final minutes = ((hours - whole) * 60).round();
  return FlightLog(
    date: date,
    flightTypes: const [FlightType.local],
    durationHours: whole,
    durationMinutes: minutes,
    aircraftType: 'AH-64',
    pilotRole: PilotRole.pic,
    isDayFlight: isDay,
    isSimulated: false,
  );
}

void main() {
  final now = DateTime(2026, 5, 20, 12);

  group('computeCurrencyStatus', () {
    test('dayAlert 15 and last day flight 14 days ago: dayDue false', () {
      final logs = [
        _flight(
          date: now.subtract(const Duration(days: 14)),
          isDay: true,
        ),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.dayDue, false);
      expect(status.day.outOfCurrency, false);
      expect(status.day.daysRemaining, 1);
      expect(status.dayMessage, '');
    });

    test('dayAlert 15 and last day flight 15 days ago: expires today', () {
      final lastDate = now.subtract(const Duration(days: 15));
      final logs = [
        _flight(date: lastDate, isDay: true),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.dayDue, false);
      expect(status.day.outOfCurrency, false);
      expect(status.day.daysRemaining, 0);
      expect(status.day.lastFlightDate, lastDate);
      expect(status.dayMessage, '');
      expect(status.hasFlights, true);
    });

    test('dayAlert 15 and last day flight 16 days ago: dayDue true', () {
      final lastDate = now.subtract(const Duration(days: 16));
      final logs = [
        _flight(date: lastDate, isDay: true),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.dayDue, true);
      expect(status.day.outOfCurrency, true);
      expect(status.day.daysRemaining, -1);
      expect(status.day.lastFlightDate, lastDate);
      expect(status.dayMessage, 'Last flight: 16 days ago');
    });

    test('last day flight 10 days ago with interval 15: 5 days remaining', () {
      final lastDate = now.subtract(const Duration(days: 10));
      final logs = [
        _flight(date: lastDate, isDay: true),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.day.daysRemaining, 5);
      expect(status.day.outOfCurrency, false);
    });

    test('nightAlert 10 and last night flight 9 days ago: nightDue false', () {
      final logs = [
        _flight(
          date: now.subtract(const Duration(days: 9)),
          isDay: false,
        ),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.nightDue, false);
      expect(status.night.daysRemaining, 1);
      expect(status.nightMessage, '');
    });

    test('nightAlert 10 and last night flight 10 days ago: expires today', () {
      final logs = [
        _flight(
          date: now.subtract(const Duration(days: 10)),
          isDay: false,
        ),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.nightDue, false);
      expect(status.night.outOfCurrency, false);
      expect(status.night.daysRemaining, 0);
      expect(status.nightMessage, '');
    });

    test('nightAlert 10 and last night flight 11 days ago: nightDue true', () {
      final logs = [
        _flight(
          date: now.subtract(const Duration(days: 11)),
          isDay: false,
        ),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.nightDue, true);
      expect(status.night.outOfCurrency, true);
      expect(status.night.daysRemaining, -1);
      expect(status.nightMessage, 'Last flight: 11 days ago');
    });

    test('uses exact manual intervals 21 and 15', () {
      final logs = [
        _flight(
          date: now.subtract(const Duration(days: 20)),
          isDay: true,
        ),
        _flight(
          date: now.subtract(const Duration(days: 14)),
          isDay: false,
        ),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 21,
        nightAlertDays: 15,
        now: now,
      );
      expect(status.dayDue, false);
      expect(status.nightDue, false);
      expect(status.day.daysRemaining, 1);
      expect(status.night.daysRemaining, 1);
    });

    test('high total hours in logs does not change interval (night 15)', () {
      final logs = [
        _flight(
          date: now.subtract(const Duration(days: 20)),
          isDay: true,
          hours: 500,
        ),
        _flight(
          date: now.subtract(const Duration(days: 16)),
          isDay: false,
          hours: 50,
        ),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 30,
        nightAlertDays: 15,
        now: now,
      );
      expect(status.nightDue, true);
      expect(status.night.outOfCurrency, true);
      expect(status.night.daysRemaining, -1);
      expect(status.nightMessage, 'Last flight: 16 days ago');
    });

    test('formatLastFlightDaysAgo uses singular day', () {
      expect(formatLastFlightDaysAgo(1), 'Last flight: 1 day ago');
    });

    test('no day flights when due shows Last flight: none', () {
      final logs = [
        _flight(
          date: now.subtract(const Duration(days: 5)),
          isDay: false,
        ),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.dayDue, true);
      expect(status.day.lastFlightDate, isNull);
      expect(status.day.daysRemaining, isNull);
      expect(status.day.outOfCurrency, true);
      expect(status.dayMessage, 'Last flight: none');
    });

    test('empty logs: no alert', () {
      final status = computeCurrencyStatus(
        logs: [],
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.hasAlert, false);
      expect(status.hasFlights, false);
      expect(status.day.outOfCurrency, false);
      expect(status.night.outOfCurrency, false);
    });
  });
}

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
    });

    test('dayAlert 15 and last day flight 15 days ago: dayDue true', () {
      final logs = [
        _flight(
          date: now.subtract(const Duration(days: 15)),
          isDay: true,
        ),
      ];
      final status = computeCurrencyStatus(
        logs: logs,
        dayAlertDays: 15,
        nightAlertDays: 10,
        now: now,
      );
      expect(status.dayDue, true);
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
    });

    test('nightAlert 10 and last night flight 10 days ago: nightDue true', () {
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
      expect(status.nightDue, true);
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
      expect(status.dayMessage, contains('21'));
      expect(status.nightMessage, contains('15'));
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
      expect(status.nightMessage, contains('15'));
      expect(status.nightMessage, isNot(contains('10')));
    });
  });
}

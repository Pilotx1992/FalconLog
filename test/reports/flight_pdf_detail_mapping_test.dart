import 'package:falconlog/models/flight_log.dart';
import 'package:falconlog/reports/domain/flight_log_duration.dart';
import 'package:falconlog/reports/domain/flight_log_labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'fixtures/report_test_fixtures.dart';

void main() {
  final dateFmt = DateFormat('dd MMM yyyy');

  group('detail row mapping', () {
    test('uses FlightLog.date not createdAt', () {
      final log = buildTestLog(
        date: DateTime(2026, 3, 10),
        createdAt: DateTime(2099, 1, 1),
      );
      expect(dateFmt.format(log.date), '10 Mar 2026');
    });

    test('formats duration as HH:MM', () {
      final log = buildTestLog(
        date: DateTime(2026, 1, 1),
        durationHours: 2,
        durationMinutes: 30,
      );
      expect(formatDurationHhMm(durationInHours(log)), '02:30');
    });

    test('flight condition is Day or Night', () {
      expect(flightConditionLabel(true), 'Day');
      expect(flightConditionLabel(false), 'Night');
    });

    test('flight mode is Actual or Simulator', () {
      expect(flightModeLabel(false), 'Actual');
      expect(flightModeLabel(true), 'Simulator');
    });

    test('multiple flight types joined with comma', () {
      final log = buildTestLog(
        date: DateTime(2026, 1, 1),
        flightTypes: [FlightType.local, FlightType.mission],
      );
      expect(flightTypesLabel(log.flightTypes), 'Local, Mission');
    });
  });
}

import 'package:falconlog/models/flight_log.dart';
import 'package:falconlog/reports/domain/report_date_range.dart';
import 'package:falconlog/reports/services/flight_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/report_test_fixtures.dart';

void main() {
  const service = FlightReportService();

  group('filterByDateRange', () {
    test('uses FlightLog.date only and includes boundaries', () {
      final logs = [
        buildTestLog(
          id: 'a',
          date: DateTime(2026, 1, 10),
          createdAt: DateTime(2099, 1, 1),
        ),
        buildTestLog(
          id: 'b',
          date: DateTime(2026, 1, 20),
          createdAt: DateTime(2000, 1, 1),
        ),
        buildTestLog(id: 'c', date: DateTime(2026, 2, 1)),
      ];
      final range = ReportDateRange.custom(
        start: DateTime(2026, 1, 10),
        end: DateTime(2026, 1, 20),
      );
      final filtered = service.filterByDateRange(logs, range);
      expect(filtered.map((l) => l.id).toList(), ['a', 'b']);
    });

    test('sorts by date ascending', () {
      final logs = [
        buildTestLog(id: 'b', date: DateTime(2026, 1, 15)),
        buildTestLog(id: 'a', date: DateTime(2026, 1, 5)),
      ];
      final range = ReportDateRange.thisMonth(anchor: DateTime(2026, 1, 10));
      final filtered = service.filterByDateRange(logs, range);
      expect(filtered.first.id, 'a');
    });
  });

  group('buildSummary', () {
    test('totals hours and day/night from isDayFlight', () {
      final logs = [
        buildTestLog(
          date: DateTime(2026, 1, 1),
          durationHours: 2,
          durationMinutes: 30,
          isDayFlight: true,
        ),
        buildTestLog(
          date: DateTime(2026, 1, 2),
          durationHours: 1,
          durationMinutes: 0,
          isDayFlight: false,
        ),
      ];
      final range = ReportDateRange.thisYear(anchor: DateTime(2026, 6, 1));
      final summary = service.buildSummary(logs, range);
      expect(summary.totalFlights, 2);
      expect(summary.totalHours, closeTo(3.5, 0.001));
      expect(summary.dayHours, closeTo(2.5, 0.001));
      expect(summary.nightHours, closeTo(1.0, 0.001));
    });

    test('empty range returns safe empty summary', () {
      final range = ReportDateRange.thisYear(anchor: DateTime(2026, 1, 1));
      final summary = service.buildSummary([], range);
      expect(summary.isEmpty, isTrue);
      expect(summary.totalFlights, 0);
    });

    test('all-time summary matches dashboard-style totals', () {
      final logs = [
        buildTestLog(
          date: DateTime(2024, 1, 1),
          durationHours: 1,
          durationMinutes: 30,
          isDayFlight: true,
        ),
        buildTestLog(
          date: DateTime(2025, 6, 1),
          durationHours: 2,
          isDayFlight: false,
        ),
      ];
      var totalHours = 0.0;
      var dayHours = 0.0;
      var nightHours = 0.0;
      for (final log in logs) {
        final h = log.durationHours + log.durationMinutes / 60.0;
        totalHours += h;
        if (log.isDayFlight) {
          dayHours += h;
        } else {
          nightHours += h;
        }
      }
      final summary = service.buildSummary(
        logs,
        ReportDateRange.allTime(),
      );
      expect(summary.totalFlights, logs.length);
      expect(summary.totalHours, closeTo(totalHours, 0.001));
      expect(summary.dayHours, closeTo(dayHours, 0.001));
      expect(summary.nightHours, closeTo(nightHours, 0.001));
    });
  });

  group('breakdowns', () {
    final logs = [
      buildTestLog(
        date: DateTime(2026, 3, 1),
        flightTypes: [FlightType.local, FlightType.mission],
        durationHours: 2,
        pilotRole: PilotRole.pic,
        isDayFlight: true,
      ),
      buildTestLog(
        date: DateTime(2026, 3, 2),
        flightTypes: [FlightType.mission],
        durationHours: 1,
        pilotRole: PilotRole.ip,
        isSimulated: true,
        isDayFlight: false,
      ),
    ];

    test('flight type breakdown splits hours across tags', () {
      final b = service.buildFlightTypeBreakdown(logs);
      expect(b.rows, isNotEmpty);
      final local = b.rows.firstWhere((r) => r.label == 'Local');
      expect(local.hours, closeTo(1.0, 0.001));
    });

    test('pilot role breakdown', () {
      final b = service.buildPilotRoleBreakdown(logs);
      expect(b.rows.length, 2);
    });

    test('flight condition Day/Night only', () {
      final b = service.buildFlightConditionBreakdown(logs);
      expect(b.rows.map((r) => r.label).toSet(), {'Day', 'Night'});
    });

    test('flight mode Actual/Simulator hours', () {
      final b = service.buildFlightModeBreakdown(logs);
      final actual = b.rows.firstWhere((r) => r.label == 'Actual');
      final sim = b.rows.firstWhere((r) => r.label == 'Simulator');
      expect(actual.hours, closeTo(2.0, 0.001));
      expect(sim.hours, closeTo(1.0, 0.001));
      expect(actual.flights, 1);
      expect(sim.flights, 1);
    });

    test('aircraft breakdown by type', () {
      final b = service.buildAircraftBreakdown(logs);
      expect(b.byAircraftType, isNotEmpty);
    });
  });
}

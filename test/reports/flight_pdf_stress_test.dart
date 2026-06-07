import 'package:falconlog/reports/domain/report_date_range.dart';
import 'package:falconlog/reports/services/flight_report_export_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/report_test_fixtures.dart';

void main() {
  final coordinator = FlightReportExportCoordinator();

  test('500 flight logs PDF generation completes', () async {
    final logs = buildLogs(500, startDate: DateTime(2025, 1, 1));
    final range = ReportDateRange.thisYear(anchor: DateTime(2025, 6, 1));
    final bytes = await coordinator.buildPdfBytes(allLogs: logs, range: range);
    expect(bytes.isNotEmpty, isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('1000 flight logs PDF generation completes', () async {
    final logs = buildLogs(1000, startDate: DateTime(2024, 1, 1));
    final range = ReportDateRange.thisYear(anchor: DateTime(2024, 6, 1));
    final bytes = await coordinator.buildPdfBytes(allLogs: logs, range: range);
    expect(bytes.isNotEmpty, isTrue);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('many registrations and flight types', () async {
    final logs = buildLogs(200, startDate: DateTime(2026, 1, 1));
    final range = ReportDateRange.custom(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 12, 31),
    );
    await expectLater(
      coordinator.buildPdfBytes(allLogs: logs, range: range),
      completes,
    );
  });
}

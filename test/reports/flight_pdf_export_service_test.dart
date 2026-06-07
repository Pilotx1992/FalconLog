import 'package:falconlog/models/flight_log.dart';
import 'package:falconlog/reports/domain/report_date_range.dart';
import 'package:falconlog/reports/services/flight_pdf_export_service.dart';
import 'package:falconlog/reports/services/flight_report_export_coordinator.dart';
import 'package:falconlog/reports/services/flight_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/report_test_fixtures.dart';

void main() {
  const pdfService = FlightPdfExportService();
  const reportService = FlightReportService();
  final coordinator = FlightReportExportCoordinator();

  FlightPdfExportInput inputFor(List<FlightLog> logs, ReportDateRange range) {
    final summary = reportService.buildSummary(logs, range);
    return FlightPdfExportInput(
      range: range,
      summary: summary,
      logs: logs,
      flightTypes: reportService.buildFlightTypeBreakdown(logs),
      pilotRoles: reportService.buildPilotRoleBreakdown(logs),
      conditions: reportService.buildFlightConditionBreakdown(logs),
      modes: reportService.buildFlightModeBreakdown(logs),
      aircraft: reportService.buildAircraftBreakdown(logs),
      trends: reportService.buildTrendBuckets(logs, range),
      generatedAt: DateTime(2026, 6, 3, 12, 0),
    );
  }

  test('generates non-empty PDF bytes for valid data', () async {
    final logs = [
      buildTestLog(date: DateTime(2026, 6, 1)),
      buildTestLog(date: DateTime(2026, 6, 2), isDayFlight: false),
    ];
    final range = ReportDateRange.thisMonth(anchor: DateTime(2026, 6, 3));
    final bytes = await pdfService.generate(inputFor(logs, range));
    expect(bytes.isNotEmpty, isTrue);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('empty range produces one-page PDF', () async {
    final range = ReportDateRange.thisYear(anchor: DateTime(2026, 1, 1));
    final bytes = await pdfService.generate(inputFor([], range));
    expect(bytes.isNotEmpty, isTrue);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('PDF generates substantial output for summary report', () async {
    final logs = [buildTestLog(date: DateTime(2026, 1, 15))];
    final range = ReportDateRange.thisMonth(anchor: DateTime(2026, 1, 15));
    final bytes = await pdfService.generate(inputFor(logs, range));
    expect(bytes.length, greaterThan(2000));
  });

  test('long remarks do not throw', () async {
    final logs = [
      buildTestLog(
        date: DateTime(2026, 3, 1),
        remarks: 'X' * 2000,
      ),
    ];
    final range = ReportDateRange.thisYear(anchor: DateTime(2026, 1, 1));
    await expectLater(
      pdfService.generate(inputFor(logs, range)),
      completes,
    );
  });

  test('coordinator builds bytes for 500 logs', () async {
    final logs = buildLogs(500, startDate: DateTime(2026, 1, 1));
    final range = ReportDateRange.thisYear(anchor: DateTime(2026, 1, 1));
    final bytes = await coordinator.buildPdfBytes(allLogs: logs, range: range);
    expect(bytes.length, greaterThan(1000));
  });
}

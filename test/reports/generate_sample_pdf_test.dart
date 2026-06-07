import 'dart:io';

import 'package:falconlog/reports/domain/report_date_range.dart';
import 'package:falconlog/reports/services/flight_report_export_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/report_test_fixtures.dart';

void main() {
  test('writes sample all-time PDF to build/', () async {
    final coordinator = FlightReportExportCoordinator();
    final logs = [
      buildTestLog(id: '1', date: DateTime(2026, 5, 10), durationHours: 1),
      buildTestLog(id: '2', date: DateTime(2026, 5, 10), durationMinutes: 50, isDayFlight: false),
      buildTestLog(id: '3', date: DateTime(2026, 5, 11), durationHours: 2),
      buildTestLog(id: '4', date: DateTime(2026, 6, 1), isSimulated: true),
    ];
    final bytes = await coordinator.buildPdfBytes(
      allLogs: logs,
      range: ReportDateRange.allTime(),
    );
    final dir = Directory('build');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('build/sample_all_time_report.pdf');
    await file.writeAsBytes(bytes);
    expect(await file.exists(), isTrue);
    expect(bytes.length, greaterThan(2000));
  });
}

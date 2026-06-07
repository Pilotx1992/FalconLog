import 'package:falconlog/reports/domain/report_date_range.dart';
import 'package:falconlog/reports/pdf/flight_pdf_logbook_builder.dart';
import 'package:falconlog/reports/services/flight_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/report_test_fixtures.dart';

void main() {
  const reportService = FlightReportService();

  group('FlightPdfLogbookBuilder', () {
    test('groups same-date flights under one date with sequence numbers', () {
      final logs = [
        buildTestLog(id: 'a', date: DateTime(2026, 5, 10)),
        buildTestLog(id: 'b', date: DateTime(2026, 5, 10)),
        buildTestLog(id: 'c', date: DateTime(2026, 5, 11)),
      ];
      final filtered = reportService.filterByDateRange(
        logs,
        ReportDateRange.allTime(),
      );

      final flights =
          FlightPdfLogbookBuilder.buildRows(filtered).where((r) => r.isFlight);

      expect(flights.length, 3);
      final rows = flights.toList();
      expect(rows[0].showDate, isTrue);
      expect(rows[0].date, '10 May 2026');
      expect(rows[0].sequenceNo, '1');
      expect(rows[1].showDate, isFalse);
      expect(rows[1].sequenceNo, '2');
      expect(rows[2].showDate, isTrue);
      expect(rows[2].date, '11 May 2026');
      expect(rows[2].sequenceNo, '1');
    });

    test('daily subtotal only when group has multiple flights', () {
      final logs = [
        buildTestLog(date: DateTime(2026, 5, 10)),
        buildTestLog(id: 'b', date: DateTime(2026, 5, 10)),
        buildTestLog(id: 'c', date: DateTime(2026, 5, 11)),
      ];
      final filtered = reportService.filterByDateRange(
        logs,
        ReportDateRange.allTime(),
      );
      final rows = FlightPdfLogbookBuilder.buildRows(filtered);

      final subtotals = rows
          .where((r) => r.kind == LogbookRowKind.dailySubtotal)
          .toList();
      expect(subtotals.length, 1);
      expect(subtotals.first.subtotalLabel, contains('10 May 2026'));
    });

    test('logbook headers include Flight Date and Mode', () {
      expect(FlightPdfLogbookBuilder.logbookHeaders, [
        'Flight Date',
        'No.',
        'Flight Type',
        'Duration',
        'Aircraft Type',
        'Pilot Role',
        'Condition',
        'Mode',
      ]);
    });

    test('flight rows include mode label', () {
      final logs = [
        buildTestLog(id: 'a', date: DateTime(2026, 5, 10), isSimulated: true),
        buildTestLog(id: 'b', date: DateTime(2026, 5, 10)),
      ];
      final filtered = reportService.filterByDateRange(
        logs,
        ReportDateRange.allTime(),
      );
      final rows = FlightPdfLogbookBuilder.buildRows(filtered)
          .where((r) => r.isFlight)
          .toList();
      expect(rows[0].mode, 'Simulator');
      expect(rows[1].mode, 'Actual');
    });

    test('paginateWithMeta provides row range metadata', () {
      final logs = List.generate(
        25,
        (i) => buildTestLog(
          id: 'r-$i',
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
        ),
      );
      final filtered = reportService.filterByDateRange(
        logs,
        ReportDateRange.allTime(),
      );
      final summary = reportService.buildSummary(filtered, ReportDateRange.allTime());
      final slices = FlightPdfLogbookBuilder.paginateWithMeta(
        filtered,
        summary: summary,
      );
      expect(slices.length, greaterThan(1));
      expect(slices.first.firstFlightIndex, 1);
      expect(slices.first.totalFlights, 25);
    });

    test('paginate keeps groups intact when they fit on one page', () {
      final logs = List.generate(
        5,
        (i) => buildTestLog(
          id: 'p-$i',
          date: DateTime(2026, 1, 1).add(Duration(days: i ~/ 2)),
        ),
      );
      final filtered = reportService.filterByDateRange(
        logs,
        ReportDateRange.allTime(),
      );
      final range = ReportDateRange.allTime();
      final summary = reportService.buildSummary(filtered, range);

      final pages = FlightPdfLogbookBuilder.paginate(
        filtered,
        summary: summary,
      );

      expect(pages, isNotEmpty);
      expect(
        pages.expand((p) => p.where((r) => r.isFlight)).length,
        filtered.length,
      );
    });
  });
}

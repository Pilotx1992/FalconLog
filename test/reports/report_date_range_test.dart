import 'package:falconlog/reports/domain/report_date_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportDateRange.allTime', () {
    test('contains any reasonable flight date', () {
      final range = ReportDateRange.allTime();
      expect(range.formatLabel(), 'All time');
      expect(range.contains(DateTime(2020, 5, 15)), isTrue);
      expect(range.contains(DateTime(1899, 12, 31)), isFalse);
      expect(range.contains(DateTime(2101, 1, 1)), isFalse);
    });
  });

  group('ReportDateRange.thisMonth', () {
    test('includes only current calendar month', () {
      final anchor = DateTime(2026, 6, 15);
      final range = ReportDateRange.thisMonth(anchor: anchor);
      expect(range.start, DateTime(2026, 6, 1));
      expect(range.end, DateTime(2026, 6, 30));
      expect(range.contains(DateTime(2026, 6, 1)), isTrue);
      expect(range.contains(DateTime(2026, 5, 31)), isFalse);
      expect(range.contains(DateTime(2026, 7, 1)), isFalse);
    });
  });

  group('ReportDateRange.thisYear', () {
    test('includes only selected calendar year', () {
      final range = ReportDateRange.thisYear(anchor: DateTime(2026, 8, 1));
      expect(range.start, DateTime(2026, 1, 1));
      expect(range.end, DateTime(2026, 12, 31));
      expect(range.contains(DateTime(2026, 6, 15)), isTrue);
      expect(range.contains(DateTime(2025, 12, 31)), isFalse);
    });
  });

  group('ReportDateRange.custom', () {
    test('includes start and end boundary dates', () {
      final range = ReportDateRange.custom(
        start: DateTime(2026, 1, 10),
        end: DateTime(2026, 1, 20),
      );
      expect(range.contains(DateTime(2026, 1, 10)), isTrue);
      expect(range.contains(DateTime(2026, 1, 20)), isTrue);
      expect(range.contains(DateTime(2026, 1, 9)), isFalse);
    });

    test('rejects invalid custom range', () {
      expect(
        () => ReportDateRange.custom(
          start: DateTime(2026, 2, 1),
          end: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('ReportDateRange.resolve', () {
    test('does not throw for invalid custom dates', () {
      final range = ReportDateRange.resolve(
        kind: ReportPeriodKind.custom,
        customStart: DateTime(2026, 2, 1),
        customEnd: DateTime(2026, 1, 1),
      );
      expect(range.kind, ReportPeriodKind.custom);
      expect(range.start, range.end);
    });
  });

  group('reportTitle', () {
    test('is always Flight Log Report', () {
      expect(ReportDateRange.allTime().reportTitle(), 'Flight Log Report');
      expect(
        ReportDateRange.thisMonth().reportTitle(),
        'Flight Log Report',
      );
    });
  });
}

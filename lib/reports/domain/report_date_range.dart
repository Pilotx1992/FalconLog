import 'package:intl/intl.dart';

import '../../notifications/domain/currency_daily_notification.dart';

enum ReportPeriodKind { allTime, thisMonth, thisYear, custom }

class ReportDateRange {
  ReportDateRange({
    required this.kind,
    required this.start,
    required this.end,
  }) : assert(!start.isAfter(end), 'start must not be after end');

  final ReportPeriodKind kind;
  final DateTime start;
  final DateTime end;

  static final DateTime _allTimeStart = DateTime(1900, 1, 1);
  static final DateTime _allTimeEnd = DateTime(2100, 12, 31);

  factory ReportDateRange.allTime() {
    return ReportDateRange(
      kind: ReportPeriodKind.allTime,
      start: dateOnly(_allTimeStart),
      end: dateOnly(_allTimeEnd),
    );
  }

  factory ReportDateRange.thisMonth({DateTime? anchor}) {
    final a = dateOnly(anchor ?? DateTime.now());
    final start = DateTime(a.year, a.month, 1);
    final end = DateTime(a.year, a.month + 1, 0);
    return ReportDateRange(
      kind: ReportPeriodKind.thisMonth,
      start: dateOnly(start),
      end: dateOnly(end),
    );
  }

  factory ReportDateRange.thisYear({DateTime? anchor}) {
    final a = dateOnly(anchor ?? DateTime.now());
    return ReportDateRange(
      kind: ReportPeriodKind.thisYear,
      start: DateTime(a.year, 1, 1),
      end: DateTime(a.year, 12, 31),
    );
  }

  factory ReportDateRange.custom({
    required DateTime start,
    required DateTime end,
  }) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    if (s.isAfter(e)) {
      throw ArgumentError('startDate must not be after endDate');
    }
    return ReportDateRange(
      kind: ReportPeriodKind.custom,
      start: s,
      end: e,
    );
  }

  /// Resolves a range for UI/preview without throwing on invalid custom dates.
  factory ReportDateRange.resolve({
    required ReportPeriodKind kind,
    DateTime? customStart,
    DateTime? customEnd,
    DateTime? anchor,
  }) {
    switch (kind) {
      case ReportPeriodKind.allTime:
        return ReportDateRange.allTime();
      case ReportPeriodKind.thisMonth:
        return ReportDateRange.thisMonth(anchor: anchor);
      case ReportPeriodKind.thisYear:
        return ReportDateRange.thisYear(anchor: anchor);
      case ReportPeriodKind.custom:
        final s = dateOnly(customStart ?? DateTime.now());
        final e = dateOnly(customEnd ?? DateTime.now());
        if (s.isAfter(e)) {
          return ReportDateRange(
            kind: ReportPeriodKind.custom,
            start: s,
            end: s,
          );
        }
        return ReportDateRange(
          kind: ReportPeriodKind.custom,
          start: s,
          end: e,
        );
    }
  }

  bool contains(DateTime flightDate) {
    final d = dateOnly(flightDate);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  String formatLabel() {
    switch (kind) {
      case ReportPeriodKind.allTime:
        return 'All time';
      case ReportPeriodKind.thisMonth:
      case ReportPeriodKind.thisYear:
      case ReportPeriodKind.custom:
        final fmt = DateFormat('d MMM yyyy');
        if (start == end) return fmt.format(start);
        return '${fmt.format(start)} - ${fmt.format(end)}';
    }
  }

  /// Numeric date label for UI preview (e.g. 04/06/2026).
  String formatNumericLabel() {
    switch (kind) {
      case ReportPeriodKind.allTime:
        return 'All time';
      case ReportPeriodKind.thisMonth:
      case ReportPeriodKind.thisYear:
      case ReportPeriodKind.custom:
        final fmt = DateFormat('dd/MM/yyyy');
        if (start == end) return fmt.format(start);
        return '${fmt.format(start)} - ${fmt.format(end)}';
    }
  }

  String reportTitle() => 'Flight Log Report';
}

bool isValidCustomRange(DateTime start, DateTime end) =>
    !dateOnly(start).isAfter(dateOnly(end));

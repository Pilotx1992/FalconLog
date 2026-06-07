import 'package:intl/intl.dart';

import '../../models/flight_log.dart';
import '../domain/flight_log_duration.dart';
import '../domain/flight_log_labels.dart';
import '../domain/flight_report_summary.dart';
import '../../notifications/domain/currency_daily_notification.dart';

/// Set to false to hide all daily subtotal rows.
const bool kLogbookShowDailySubtotals = true;

/// Daily subtotals appear only when a date group has more than this many flights.
const int kLogbookDailySubtotalMinFlights = 2;

/// Approximate max flight rows on page 1 (includes KPI header).
const int kLogbookMaxFlightRowsFirstPage = 12;

/// Approximate max flight rows per continuation logbook page.
const int kLogbookMaxFlightRowsPerPage = 18;

enum LogbookRowKind { flight, dailySubtotal, grandTotal }

class LogbookRenderRow {
  const LogbookRenderRow({
    required this.kind,
    required this.groupIndex,
    this.date = '',
    this.sequenceNo = '',
    this.flightType = '',
    this.duration = '',
    this.aircraftType = '',
    this.pilotRole = '',
    this.condition = '',
    this.mode = '',
    this.subtotalLabel = '',
    this.showDate = false,
  });

  final LogbookRowKind kind;
  final int groupIndex;
  final String date;
  final String sequenceNo;
  final String flightType;
  final String duration;
  final String aircraftType;
  final String pilotRole;
  final String condition;
  final String mode;
  final String subtotalLabel;
  final bool showDate;

  bool get isFlight => kind == LogbookRowKind.flight;
}

class LogbookDateGroup {
  const LogbookDateGroup({
    required this.date,
    required this.flights,
    required this.totalHours,
  });

  final DateTime date;
  final List<FlightLog> flights;
  final double totalHours;

  int get flightCount => flights.length;
}

class LogbookPageSlice {
  const LogbookPageSlice({
    required this.rows,
    required this.firstFlightIndex,
    required this.lastFlightIndex,
    required this.totalFlights,
    required this.pageIndex,
  });

  final List<LogbookRenderRow> rows;
  final int firstFlightIndex;
  final int lastFlightIndex;
  final int totalFlights;
  final int pageIndex;

  bool get hasRowRange => totalFlights > 0 && lastFlightIndex >= firstFlightIndex;
}

abstract final class FlightPdfLogbookBuilder {
  FlightPdfLogbookBuilder._();

  static const logbookHeaders = [
    'Flight Date',
    'No.',
    'Flight Type',
    'Duration',
    'Aircraft Type',
    'Pilot Role',
    'Condition',
    'Mode',
  ];

  static List<LogbookDateGroup> groupByDate(List<FlightLog> logs) {
    if (logs.isEmpty) return [];

    final grouped = <DateTime, List<FlightLog>>{};
    for (final log in logs) {
      final key = dateOnly(log.date);
      grouped.putIfAbsent(key, () => []).add(log);
    }

    final dates = grouped.keys.toList()..sort();
    return [
      for (final date in dates)
        LogbookDateGroup(
          date: date,
          flights: grouped[date]!,
          totalHours: grouped[date]!
              .fold(0.0, (sum, log) => sum + durationInHours(log)),
        ),
    ];
  }

  static List<LogbookRenderRow> buildRows(List<FlightLog> logs) {
    final groups = groupByDate(logs);
    if (groups.isEmpty) return [];

    final dateFmt = DateFormat('d MMM yyyy');
    final rows = <LogbookRenderRow>[];

    for (var gi = 0; gi < groups.length; gi++) {
      rows.addAll(_rowsForGroup(groups[gi], gi, dateFmt));
    }

    return rows;
  }

  static List<LogbookRenderRow> _rowsForGroup(
    LogbookDateGroup group,
    int groupIndex,
    DateFormat dateFmt,
  ) {
    final dateLabel = dateFmt.format(group.date);
    final rows = <LogbookRenderRow>[];

    for (var i = 0; i < group.flights.length; i++) {
      final log = group.flights[i];
      rows.add(
        LogbookRenderRow(
          kind: LogbookRowKind.flight,
          groupIndex: groupIndex,
          date: dateLabel,
          sequenceNo: '${i + 1}',
          flightType: flightTypesLabel(log.flightTypes),
          duration: formatDurationHhMm(durationInHours(log)),
          aircraftType: log.aircraftType,
          pilotRole: pilotRoleLabel(log.pilotRole),
          condition: flightConditionLabel(log.isDayFlight),
          mode: flightModeLabel(log.isSimulated),
          showDate: i == 0,
        ),
      );
    }

    if (kLogbookShowDailySubtotals &&
        group.flightCount >= kLogbookDailySubtotalMinFlights) {
      final countLabel = group.flightCount.toString().padLeft(2, '0');
      rows.add(
        LogbookRenderRow(
          kind: LogbookRowKind.dailySubtotal,
          groupIndex: groupIndex,
          subtotalLabel:
              'Total for $dateLabel: $countLabel flights \u00b7 ${formatDurationHhMm(group.totalHours)}',
        ),
      );
    }

    return rows;
  }

  static LogbookRenderRow grandTotalRow(FlightReportSummary summary) {
    return LogbookRenderRow(
      kind: LogbookRowKind.grandTotal,
      groupIndex: -1,
      subtotalLabel:
          'Period total: ${summary.totalFlights} flights \u00b7 ${formatDurationHhMm(summary.totalHours)}',
    );
  }

  static List<List<LogbookRenderRow>> paginate(
    List<FlightLog> logs, {
    FlightReportSummary? summary,
  }) {
    return paginateWithMeta(logs, summary: summary)
        .map((slice) => slice.rows)
        .toList();
  }

  static List<LogbookPageSlice> paginateWithMeta(
    List<FlightLog> logs, {
    FlightReportSummary? summary,
  }) {
    final totalFlights = logs.length;
    final groups = groupByDate(logs);
    if (groups.isEmpty) {
      return [
        const LogbookPageSlice(
          rows: [],
          firstFlightIndex: 0,
          lastFlightIndex: 0,
          totalFlights: 0,
          pageIndex: 0,
        ),
      ];
    }

    final rawPages = <List<LogbookRenderRow>>[];
    var currentPage = <LogbookRenderRow>[];
    var flightRowsOnPage = 0;
    var isFirstPhysicalPage = true;
    final dateFmt = DateFormat('d MMM yyyy');

    int pageLimit() =>
        isFirstPhysicalPage ? kLogbookMaxFlightRowsFirstPage : kLogbookMaxFlightRowsPerPage;

    void startNewPage() {
      if (currentPage.isNotEmpty) {
        rawPages.add(currentPage);
        isFirstPhysicalPage = false;
      }
      currentPage = [];
      flightRowsOnPage = 0;
    }

    for (var gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      final groupRows = _rowsForGroup(group, gi, dateFmt);
      final groupFlightCount = group.flightCount;
      final limit = pageLimit();

      if (flightRowsOnPage > 0 && flightRowsOnPage + groupFlightCount > limit) {
        startNewPage();
      }

      if (groupFlightCount > pageLimit()) {
        var flightOffset = 0;
        var showDateOnNext = true;
        LogbookRenderRow? subtotalRow;

        for (final row in groupRows) {
          if (row.kind == LogbookRowKind.dailySubtotal) {
            subtotalRow = row;
            break;
          }
        }

        while (flightOffset < group.flightCount) {
          final limit = pageLimit();
          if (flightRowsOnPage > 0 && flightRowsOnPage >= limit) {
            startNewPage();
            showDateOnNext = false;
          }

          final remainingPage = pageLimit() - flightRowsOnPage;
          final take = remainingPage < (group.flightCount - flightOffset)
              ? remainingPage
              : (group.flightCount - flightOffset);

          for (var j = 0; j < take; j++) {
            final src = groupRows[flightOffset + j];
            currentPage.add(
              LogbookRenderRow(
                kind: src.kind,
                groupIndex: src.groupIndex,
                date: src.date,
                sequenceNo: src.sequenceNo,
                flightType: src.flightType,
                duration: src.duration,
                aircraftType: src.aircraftType,
                pilotRole: src.pilotRole,
                condition: src.condition,
                mode: src.mode,
                showDate: showDateOnNext && j == 0,
              ),
            );
          }
          flightOffset += take;
          flightRowsOnPage += take;
          showDateOnNext = false;

          if (flightOffset < group.flightCount) startNewPage();
        }

        if (subtotalRow != null) currentPage.add(subtotalRow);
        continue;
      }

      currentPage.addAll(groupRows);
      flightRowsOnPage += groupFlightCount;
    }

    if (currentPage.isNotEmpty) rawPages.add(currentPage);

    if (summary != null && rawPages.isNotEmpty) {
      rawPages.last.add(grandTotalRow(summary));
    }

    if (rawPages.isEmpty) {
      return [
        LogbookPageSlice(
          rows: summary != null ? [grandTotalRow(summary)] : [],
          firstFlightIndex: 0,
          lastFlightIndex: 0,
          totalFlights: totalFlights,
          pageIndex: 0,
        ),
      ];
    }

    var flightIndex = 0;
    final slices = <LogbookPageSlice>[];
    for (var pi = 0; pi < rawPages.length; pi++) {
      final pageRows = rawPages[pi];
      final flightCountOnPage =
          pageRows.where((r) => r.isFlight).length;
      final first = flightIndex + 1;
      final last = flightIndex + flightCountOnPage;
      flightIndex = last;

      slices.add(
        LogbookPageSlice(
          rows: pageRows,
          firstFlightIndex: flightCountOnPage > 0 ? first : 0,
          lastFlightIndex: flightCountOnPage > 0 ? last : 0,
          totalFlights: totalFlights,
          pageIndex: pi,
        ),
      );
    }

    return slices;
  }
}

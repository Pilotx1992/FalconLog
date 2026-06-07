import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/flight_log.dart';
import '../domain/aircraft_breakdown.dart';
import '../domain/flight_condition_breakdown.dart';
import '../domain/flight_log_duration.dart';
import '../domain/flight_mode_breakdown.dart';
import '../domain/flight_report_summary.dart';
import '../domain/flight_type_breakdown.dart';
import '../domain/period_bucket.dart';
import '../domain/pilot_role_breakdown.dart';
import '../domain/report_date_range.dart';
import '../pdf/flight_pdf_analytics_layout.dart';
import '../pdf/flight_pdf_logbook_builder.dart';
import '../pdf/flight_pdf_table_builder.dart';
import '../pdf/flight_pdf_theme.dart';

class FlightPdfExportInput {
  const FlightPdfExportInput({
    required this.range,
    required this.summary,
    required this.logs,
    required this.flightTypes,
    required this.pilotRoles,
    required this.conditions,
    required this.modes,
    required this.aircraft,
    required this.trends,
    required this.generatedAt,
  });

  final ReportDateRange range;
  final FlightReportSummary summary;
  final List<FlightLog> logs;
  final FlightTypeBreakdown flightTypes;
  final PilotRoleBreakdown pilotRoles;
  final FlightConditionBreakdown conditions;
  final FlightModeBreakdown modes;
  final AircraftBreakdown aircraft;
  final List<PeriodBucket> trends;
  final DateTime generatedAt;
}

class FlightPdfExportService {
  const FlightPdfExportService();

  Future<Uint8List> generate(FlightPdfExportInput input) async {
    final doc = pw.Document();
    final dateTimeFmt = DateFormat('dd MMM yyyy, HH:mm');
    final periodLabel = input.range.formatLabel();
    final bannerSubtitle =
        '$periodLabel · Generated ${dateTimeFmt.format(input.generatedAt)}';

    if (input.summary.isEmpty) {
      doc.addPage(
        _buildPage(
          header: FlightPdfTableBuilder.documentHeaderFull(
            subtitle: bannerSubtitle,
          ),
          pageNumber: 1,
          totalPages: 1,
          periodLabel: periodLabel,
          body: pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.SizedBox(height: 48),
                pw.Center(
                  child: pw.Text(
                    'No flight records found for the selected period.',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: FlightPdfTheme.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return doc.save();
    }

    final logbookSlices = FlightPdfLogbookBuilder.paginateWithMeta(
      input.logs,
      summary: input.summary,
    );
    final analyticsPlans =
        FlightPdfAnalyticsLayout.planPages(_buildAnalyticsBlocks(input));
    final totalPages = logbookSlices.length + analyticsPlans.length;
    var pageNumber = 1;

    for (final slice in logbookSlices) {
      final isFirstPage = slice.pageIndex == 0;
      doc.addPage(
        _buildPage(
          header: isFirstPage
              ? FlightPdfTableBuilder.documentHeaderFull(
                  subtitle: bannerSubtitle,
                  summary: input.summary,
                )
              : FlightPdfTableBuilder.documentHeaderCompact(
                  subtitle: bannerSubtitle,
                ),
          pageNumber: pageNumber,
          totalPages: totalPages,
          periodLabel: periodLabel,
          rowRangeLabel: slice.hasRowRange && logbookSlices.length > 1
              ? 'Showing rows ${slice.firstFlightIndex} to ${slice.lastFlightIndex} of ${slice.totalFlights}'
              : null,
          body: pw.Expanded(
            child: FlightPdfTableBuilder.logbookTable(rows: slice.rows),
          ),
        ),
      );
      pageNumber++;
    }

    for (final plan in analyticsPlans) {
      doc.addPage(
        _buildPage(
          header: FlightPdfTableBuilder.documentHeaderCompact(
            subtitle: bannerSubtitle,
          ),
          pageNumber: pageNumber,
          totalPages: totalPages,
          periodLabel: periodLabel,
          body: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: FlightPdfAnalyticsLayout.renderPage(plan),
          ),
        ),
      );
      pageNumber++;
    }

    return doc.save();
  }

  pw.Page _buildPage({
    required pw.Widget header,
    required int pageNumber,
    required int totalPages,
    required String periodLabel,
    required pw.Widget body,
    String? rowRangeLabel,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(FlightPdfTheme.pageMargin),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          header,
          pw.SizedBox(height: 8),
          body,
          _footer(
            periodLabel: periodLabel,
            pageNumber: pageNumber,
            totalPages: totalPages,
            rowRangeLabel: rowRangeLabel,
          ),
        ],
      ),
    );
  }

  pw.Widget _footer({
    required String periodLabel,
    required int pageNumber,
    required int totalPages,
    String? rowRangeLabel,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (rowRangeLabel != null)
            pw.Text(
              rowRangeLabel,
              style: pw.TextStyle(
                fontSize: FlightPdfTheme.footerFontSize,
                color: FlightPdfTheme.footerGray,
              ),
              textAlign: pw.TextAlign.center,
            ),
          pw.Text(
            'Generated by FalconLog · $periodLabel · Page $pageNumber of $totalPages',
            style: pw.TextStyle(
              fontSize: FlightPdfTheme.footerFontSize,
              color: FlightPdfTheme.footerGray,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<AnalyticsBlock> _buildAnalyticsBlocks(FlightPdfExportInput input) {
    final blocks = <AnalyticsBlock>[];
    final compact = input.logs.length > 80;

    final flightType = _flightTypeBlock(input.flightTypes);
    if (flightType != null) blocks.add(flightType);

    final pilotRole = _pilotRoleBlock(input.pilotRoles);
    if (pilotRole != null) blocks.add(pilotRole);

    blocks.add(_conditionBlock(input.conditions));
    blocks.add(_modeBlock(input.modes));
    blocks.addAll(_aircraftBlocks(input.aircraft, compact: compact));

    if (input.trends.isNotEmpty) {
      blocks.add(_trendBlock(input.range.kind, input.trends));
    }

    return blocks;
  }

  AnalyticsBlock? _flightTypeBlock(FlightTypeBreakdown b) {
    if (b.rows.isEmpty) return null;
    final rows = b.rows
        .map((r) => [
              r.label,
              '${r.flights}',
              formatDurationHhMm(r.hours),
              formatDurationHhMm(r.dayHours),
              formatDurationHhMm(r.nightHours),
              '${r.percentOfFlights.toStringAsFixed(0)}%',
            ])
        .toList();
    return AnalyticsBlock(
      title: 'Flight Type Breakdown',
      estimatedHeight: FlightPdfAnalyticsLayout.estimateTableBlockHeight(
        rows.length,
        hasTotals: true,
      ),
      content: FlightPdfTableBuilder.dataTable(
        headers: ['Flight Type', 'Flights', 'Hours', 'Day', 'Night', '%'],
        rows: rows,
        totalsRow: [
          'Total',
          '${b.totalFlights}',
          formatDurationHhMm(b.totalHours),
          '',
          '',
          '100%',
        ],
        alignments: const [
          PdfCellAlign.left,
          PdfCellAlign.right,
          PdfCellAlign.right,
          PdfCellAlign.right,
          PdfCellAlign.right,
          PdfCellAlign.right,
        ],
        columnWidths: FlightPdfTableBuilder.pivotColumnWidths(
          labelColumns: 1,
          numericColumns: 5,
        ),
      ),
    );
  }

  AnalyticsBlock? _pilotRoleBlock(PilotRoleBreakdown b) {
    if (b.rows.isEmpty) return null;
    var totalFlights = 0;
    var totalHours = 0.0;
    for (final r in b.rows) {
      totalFlights += r.flights;
      totalHours += r.hours;
    }
    final rows = b.rows
        .map((r) => [
              r.label,
              '${r.flights}',
              formatDurationHhMm(r.hours),
              formatDurationHhMm(r.dayHours),
              formatDurationHhMm(r.nightHours),
            ])
        .toList();
    return AnalyticsBlock(
      title: 'Pilot Role Breakdown',
      estimatedHeight: FlightPdfAnalyticsLayout.estimateTableBlockHeight(
        rows.length,
        hasTotals: true,
      ),
      content: FlightPdfTableBuilder.dataTable(
        headers: ['Pilot Role', 'Flights', 'Hours', 'Day', 'Night'],
        rows: rows,
        totalsRow: [
          'Total',
          '$totalFlights',
          formatDurationHhMm(totalHours),
          '',
          '',
        ],
        alignments: const [
          PdfCellAlign.left,
          PdfCellAlign.right,
          PdfCellAlign.right,
          PdfCellAlign.right,
          PdfCellAlign.right,
        ],
        columnWidths: FlightPdfTableBuilder.pivotColumnWidths(
          labelColumns: 1,
          numericColumns: 4,
        ),
      ),
    );
  }

  AnalyticsBlock _conditionBlock(FlightConditionBreakdown b) {
    final rows = b.rows
        .map((r) => [
              r.label,
              '${r.flights}',
              formatDurationHhMm(r.hours),
            ])
        .toList();
    return AnalyticsBlock(
      title: 'Flight Condition Breakdown',
      estimatedHeight:
          FlightPdfAnalyticsLayout.estimateTableBlockHeight(rows.length),
      content: FlightPdfTableBuilder.dataTable(
        headers: ['Condition', 'Flights', 'Hours'],
        rows: rows,
        alignments: const [
          PdfCellAlign.left,
          PdfCellAlign.right,
          PdfCellAlign.right,
        ],
        columnWidths: FlightPdfTableBuilder.pivotColumnWidths(
          labelColumns: 1,
          numericColumns: 2,
          labelFlex: 1.5,
        ),
      ),
    );
  }

  AnalyticsBlock _modeBlock(FlightModeBreakdown b) {
    final rows = b.rows
        .map((r) => [
              r.label,
              '${r.flights}',
              formatDurationHhMm(r.hours),
            ])
        .toList();
    return AnalyticsBlock(
      title: 'Flight Mode Breakdown',
      estimatedHeight:
          FlightPdfAnalyticsLayout.estimateTableBlockHeight(rows.length),
      content: FlightPdfTableBuilder.dataTable(
        headers: ['Mode', 'Flights', 'Hours'],
        rows: rows,
        alignments: const [
          PdfCellAlign.left,
          PdfCellAlign.right,
          PdfCellAlign.right,
        ],
        columnWidths: FlightPdfTableBuilder.pivotColumnWidths(
          labelColumns: 1,
          numericColumns: 2,
          labelFlex: 1.5,
        ),
      ),
    );
  }

  List<AnalyticsBlock> _aircraftBlocks(AircraftBreakdown b, {bool compact = false}) {
    final showLandings = b.byAircraftType.any((r) => r.landings > 0);
    final headers = [
      'Aircraft Type',
      'Flights',
      'Hours',
      'Day',
      'Night',
      if (showLandings) 'Landings',
    ];
    final align = [
      PdfCellAlign.left,
      PdfCellAlign.right,
      PdfCellAlign.right,
      PdfCellAlign.right,
      PdfCellAlign.right,
      if (showLandings) PdfCellAlign.right,
    ];
    final numericCount = headers.length - 1;
    final rows = b.byAircraftType
        .map((r) => [
              r.aircraftType,
              '${r.flights}',
              formatDurationHhMm(r.hours),
              formatDurationHhMm(r.dayHours),
              formatDurationHhMm(r.nightHours),
              if (showLandings) '${r.landings}',
            ])
        .toList();

    final blocks = <AnalyticsBlock>[
      AnalyticsBlock(
        title: 'Aircraft Type Breakdown',
        estimatedHeight:
            FlightPdfAnalyticsLayout.estimateTableBlockHeight(rows.length),
        content: FlightPdfTableBuilder.dataTable(
          headers: headers,
          rows: rows,
          alignments: align,
          columnWidths: FlightPdfTableBuilder.pivotColumnWidths(
            labelColumns: 1,
            numericColumns: numericCount,
          ),
        ),
      ),
    ];

    if (compact && b.hasRegistrationData && b.byRegistration.isNotEmpty) {
      blocks.add(
        AnalyticsBlock(
          title: 'Registration Breakdown',
          estimatedHeight: 36,
          content: pw.Text(
            'Registration breakdown omitted for large reports (80+ flights).',
            style: FlightPdfTheme.body(),
          ),
        ),
      );
    } else if (!compact &&
        b.hasRegistrationData &&
        b.byRegistration.isNotEmpty) {
      final regRows = b.byRegistration
          .map((r) => [
                r.registration ?? r.key,
                r.aircraftType,
                '${r.flights}',
                formatDurationHhMm(r.hours),
                formatDurationHhMm(r.dayHours),
                formatDurationHhMm(r.nightHours),
              ])
          .toList();
      blocks.add(
        AnalyticsBlock(
          title: 'Registration Breakdown',
          estimatedHeight: FlightPdfAnalyticsLayout.estimateTableBlockHeight(
            regRows.length,
          ),
          content: FlightPdfTableBuilder.dataTable(
            headers: [
              'Registration',
              'Aircraft Type',
              'Flights',
              'Hours',
              'Day',
              'Night',
            ],
            rows: regRows,
            alignments: const [
              PdfCellAlign.left,
              PdfCellAlign.left,
              PdfCellAlign.right,
              PdfCellAlign.right,
              PdfCellAlign.right,
              PdfCellAlign.right,
            ],
            columnWidths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(0.8),
              5: const pw.FlexColumnWidth(0.8),
            },
          ),
        ),
      );
    }

    return blocks;
  }

  AnalyticsBlock _trendBlock(ReportPeriodKind kind, List<PeriodBucket> trends) {
    String title;
    switch (kind) {
      case ReportPeriodKind.allTime:
      case ReportPeriodKind.thisYear:
        title = 'Monthly Totals';
      case ReportPeriodKind.thisMonth:
        title = 'Weekly Totals';
      case ReportPeriodKind.custom:
        title = 'Daily Totals';
    }
    const maxTrendRows = 22;
    final display =
        trends.length > maxTrendRows ? trends.take(maxTrendRows).toList() : trends;
    final truncated = trends.length > maxTrendRows;
    final rows = display
        .map((t) => [
              t.label,
              '${t.flights}',
              formatDurationHhMm(t.hours),
              formatDurationHhMm(t.dayHours),
              formatDurationHhMm(t.nightHours),
            ])
        .toList();

    return AnalyticsBlock(
      title: title,
      estimatedHeight: FlightPdfAnalyticsLayout.estimateTableBlockHeight(
        rows.length,
        hasNote: truncated,
      ),
      content: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (truncated)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                'Showing first $maxTrendRows periods (${trends.length} total).',
                style: FlightPdfTheme.body(),
              ),
            ),
          FlightPdfTableBuilder.dataTable(
            headers: ['Period', 'Flights', 'Hours', 'Day', 'Night'],
            rows: rows,
            alignments: const [
              PdfCellAlign.left,
              PdfCellAlign.right,
              PdfCellAlign.right,
              PdfCellAlign.right,
              PdfCellAlign.right,
            ],
            columnWidths: FlightPdfTableBuilder.pivotColumnWidths(
              labelColumns: 1,
              numericColumns: 4,
              labelFlex: 1.8,
              numericFlex: 0.75,
            ),
          ),
        ],
      ),
    );
  }
}

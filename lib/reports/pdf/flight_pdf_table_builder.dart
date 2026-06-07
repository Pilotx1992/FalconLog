import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/flight_log_duration.dart';
import '../domain/flight_report_summary.dart';
import 'flight_pdf_logbook_builder.dart';
import 'flight_pdf_theme.dart';

enum PdfCellAlign { left, center, right }

class FlightPdfTableBuilder {
  FlightPdfTableBuilder._();

  static pw.Widget documentHeaderFull({
    required String subtitle,
    FlightReportSummary? summary,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: pw.BoxDecoration(
        color: FlightPdfTheme.bannerBg,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'Flight Log Report',
            style: FlightPdfTheme.bannerTitleStyle(),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            subtitle,
            style: FlightPdfTheme.bannerSubtitleStyle(),
            textAlign: pw.TextAlign.center,
          ),
          if (summary != null && !summary.isEmpty) ...[
            pw.SizedBox(height: 8),
            _kpiCardsRow(summary),
          ],
        ],
      ),
    );
  }

  static pw.Widget documentHeaderCompact({required String subtitle}) {
    return pw.Container(
      width: double.infinity,
      height: FlightPdfTheme.compactBannerHeight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12),
      decoration: pw.BoxDecoration(
        color: FlightPdfTheme.bannerBg,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        subtitle,
        style: FlightPdfTheme.bannerSubtitleStyle(),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _kpiCardsRow(FlightReportSummary summary) {
    final cards = [
      (
        'Total Flights',
        '${summary.totalFlights}',
        FlightPdfTheme.kpiCardTotalBg,
        FlightPdfTheme.kpiCardTotalBorder,
      ),
      (
        'Total Hours',
        formatDurationHhMm(summary.totalHours),
        FlightPdfTheme.kpiCardTotalBg,
        FlightPdfTheme.kpiCardTotalBorder,
      ),
      (
        'Day Hours',
        formatDurationHhMm(summary.dayHours),
        FlightPdfTheme.kpiCardDayBg,
        FlightPdfTheme.kpiCardDayBorder,
      ),
      (
        'Night Hours',
        formatDurationHhMm(summary.nightHours),
        FlightPdfTheme.kpiCardNightBg,
        FlightPdfTheme.kpiCardNightBorder,
      ),
    ];

    return pw.Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 10),
          pw.Expanded(
            child: _kpiCard(cards[i].$1, cards[i].$2, cards[i].$3, cards[i].$4),
          ),
        ],
      ],
    );
  }

  static pw.Widget _kpiCard(
    String label,
    String value,
    PdfColor bg,
    PdfColor borderColor,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value, style: FlightPdfTheme.kpiValueStyle()),
          pw.SizedBox(height: 2),
          pw.Text(label, style: FlightPdfTheme.kpiLabelStyle()),
        ],
      ),
    );
  }

  static Map<int, pw.TableColumnWidth> logbookColumnWidths() => const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(0.35),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(0.65),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FlexColumnWidth(0.55),
        6: pw.FlexColumnWidth(0.55),
        7: pw.FlexColumnWidth(0.5),
      };

  static Map<int, pw.TableColumnWidth> pivotColumnWidths({
    required int labelColumns,
    required int numericColumns,
    double labelFlex = 2.0,
    double numericFlex = 0.8,
  }) {
    final widths = <int, pw.TableColumnWidth>{};
    var i = 0;
    for (var l = 0; l < labelColumns; l++) {
      widths[i++] = pw.FlexColumnWidth(labelFlex);
    }
    for (var n = 0; n < numericColumns; n++) {
      widths[i++] = pw.FlexColumnWidth(numericFlex);
    }
    return widths;
  }

  static pw.Widget analyticsBlockLabel(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(title, style: FlightPdfTheme.analyticsLabelStyle()),
    );
  }

  static pw.Widget pivotTable({
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? totalsRow,
    required List<PdfCellAlign> alignments,
    Map<int, pw.TableColumnWidth>? columnWidths,
    bool splitLongTables = true,
  }) {
    if (!splitLongTables || rows.length <= 22) {
      return dataTable(
        headers: headers,
        rows: rows,
        totalsRow: totalsRow,
        alignments: alignments,
        columnWidths: columnWidths,
      );
    }
    final chunks = <pw.Widget>[];
    for (var i = 0; i < rows.length; i += 22) {
      final end = (i + 22 > rows.length) ? rows.length : i + 22;
      final isLast = end == rows.length;
      chunks.add(
        dataTable(
          headers: headers,
          rows: rows.sublist(i, end),
          totalsRow: isLast ? totalsRow : null,
          alignments: alignments,
          columnWidths: columnWidths,
        ),
      );
      if (!isLast) chunks.add(pw.SizedBox(height: 6));
    }
    return pw.Column(children: chunks);
  }

  static pw.Widget logbookTable({required List<LogbookRenderRow> rows}) {
    const headers = FlightPdfLogbookBuilder.logbookHeaders;
    const alignments = [
      PdfCellAlign.left,
      PdfCellAlign.center,
      PdfCellAlign.left,
      PdfCellAlign.right,
      PdfCellAlign.left,
      PdfCellAlign.center,
      PdfCellAlign.center,
      PdfCellAlign.center,
    ];
    const maxLines = [2, 1, 2, 1, 2, 1, 1, 1];

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: FlightPdfTheme.headerBg),
        children: List.generate(headers.length, (j) {
          return _cell(
            headers[j],
            FlightPdfTheme.headerCell(),
            alignments[j],
            height: FlightPdfTheme.tableHeaderHeight,
            maxLines: 1,
          );
        }),
      ),
    ];

    for (final row in rows) {
      switch (row.kind) {
        case LogbookRowKind.flight:
          final bg = row.groupIndex.isEven
              ? FlightPdfTheme.dateGroupBase
              : FlightPdfTheme.dateGroupAlt;
          tableRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                _cell(
                  row.showDate ? row.date : '',
                  FlightPdfTheme.body(
                    weight: row.showDate ? pw.FontWeight.bold : null,
                  ),
                  alignments[0],
                  maxLines: maxLines[0],
                ),
                _cell(
                  row.sequenceNo,
                  FlightPdfTheme.body(),
                  alignments[1],
                  maxLines: maxLines[1],
                ),
                _cell(
                  row.flightType,
                  FlightPdfTheme.body(),
                  alignments[2],
                  maxLines: maxLines[2],
                ),
                _cell(
                  row.duration,
                  FlightPdfTheme.durationCell(),
                  alignments[3],
                  maxLines: maxLines[3],
                ),
                _cell(
                  row.aircraftType,
                  FlightPdfTheme.body(),
                  alignments[4],
                  maxLines: maxLines[4],
                ),
                _cell(
                  row.pilotRole,
                  FlightPdfTheme.body(),
                  alignments[5],
                  maxLines: maxLines[5],
                ),
                _cell(
                  row.condition,
                  FlightPdfTheme.body(),
                  alignments[6],
                  maxLines: maxLines[6],
                ),
                _cell(
                  row.mode,
                  FlightPdfTheme.body(),
                  alignments[7],
                  maxLines: maxLines[7],
                ),
              ],
            ),
          );
        case LogbookRowKind.dailySubtotal:
        case LogbookRowKind.grandTotal:
          final bg = row.kind == LogbookRowKind.grandTotal
              ? FlightPdfTheme.totalsBg
              : (row.groupIndex.isEven
                  ? FlightPdfTheme.dateGroupBase
                  : FlightPdfTheme.dateGroupAlt);
          tableRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: bg,
                border: pw.Border(
                  top: pw.BorderSide(color: FlightPdfTheme.border, width: 0.5),
                ),
              ),
              children: [
                pw.Container(
                  height: FlightPdfTheme.subtotalRowHeight,
                  padding: FlightPdfTheme.cellPadding,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    row.subtotalLabel,
                    style: FlightPdfTheme.subtotalStyle().copyWith(
                      fontWeight: row.kind == LogbookRowKind.grandTotal
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
                for (var i = 1; i < headers.length; i++)
                  pw.Container(
                    height: FlightPdfTheme.subtotalRowHeight,
                    padding: FlightPdfTheme.cellPadding,
                  ),
              ],
            ),
          );
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: FlightPdfTheme.border, width: 0.5),
      columnWidths: logbookColumnWidths(),
      children: tableRows,
    );
  }

  static Map<int, pw.TableColumnWidth> equalWidths(int count) => {
        for (var i = 0; i < count; i++) i: const pw.FlexColumnWidth(1),
      };

  static pw.Widget dataTable({
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? totalsRow,
    required List<PdfCellAlign> alignments,
    Map<int, pw.TableColumnWidth>? columnWidths,
    double? bodyFontSize,
  }) {
    return _table(
      headers: headers,
      rows: rows,
      totalsRow: totalsRow,
      alignments: alignments,
      columnWidths: columnWidths,
      bodyFontSize: bodyFontSize,
    );
  }

  static pw.Table _table({
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? totalsRow,
    required List<PdfCellAlign> alignments,
    Map<int, pw.TableColumnWidth>? columnWidths,
    double? bodyFontSize,
  }) {
    final widths = columnWidths ?? equalWidths(headers.length);
    final dataStyle = FlightPdfTheme.body(
      fontSize: bodyFontSize ?? FlightPdfTheme.bodyFontSize,
    );

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: FlightPdfTheme.headerBg,
          border: pw.Border(
            bottom: pw.BorderSide(color: FlightPdfTheme.border, width: 0.5),
          ),
        ),
        children: List.generate(headers.length, (j) {
          final align =
              j < alignments.length ? alignments[j] : PdfCellAlign.left;
          return _cell(
            headers[j],
            FlightPdfTheme.headerCell(),
            align,
            height: FlightPdfTheme.tableHeaderHeight,
            maxLines: 1,
          );
        }),
      ),
    ];

    for (var i = 0; i < rows.length; i++) {
      final bg = i.isOdd ? FlightPdfTheme.rowAlt : PdfColors.white;
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: List.generate(rows[i].length, (j) {
            final align = j < alignments.length
                ? alignments[j]
                : PdfCellAlign.left;
            return _cell(
              rows[i][j],
              dataStyle,
              align,
              maxLines: j == 0 ? 2 : 1,
            );
          }),
        ),
      );
    }

    if (totalsRow != null) {
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: FlightPdfTheme.totalsBg,
            border: pw.Border(
              top: pw.BorderSide(color: FlightPdfTheme.border, width: 0.5),
            ),
          ),
          children: List.generate(totalsRow.length, (j) {
            final align =
                j < alignments.length ? alignments[j] : PdfCellAlign.left;
            return _cell(
              totalsRow[j],
              FlightPdfTheme.body(
                weight: pw.FontWeight.bold,
                fontSize: bodyFontSize,
              ),
              align,
              height: FlightPdfTheme.subtotalRowHeight,
              maxLines: 1,
            );
          }),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: FlightPdfTheme.border,
        width: 0.5,
      ),
      columnWidths: widths,
      children: tableRows,
    );
  }

  static pw.Widget _cell(
    String text,
    pw.TextStyle style,
    PdfCellAlign align, {
    double? height,
    int maxLines = 2,
  }) {
    pw.Alignment alignment;
    switch (align) {
      case PdfCellAlign.center:
        alignment = pw.Alignment.center;
      case PdfCellAlign.right:
        alignment = pw.Alignment.centerRight;
      case PdfCellAlign.left:
        alignment = pw.Alignment.centerLeft;
    }
    return pw.Container(
      height: height ?? FlightPdfTheme.tableRowHeight,
      padding: FlightPdfTheme.cellPadding,
      alignment: alignment,
      child: pw.Text(text, style: style, maxLines: maxLines),
    );
  }
}

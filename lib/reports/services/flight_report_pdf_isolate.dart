import 'dart:isolate';
import 'dart:typed_data';

import '../../models/flight_log.dart';
import '../domain/report_date_range.dart';
import 'flight_pdf_export_service.dart';
import 'flight_report_service.dart';

class _PdfBuildPayload {
  const _PdfBuildPayload({
    required this.logsJson,
    required this.kind,
    required this.startMs,
    required this.endMs,
    required this.generatedAtMs,
  });

  final List<Map<String, dynamic>> logsJson;
  final ReportPeriodKind kind;
  final int startMs;
  final int endMs;
  final int generatedAtMs;
}

/// Builds the flight report PDF off the UI isolate to avoid jank/ANR.
Future<Uint8List> generateFlightReportPdfInBackground({
  required List<FlightLog> allLogs,
  required ReportDateRange range,
  DateTime? generatedAt,
}) async {
  final payload = _PdfBuildPayload(
    logsJson: allLogs.map((log) => log.toJson()).toList(),
    kind: range.kind,
    startMs: range.start.millisecondsSinceEpoch,
    endMs: range.end.millisecondsSinceEpoch,
    generatedAtMs: (generatedAt ?? DateTime.now()).millisecondsSinceEpoch,
  );
  return Isolate.run(() async => _generatePdfBytes(payload));
}

Future<Uint8List> _generatePdfBytes(_PdfBuildPayload payload) async {
  const reportService = FlightReportService();
  const pdfService = FlightPdfExportService();

  final logs = payload.logsJson.map(FlightLog.fromJson).toList();
  final range = ReportDateRange(
    kind: payload.kind,
    start: DateTime.fromMillisecondsSinceEpoch(payload.startMs),
    end: DateTime.fromMillisecondsSinceEpoch(payload.endMs),
  );
  final generatedAt =
      DateTime.fromMillisecondsSinceEpoch(payload.generatedAtMs);

  final inRange = reportService.filterByDateRange(logs, range);
  final summary = reportService.buildSummary(inRange, range);

  return pdfService.generate(
    FlightPdfExportInput(
      range: range,
      summary: summary,
      logs: inRange,
      flightTypes: reportService.buildFlightTypeBreakdown(inRange),
      pilotRoles: reportService.buildPilotRoleBreakdown(inRange),
      conditions: reportService.buildFlightConditionBreakdown(inRange),
      modes: reportService.buildFlightModeBreakdown(inRange),
      aircraft: reportService.buildAircraftBreakdown(inRange),
      trends: reportService.buildTrendBuckets(inRange, range),
      generatedAt: generatedAt,
    ),
  );
}

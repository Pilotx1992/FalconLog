import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/flight_log.dart';
import '../domain/report_date_range.dart';
import 'flight_report_export_outcome.dart';
import 'flight_report_pdf_isolate.dart';

class FlightReportExportCoordinator {
  FlightReportExportCoordinator();

  Future<Uint8List> buildPdfBytes({
    required List<FlightLog> allLogs,
    required ReportDateRange range,
  }) {
    return generateFlightReportPdfInBackground(
      allLogs: allLogs,
      range: range,
    );
  }

  String fileNameFor(ReportDateRange range) {
    final stamp = DateTime.now();
    final d =
        '${stamp.year}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}';
    final kind = switch (range.kind) {
      ReportPeriodKind.allTime => 'AllTime',
      ReportPeriodKind.thisMonth => 'ThisMonth',
      ReportPeriodKind.thisYear => 'ThisYear',
      ReportPeriodKind.custom => 'Custom',
    };
    return 'FalconLog_${kind}_Report_$d.pdf';
  }

  Future<FlightReportExportOutcome> sharePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      final result = await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        subject: 'FalconLog Flight Report',
      );
      if (result.status == ShareResultStatus.dismissed) {
        return const FlightReportExportOutcome.cancelled();
      }
      return const FlightReportExportOutcome.success();
    } catch (e) {
      return FlightReportExportOutcome.failure('Share failed: $e');
    }
  }

  Future<FlightReportExportOutcome> savePdf({
    required Uint8List bytes,
    required String fileName,
    required FlightReportSaveFile saveFile,
  }) async {
    try {
      final path = await saveFile(fileName: fileName, bytes: bytes);
      if (path == null) {
        return const FlightReportExportOutcome.cancelled();
      }
      return FlightReportExportOutcome.success(path);
    } catch (e) {
      return FlightReportExportOutcome.failure('Save failed: $e');
    }
  }
}

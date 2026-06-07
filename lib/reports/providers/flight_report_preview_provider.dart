import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/flight_log.dart';
import '../../providers/flight_logs_provider.dart';
import '../domain/flight_report_summary.dart';
import '../domain/report_date_range.dart';
import '../services/flight_report_service.dart';

final flightReportServiceProvider = Provider<FlightReportService>(
  (ref) => const FlightReportService(),
);

class FlightReportPreviewParams {
  const FlightReportPreviewParams({required this.range});

  final ReportDateRange range;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightReportPreviewParams &&
          other.range.kind == range.kind &&
          other.range.start == range.start &&
          other.range.end == range.end;

  @override
  int get hashCode => Object.hash(range.kind, range.start, range.end);
}

class FlightReportPreviewData {
  const FlightReportPreviewData({required this.summary});

  final FlightReportSummary? summary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightReportPreviewData &&
          other.summary == summary;

  @override
  int get hashCode => summary.hashCode;
}

final flightReportPreviewProvider =
    Provider.family<FlightReportPreviewData?, FlightReportPreviewParams>(
  (ref, params) {
    final logsAsync = ref.watch(flightLogsProvider);
    return logsAsync.when(
      data: (logs) {
        final service = ref.watch(flightReportServiceProvider);
        final inRange = service.filterByDateRange(logs, params.range);
        return FlightReportPreviewData(
          summary: service.buildSummary(inRange, params.range),
        );
      },
      loading: () => null,
      error: (_, __) => null,
    );
  },
);

List<FlightLog> flightLogsFromRef(WidgetRef ref) {
  return ref.watch(flightLogsProvider).maybeWhen(
        data: (l) => l,
        orElse: () => [],
      );
}

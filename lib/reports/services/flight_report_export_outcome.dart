enum FlightReportExportStatus { success, cancelled, failure }

class FlightReportExportOutcome {
  const FlightReportExportOutcome._({
    required this.status,
    this.savedPath,
    this.errorMessage,
  });

  const FlightReportExportOutcome.success([String? savedPath])
      : this._(status: FlightReportExportStatus.success, savedPath: savedPath);

  const FlightReportExportOutcome.cancelled()
      : this._(status: FlightReportExportStatus.cancelled);

  const FlightReportExportOutcome.failure(String message)
      : this._(
          status: FlightReportExportStatus.failure,
          errorMessage: message,
        );

  final FlightReportExportStatus status;
  final String? savedPath;
  final String? errorMessage;

  bool get isSuccess => status == FlightReportExportStatus.success;
  bool get isCancelled => status == FlightReportExportStatus.cancelled;
  bool get isFailure => status == FlightReportExportStatus.failure;
}

typedef FlightReportSaveFile = Future<String?> Function({
  required String fileName,
  required List<int> bytes,
});

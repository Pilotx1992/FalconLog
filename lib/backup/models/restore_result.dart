import 'restore_options.dart';

/// Result of a restore operation
class RestoreResult {
  final bool success;
  final int flightLogsRestored;
  final DateTime? backupDate;
  final String? sourceDevice;
  final String? error;
  final RestoreOptions? options;

  const RestoreResult.success({
    required this.flightLogsRestored,
    this.backupDate,
    this.sourceDevice,
    this.options,
  })  : success = true,
        error = null;

  const RestoreResult.failure({
    required this.error,
    this.flightLogsRestored = 0,
    this.backupDate,
    this.sourceDevice,
    this.options,
  }) : success = false;

  const RestoreResult.error(String errorMessage)
      : success = false,
        error = errorMessage,
        flightLogsRestored = 0,
        backupDate = null,
        sourceDevice = null,
        options = null;

  /// Get formatted summary of restore operation
  String get summary {
    if (success) {
      return 'Successfully restored $flightLogsRestored flight logs';
    } else {
      return 'Restore failed: $error';
    }
  }

  /// Get detailed description
  String get description {
    if (success) {
      final buffer = StringBuffer();
      buffer.writeln('Restore completed successfully!');
      buffer.writeln('Flight logs restored: $flightLogsRestored');

      if (backupDate != null) {
        buffer.writeln('Backup date: ${_formatDate(backupDate!)}');
      }

      if (sourceDevice != null) {
        buffer.writeln('Source device: $sourceDevice');
      }

      if (options != null && options!.useDateFilter) {
        buffer.writeln(
            'Date filter applied: ${_formatDate(options!.startDate!)} to ${_formatDate(options!.endDate!)}');
      }

      return buffer.toString().trim();
    } else {
      return 'Restore failed: $error';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  String toString() {
    return 'RestoreResult(success: $success, flightLogsRestored: $flightLogsRestored, error: $error)';
  }
}

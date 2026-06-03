/// Result of a backup operation
class BackupResult {
  final bool success;
  final String message;
  final int? logsCount;
  final int? backupSize;
  final String? filePath;
  final String? error;

  const BackupResult.success({
    required this.message,
    this.logsCount,
    this.backupSize,
    this.filePath,
  })  : success = true,
        error = null;

  const BackupResult.error(String errorMessage)
      : success = false,
        message = '',
        error = errorMessage,
        logsCount = null,
        backupSize = null,
        filePath = null;

  /// Get formatted summary of backup operation
  String get summary {
    if (success) {
      return message;
    } else {
      return 'Backup failed: $error';
    }
  }

  @override
  String toString() {
    return 'BackupResult(success: $success, message: $message, logsCount: $logsCount, error: $error)';
  }
}

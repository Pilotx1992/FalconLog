import 'package:logging/logging.dart';

import '../../core/exceptions/backup_exceptions.dart';
import 'backup_constants.dart';

/// Enhanced error handler for backup operations
class BackupErrorHandler {
  static final _logger = Logger('BackupErrorHandler');

  /// Handle backup errors and return user-friendly messages
  static String handleBackupError(dynamic error, {String? context}) {
    try {
      _logger.warning('Backup error in $context: $error');

      if (error is BackupException) {
        return _handleBackupException(error);
      } else if (error is CloudAuthenticationException) {
        return 'Google Drive authentication failed. Please sign in again.';
      } else if (error is CloudUploadException) {
        return 'Failed to upload backup to Google Drive. Please check your internet connection.';
      } else if (error is CloudDownloadException) {
        return 'Failed to download backup from Google Drive. Please check your internet connection.';
      } else if (error is EncryptionException) {
        return 'Encryption failed. Please try again.';
      } else if (error is DecryptionException) {
        return 'Decryption failed. The backup may be corrupted.';
      } else if (error is ValidationException) {
        return 'Backup validation failed: ${error.errors.join(', ')}';
      } else if (error is StorageException) {
        return 'Storage error: ${error.message}';
      } else if (error is DiskFullException) {
        return 'Not enough storage space. Please free up some space and try again.';
      } else if (error is PermissionDeniedException) {
        return 'Permission denied. Please check app permissions.';
      } else if (error is OperationCancelledException) {
        return 'Operation was cancelled.';
      } else {
        // Generic error handling
        final errorString = error.toString().toLowerCase();

        if (errorString.contains('network') || errorString.contains('connection')) {
          return 'Network error. Please check your internet connection.';
        } else if (errorString.contains('timeout')) {
          return 'Operation timed out. Please try again.';
        } else if (errorString.contains('permission')) {
          return 'Permission denied. Please check app permissions.';
        } else if (errorString.contains('storage') || errorString.contains('disk')) {
          return 'Storage error. Please free up some space and try again.';
        } else if (errorString.contains('authentication') || errorString.contains('auth')) {
          return 'Authentication failed. Please sign in again.';
        } else {
          return 'An unexpected error occurred. Please try again.';
        }
      }
    } catch (e, stackTrace) {
      _logger.severe('Error in error handler', e, stackTrace);
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Handle specific backup exceptions
  static String _handleBackupException(BackupException exception) {
    switch (exception) {
      case BackupCreationException _:
        return 'Failed to create backup. Please try again.';
      case BackupVerificationException _:
        return 'Backup verification failed. The backup may be corrupted.';
      case BackupNotFoundException _:
        return 'Backup not found. It may have been deleted.';
      case BackupCorruptedException _:
        return 'Backup is corrupted and cannot be restored.';
      case RestoreException _:
        return 'Failed to restore backup. Please try again.';
      case SyncException _:
        return 'Cloud sync failed. Please check your internet connection.';
      default:
        return exception.message;
    }
  }

  /// Get error code for specific error types
  static int? getErrorCode(dynamic error) {
    if (error is BackupException) {
      return error.errorCode;
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return BackupConstants.errorCodes['NETWORK_ERROR'];
    } else if (errorString.contains('authentication') || errorString.contains('auth')) {
      return BackupConstants.errorCodes['AUTHENTICATION_FAILED'];
    } else if (errorString.contains('storage') || errorString.contains('disk')) {
      return BackupConstants.errorCodes['DISK_FULL'];
    } else if (errorString.contains('permission')) {
      return BackupConstants.errorCodes['PERMISSION_DENIED'];
    }

    return null;
  }

  /// Check if error is recoverable
  static bool isRecoverableError(dynamic error) {
    if (error is BackupException) {
      return error.errorCode != BackupConstants.errorCodes['CORRUPTED_DATA'];
    }

    final errorString = error.toString().toLowerCase();

    // Non-recoverable errors
    if (errorString.contains('corrupted') ||
        errorString.contains('invalid') ||
        errorString.contains('malformed')) {
      return false;
    }

    // Recoverable errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('authentication') ||
        errorString.contains('permission')) {
      return true;
    }

    return true; // Default to recoverable
  }

  /// Get suggested action for error
  static String getSuggestedAction(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Check your internet connection and try again.';
    } else if (errorString.contains('authentication') || errorString.contains('auth')) {
      return 'Sign in to Google Drive again.';
    } else if (errorString.contains('storage') || errorString.contains('disk')) {
      return 'Free up storage space and try again.';
    } else if (errorString.contains('permission')) {
      return 'Grant necessary permissions to the app.';
    } else if (errorString.contains('timeout')) {
      return 'Try again with a better internet connection.';
    } else if (errorString.contains('corrupted')) {
      return 'Try restoring from a different backup.';
    } else {
      return 'Please try again or contact support if the problem persists.';
    }
  }

  /// Create error report for debugging
  static Map<String, dynamic> createErrorReport(dynamic error, {String? context}) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'context': context ?? 'Unknown',
      'error_type': error.runtimeType.toString(),
      'error_message': error.toString(),
      'error_code': getErrorCode(error),
      'is_recoverable': isRecoverableError(error),
      'suggested_action': getSuggestedAction(error),
      'user_friendly_message': handleBackupError(error, context: context),
    };
  }

  /// Log error with appropriate level
  static void logError(dynamic error, {String? context, StackTrace? stackTrace}) {
    if (error is BackupException) {
      if (error.errorCode == BackupConstants.errorCodes['CORRUPTED_DATA']) {
        _logger.severe('Critical backup error in $context: $error', error, stackTrace);
      } else {
        _logger.warning('Backup error in $context: $error', error, stackTrace);
      }
    } else {
      _logger.warning('General error in $context: $error', error, stackTrace);
    }
  }

  /// Handle and log error in one call
  static String handleAndLogError(dynamic error, {String? context, StackTrace? stackTrace}) {
    logError(error, context: context, stackTrace: stackTrace);
    return handleBackupError(error, context: context);
  }
}

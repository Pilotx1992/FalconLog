import '../auth/auth_error_mapper.dart';
import '../services/navigation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum NotificationType {
  success,
  error,
  info,
  warning,
}

class NotificationService {
  // Show success message
  static void showSuccess(String message) {
    NavigationService.showSnackBar(message, isError: false);
  }

  // Show error message
  static void showError(String message) {
    NavigationService.showSnackBar(message, isError: true);
  }

  // Show warning message
  static void showWarning(String message) {
    NavigationService.showSnackBar(message, isError: false);
  }

  // Show info message
  static void showInfo(String message) {
    NavigationService.showSnackBar(message, isError: false);
  }

  // Show authentication success
  static void showAuthSuccess(String action) {
    showSuccess('$action successful!');
  }

  // Show authentication error ([error] is a Firebase code or user message).
  static void showAuthError(String action, String error) {
    final mapped = mapFirebaseAuthException(
      FirebaseAuthException(code: error, message: null),
    );
    final detail =
        mapped == 'Authentication failed. Please try again.' ? error : mapped;
    showError('Failed to $action: $detail');
  }

  // Show validation error
  static void showValidationError(String field) {
    showError('Enter valid $field.');
  }

  // Show flight log notifications
  static void showFlightLogSaved() {
    showSuccess('Flight saved!');
  }

  static void showFlightLogUpdated() {
    showSuccess('Flight updated!');
  }

  static void showFlightLogDeleted() {
    showSuccess('Flight deleted!');
  }

  // Show currency alerts
  static void showCurrencyAlert(String type, int daysRemaining) {
    if (daysRemaining <= 0) {
      showError('$type currency expired! Log flight to renew.');
    } else if (daysRemaining <= 7) {
      showInfo('$type currency expires in $daysRemaining days.');
    }
  }

  // Show email verification reminders
  static void showEmailVerificationReminder() {
    showInfo('Verify email to access all features.');
  }

  static void showEmailVerificationSent() {
    showSuccess('Verification email sent!');
  }

  // Show backup/sync notifications
  static void showBackupSuccess() {
    showSuccess('Data backed up!');
  }

  static void showSyncSuccess() {
    showSuccess('Data synced!');
  }

  static void showBackupError() {
    showError('Backup failed. Try again.');
  }

  // Show settings changes
  static void showSettingsSaved() {
    showSuccess('Settings saved!');
  }

  // Show import/export notifications
  static void showDataExported() {
    showSuccess('Data exported!');
  }

  static void showDataImported(int count) {
    showSuccess('$count flights imported!');
  }

  // Show permission requests
  static void showPermissionDenied(String permission) {
    showError('$permission permission required.');
  }

  // Show maintenance notifications
  static void showMaintenanceMode() {
    showInfo('Under maintenance. Some features unavailable.');
  }

  // Show update notifications
  static void showUpdateAvailable() {
    showInfo('Update available!');
  }

  // Show connection status
  static void showConnectionLost() {
    showError('Connection lost.');
  }

  static void showConnectionRestored() {
    showSuccess('Connected!');
  }

  // Show backup notifications
  static Future<void> showBackupNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.success,
  }) async {
    switch (type) {
      case NotificationType.success:
        showSuccess('$title: $body');
        break;
      case NotificationType.error:
        showError('$title: $body');
        break;
      case NotificationType.info:
        showInfo('$title: $body');
        break;
      case NotificationType.warning:
        showInfo('$title: $body');
        break;
    }
  }
}

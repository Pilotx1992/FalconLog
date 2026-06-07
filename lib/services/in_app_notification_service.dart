import '../auth/auth_error_mapper.dart';
import '../services/navigation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum NotificationType {
  success,
  error,
  info,
  warning,
}

/// In-app SnackBar messages (not system notifications).
class InAppNotificationService {
  static void showSuccess(String message) {
    NavigationService.showSnackBar(message, isError: false);
  }

  static void showError(String message) {
    NavigationService.showSnackBar(message, isError: true);
  }

  static void showWarning(String message) {
    NavigationService.showSnackBar(message, isError: false);
  }

  static void showInfo(String message) {
    NavigationService.showSnackBar(message, isError: false);
  }

  static void showAuthSuccess(String action) {
    showSuccess('$action successful!');
  }

  static void showAuthError(String action, String error) {
    final mapped = mapFirebaseAuthException(
      FirebaseAuthException(code: error, message: null),
    );
    final detail =
        mapped == 'Authentication failed. Please try again.' ? error : mapped;
    showError('Failed to $action: $detail');
  }

  static void showValidationError(String field) {
    showError('Enter valid $field.');
  }

  static void showFlightLogSaved() {
    showSuccess('Flight saved!');
  }

  static void showFlightLogUpdated() {
    showSuccess('Flight updated!');
  }

  static void showFlightLogDeleted() {
    showSuccess('Flight deleted!');
  }

  static void showCurrencyAlert(String type, int daysRemaining) {
    if (daysRemaining <= 0) {
      showError('$type currency expired! Log flight to renew.');
    } else if (daysRemaining <= 7) {
      showInfo('$type currency expires in $daysRemaining days.');
    }
  }

  static void showEmailVerificationReminder() {
    showInfo('Verify email to access all features.');
  }

  static void showEmailVerificationSent() {
    showSuccess('Verification email sent!');
  }

  static void showBackupSuccess() {
    showSuccess('Data backed up!');
  }

  static void showSyncSuccess() {
    showSuccess('Data synced!');
  }

  static void showBackupError() {
    showError('Backup failed. Try again.');
  }

  static void showSettingsSaved() {
    showSuccess('Settings saved!');
  }

  static void showDataExported() {
    showSuccess('Data exported!');
  }

  static void showDataImported(int count) {
    showSuccess('$count flights imported!');
  }

  static void showPermissionDenied(String permission) {
    showError('$permission permission required.');
  }

  static void showMaintenanceMode() {
    showInfo('Under maintenance. Some features unavailable.');
  }

  static void showUpdateAvailable() {
    showInfo('Update available!');
  }

  static void showConnectionLost() {
    showError('Connection lost.');
  }

  static void showConnectionRestored() {
    showSuccess('Connected!');
  }

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

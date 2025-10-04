import '../services/navigation_service.dart';

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

  // Show authentication error
  static void showAuthError(String action, String error) {
    String message = 'Failed to $action: ';

    // Handle common Firebase Auth errors
    if (error.contains('user-not-found')) {
      message += 'Account not found.';
    } else if (error.contains('wrong-password')) {
      message += 'Wrong password.';
    } else if (error.contains('email-already-in-use')) {
      message += 'Email already exists.';
    } else if (error.contains('weak-password')) {
      message += 'Password too weak.';
    } else if (error.contains('invalid-email')) {
      message += 'Invalid email.';
    } else if (error.contains('user-disabled')) {
      message += 'Account disabled.';
    } else if (error.contains('too-many-requests')) {
      message += 'Too many attempts. Try later.';
    } else if (error.contains('network-request-failed')) {
      message += 'Network error.';
    } else if (error.contains('requires-recent-login')) {
      message += 'Sign in again.';
    } else {
      message += error;
    }

    showError(message);
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


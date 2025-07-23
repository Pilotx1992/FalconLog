import '../services/navigation_service.dart';

class NotificationService {
  // Show success message
  static void showSuccess(String message) {
    NavigationService.showSnackBar(message, isError: false);
  }
  
  // Show error message
  static void showError(String message) {
    NavigationService.showSnackBar(message, isError: true);
  }
  
  // Show info message
  static void showInfo(String message) {
    NavigationService.showSnackBar(message, isError: false);
  }
  
  // Show authentication success
  static void showAuthSuccess(String action) {
    showSuccess('$action successful! Welcome to FalconLog.');
  }
  
  // Show authentication error
  static void showAuthError(String action, String error) {
    String message = 'Failed to $action: ';
    
    // Handle common Firebase Auth errors
    if (error.contains('user-not-found')) {
      message += 'No account found with this email address.';
    } else if (error.contains('wrong-password')) {
      message += 'Incorrect password. Please try again.';
    } else if (error.contains('email-already-in-use')) {
      message += 'An account already exists with this email address.';
    } else if (error.contains('weak-password')) {
      message += 'Password is too weak. Please choose a stronger password.';
    } else if (error.contains('invalid-email')) {
      message += 'Invalid email address format.';
    } else if (error.contains('user-disabled')) {
      message += 'This account has been disabled.';
    } else if (error.contains('too-many-requests')) {
      message += 'Too many failed attempts. Please try again later.';
    } else if (error.contains('network-request-failed')) {
      message += 'Network error. Please check your internet connection.';
    } else if (error.contains('requires-recent-login')) {
      message += 'Please sign in again to continue.';
    } else {
      message += error;
    }
    
    showError(message);
  }
  
  // Show validation error
  static void showValidationError(String field) {
    showError('Please enter a valid $field.');
  }
  
  // Show flight log notifications
  static void showFlightLogSaved() {
    showSuccess('Flight log saved successfully!');
  }
  
  static void showFlightLogUpdated() {
    showSuccess('Flight log updated successfully!');
  }
  
  static void showFlightLogDeleted() {
    showSuccess('Flight log deleted successfully!');
  }
  
  // Show currency alerts
  static void showCurrencyAlert(String type, int daysRemaining) {
    if (daysRemaining <= 0) {
      showError('Your $type currency has expired! Log a flight to renew.');
    } else if (daysRemaining <= 7) {
      showInfo('Your $type currency expires in $daysRemaining days.');
    }
  }
  
  // Show email verification reminders
  static void showEmailVerificationReminder() {
    showInfo('Please verify your email address to access all features.');
  }
  
  static void showEmailVerificationSent() {
    showSuccess('Verification email sent! Please check your inbox.');
  }
  
  // Show backup/sync notifications
  static void showBackupSuccess() {
    showSuccess('Data backed up successfully!');
  }
  
  static void showSyncSuccess() {
    showSuccess('Data synchronized successfully!');
  }
  
  static void showBackupError() {
    showError('Failed to backup data. Please try again.');
  }
  
  // Show settings changes
  static void showSettingsSaved() {
    showSuccess('Settings saved successfully!');
  }
  
  // Show import/export notifications
  static void showDataExported() {
    showSuccess('Flight data exported successfully!');
  }
  
  static void showDataImported(int count) {
    showSuccess('$count flight logs imported successfully!');
  }
  
  // Show permission requests
  static void showPermissionDenied(String permission) {
    showError('$permission permission is required for this feature.');
  }
  
  // Show maintenance notifications
  static void showMaintenanceMode() {
    showInfo('App is under maintenance. Some features may be unavailable.');
  }
  
  // Show update notifications
  static void showUpdateAvailable() {
    showInfo('A new version of FalconLog is available!');
  }
  
  // Show connection status
  static void showConnectionLost() {
    showError('Connection lost. Some features may be unavailable.');
  }
  
  static void showConnectionRestored() {
    showSuccess('Connection restored!');
  }
}

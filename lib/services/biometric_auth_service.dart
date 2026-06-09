import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricSetupKey = 'biometric_setup_complete';

  // Check if biometric authentication is available on device
  static Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking device support: $e');
      return false;
    }
  }

  // Check if biometrics are available and enrolled
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking biometrics availability: $e');
      return false;
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  // Check if user has enrolled biometrics
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking enrolled biometrics: $e');
      return false;
    }
  }

  // Authenticate using biometrics
  static Future<bool> authenticate({
    String reason = 'Authenticate to access FalconLog',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Check if device supports biometrics
      if (!await isDeviceSupported()) {
        throw BiometricException('Device not supported');
      }

      // Check if biometrics are available
      if (!await canCheckBiometrics()) {
        throw BiometricException('Biometrics not available');
      }

      // Check if user has enrolled biometrics
      if (!await hasEnrolledBiometrics()) {
        throw BiometricException('No biometrics enrolled');
      }

      // Perform authentication
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'FalconLog Authentication',
            cancelButton: 'Cancel',
            deviceCredentialsRequiredTitle: 'Credentials required',
            deviceCredentialsSetupDescription: 'Set up device credentials',
            goToSettingsButton: 'Settings',
            goToSettingsDescription: 'Set up biometrics in settings',
          ),
        ],
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: false, // Allow fallback to device credentials
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('Biometric authentication error: ${e.message}');
      throw BiometricException(_getErrorMessage(e.code));
    } catch (e) {
      if (kDebugMode) debugPrint('Unexpected biometric error: $e');
      throw BiometricException('Auth failed');
    }
  }

  // Get user-friendly error message
  static String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'NotAvailable':
        return 'Not available';
      case 'NotEnrolled':
        return 'Not enrolled';
      case 'LockedOut':
        return 'Locked out';
      case 'PermanentlyLockedOut':
        return 'Permanently locked';
      case 'UserCancel':
        return 'Cancelled';
      case 'UserFallback':
        return 'Fallback used';
      case 'SystemCancel':
        return 'System cancelled';
      case 'InvalidContext':
        return 'Invalid context';
      case 'NotSupported':
        return 'Not supported';
      default:
        return 'Failed';
    }
  }

  // Check if biometric authentication is enabled in app settings
  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking biometric enabled status: $e');
      return false;
    }
  }

  // Enable/disable biometric authentication in app settings
  static Future<void> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);

      if (enabled) {
        // Mark setup as complete when enabling
        await prefs.setBool(_biometricSetupKey, true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error setting biometric enabled status: $e');
      throw BiometricException('Failed to save settings');
    }
  }

  // Check if biometric setup is complete
  static Future<bool> isBiometricSetupComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricSetupKey) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking biometric setup status: $e');
      return false;
    }
  }

  // Get biometric type names for display
  static String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return 'Biometric';

    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong)) {
      return 'Biometric';
    } else if (types.contains(BiometricType.weak)) {
      return 'Biometric';
    }

    return 'Biometric';
  }

  // Setup biometric authentication (first time)
  static Future<BiometricSetupResult> setupBiometricAuth() async {
    try {
      // Check device capabilities
      if (!await isDeviceSupported()) {
        return BiometricSetupResult.deviceNotSupported;
      }

      if (!await canCheckBiometrics()) {
        return BiometricSetupResult.biometricsNotAvailable;
      }

      if (!await hasEnrolledBiometrics()) {
        return BiometricSetupResult.noBiometricsEnrolled;
      }

      // Test authentication
      final authenticated = await authenticate(
        reason: 'Enable biometric auth',
      );

      if (authenticated) {
        await setBiometricEnabled(true);
        return BiometricSetupResult.success;
      } else {
        return BiometricSetupResult.authenticationFailed;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Biometric setup error: $e');
      return BiometricSetupResult.error;
    }
  }

  // Disable biometric authentication
  static Future<void> disableBiometricAuth() async {
    try {
      await setBiometricEnabled(false);
    } catch (e) {
      if (kDebugMode) debugPrint('Error disabling biometric auth: $e');
      throw BiometricException('Failed to disable auth');
    }
  }

  // Instance methods for compatibility with backup service
  Future<bool> isBiometricAvailable() async {
    return await canCheckBiometrics() && await hasEnrolledBiometrics();
  }

  Future<String> getBiometricAvailability() async {
    if (!await isDeviceSupported()) {
      return 'Device not supported';
    }
    if (!await canCheckBiometrics()) {
      return 'Biometrics not available';
    }
    if (!await hasEnrolledBiometrics()) {
      return 'No biometrics enrolled';
    }
    return 'Available';
  }
}

// Custom exception for biometric errors
class BiometricException implements Exception {
  final String message;

  const BiometricException(this.message);

  @override
  String toString() => 'BiometricException: $message';
}

// Enum for setup results
enum BiometricSetupResult {
  success,
  deviceNotSupported,
  biometricsNotAvailable,
  noBiometricsEnrolled,
  authenticationFailed,
  error,
}

// Extension for user-friendly messages
extension BiometricSetupResultMessages on BiometricSetupResult {
  String get message {
    switch (this) {
      case BiometricSetupResult.success:
        return 'Enabled Successfully';
      case BiometricSetupResult.deviceNotSupported:
        return 'Not supported';
      case BiometricSetupResult.biometricsNotAvailable:
        return 'Unavailable';
      case BiometricSetupResult.noBiometricsEnrolled:
        return 'None enrolled';
      case BiometricSetupResult.authenticationFailed:
        return 'Failed';
      case BiometricSetupResult.error:
        return 'Error';
    }
  }
}

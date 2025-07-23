import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricSetupKey = 'biometric_setup_complete';

  // Check if biometric authentication is available on device
  static Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('Error checking device support: $e');
      return false;
    }
  }

  // Check if biometrics are available and enrolled
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Error checking biometrics availability: $e');
      return false;
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  // Check if user has enrolled biometrics
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking enrolled biometrics: $e');
      return false;
    }
  }

  // Authenticate using biometrics
  static Future<bool> authenticate({
    String reason = 'Please authenticate to access FalconLog',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Check if device supports biometrics
      if (!await isDeviceSupported()) {
        throw BiometricException('Device does not support biometric authentication');
      }

      // Check if biometrics are available
      if (!await canCheckBiometrics()) {
        throw BiometricException('Biometric authentication is not available');
      }

      // Check if user has enrolled biometrics
      if (!await hasEnrolledBiometrics()) {
        throw BiometricException('No biometrics enrolled on this device');
      }

      // Perform authentication
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'FalconLog Authentication',
            cancelButton: 'Cancel',
            deviceCredentialsRequiredTitle: 'Device credentials required',
            deviceCredentialsSetupDescription: 'Please set up device credentials',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription: 'Please set up biometric authentication in settings',
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
      debugPrint('Biometric authentication error: ${e.message}');
      throw BiometricException(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('Unexpected biometric error: $e');
      throw BiometricException('Biometric authentication failed: $e');
    }
  }

  // Get user-friendly error message
  static String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device';
      case 'NotEnrolled':
        return 'No biometrics are enrolled on this device';
      case 'LockedOut':
        return 'Biometric authentication is locked out. Please try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is permanently locked out';
      case 'UserCancel':
        return 'Authentication was cancelled by user';
      case 'UserFallback':
        return 'User chose to use fallback authentication';
      case 'SystemCancel':
        return 'Authentication was cancelled by system';
      case 'InvalidContext':
        return 'Authentication context is invalid';
      case 'NotSupported':
        return 'Biometric authentication is not supported';
      default:
        return 'Biometric authentication failed';
    }
  }

  // Check if biometric authentication is enabled in app settings
  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      debugPrint('Error checking biometric enabled status: $e');
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
      debugPrint('Error setting biometric enabled status: $e');
      throw BiometricException('Failed to save biometric settings');
    }
  }

  // Check if biometric setup is complete
  static Future<bool> isBiometricSetupComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricSetupKey) ?? false;
    } catch (e) {
      debugPrint('Error checking biometric setup status: $e');
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
        reason: 'Enable biometric authentication for FalconLog',
      );

      if (authenticated) {
        await setBiometricEnabled(true);
        return BiometricSetupResult.success;
      } else {
        return BiometricSetupResult.authenticationFailed;
      }
    } catch (e) {
      debugPrint('Biometric setup error: $e');
      return BiometricSetupResult.error;
    }
  }

  // Disable biometric authentication
  static Future<void> disableBiometricAuth() async {
    try {
      await setBiometricEnabled(false);
    } catch (e) {
      debugPrint('Error disabling biometric auth: $e');
      throw BiometricException('Failed to disable biometric authentication');
    }
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
        return 'Biometric authentication enabled successfully!';
      case BiometricSetupResult.deviceNotSupported:
        return 'Your device does not support biometric authentication';
      case BiometricSetupResult.biometricsNotAvailable:
        return 'Biometric authentication is not available on this device';
      case BiometricSetupResult.noBiometricsEnrolled:
        return 'Please enroll fingerprint or face ID in device settings first';
      case BiometricSetupResult.authenticationFailed:
        return 'Biometric authentication failed. Please try again';
      case BiometricSetupResult.error:
        return 'An error occurred while setting up biometric authentication';
    }
  }

  bool get isSuccess => this == BiometricSetupResult.success;
}

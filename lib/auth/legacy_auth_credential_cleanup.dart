import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys that must never store raw Firebase passwords.
class LegacyAuthCredentialKeys {
  LegacyAuthCredentialKeys._();

  static const String biometricEmail = 'biometric_email';
  static const String biometricPassword = 'biometric_password';

  /// All legacy plaintext credential keys to purge on startup/auth init.
  static const List<String> unsafePlaintextCredentialKeys = [
    biometricEmail,
    biometricPassword,
    'saved_password',
    'firebase_password',
    'user_password',
  ];
}

/// Removes unsafe legacy auth secrets from SharedPreferences.
///
/// Safe to call repeatedly. Does not sign the user out of Firebase, clear PIN
/// secrets, backup keys, or flight log data.
class LegacyAuthCredentialCleanup {
  LegacyAuthCredentialCleanup._();

  static Future<SharedPreferences> Function() prefsProvider =
      SharedPreferences.getInstance;

  /// Removes legacy plaintext credential keys if present.
  static Future<void> removeUnsafePlaintextCredentials() async {
    final prefs = await prefsProvider();
    for (final key in LegacyAuthCredentialKeys.unsafePlaintextCredentialKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }
  }
}

/// Shown when Firebase biometric login cannot proceed without unsafe storage.
const String kBiometricLoginRequiresSignInMessage =
    'For your security, please sign in again with your email and password.';

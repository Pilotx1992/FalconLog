import 'dart:io';

import 'package:falconlog/auth/legacy_auth_credential_cleanup.dart';
import 'package:falconlog/backup/utils/app_settings_backup.dart';
import 'package:falconlog/security/services/security_service.dart';
import 'package:falconlog/services/enhanced_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_security_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final enhancedAuthSource = File(
    'lib/services/enhanced_auth_service.dart',
  ).readAsStringSync();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LegacyAuthCredentialCleanup.prefsProvider = SharedPreferences.getInstance;
    EnhancedAuthService.resetLegacyCleanupForTesting();
  });

  tearDown(() {
    LegacyAuthCredentialCleanup.prefsProvider = SharedPreferences.getInstance;
  });

  group('Legacy credential cleanup', () {
    test('legacy_plaintext_biometric_password_is_removed', () async {
      SharedPreferences.setMockInitialValues({
        LegacyAuthCredentialKeys.biometricEmail: 'old@example.com',
        LegacyAuthCredentialKeys.biometricPassword: 'plaintext-secret',
        'saved_password': 'also-secret',
        'selected_language': 'en',
        'biometric_enabled': true,
      });

      await LegacyAuthCredentialCleanup.removeUnsafePlaintextCredentials();

      final prefs = await SharedPreferences.getInstance();
      for (final key
          in LegacyAuthCredentialKeys.unsafePlaintextCredentialKeys) {
        expect(prefs.containsKey(key), isFalse);
      }
      expect(prefs.getString('selected_language'), 'en');
      expect(prefs.getBool('biometric_enabled'), isTrue);
    });
  });

  group('EnhancedAuthService source contract', () {
    test('biometric_login_does_not_store_plaintext_password', () {
      expect(enhancedAuthSource.contains('_saveBiometricCredentials'), isFalse);
      expect(
        enhancedAuthSource.contains("setString('biometric_password'"),
        isFalse,
      );
      expect(
        enhancedAuthSource.contains('setString("biometric_password"'),
        isFalse,
      );
      expect(
        enhancedAuthSource.contains('getString(\'biometric_password\')'),
        isFalse,
      );
      expect(enhancedAuthSource.contains('password: savedPassword'), isFalse);
      expect(enhancedAuthSource.contains('savedPassword'), isFalse);
    });

    test('unsafe_biometric_firebase_relogin_requires_normal_login_message', () {
      expect(
        enhancedAuthSource.contains('kBiometricLoginRequiresSignInMessage'),
        isTrue,
      );
      expect(
        enhancedAuthSource.contains('_firebaseAuth.currentUser != null'),
        isTrue,
      );
    });
  });

  group('App lock isolation', () {
    test('local_app_lock_biometric_is_not_broken', () async {
      SharedPreferences.setMockInitialValues({
        LegacyAuthCredentialKeys.biometricPassword: 'legacy',
        'biometric_enabled': true,
      });

      final repository = FakeSecurityRepository();
      final service = SecurityService(repository);
      await service.initialize();

      expect(service.isPinEnabled, isFalse);
      expect(service.settings.isAppLockBiometricEnabled, isFalse);

      await LegacyAuthCredentialCleanup.removeUnsafePlaintextCredentials();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(LegacyAuthCredentialKeys.biometricPassword),
        isFalse,
      );
    });
  });

  group('Backup settings export', () {
    test('backup_payload_does_not_include_plaintext_password', () async {
      SharedPreferences.setMockInitialValues({
        LegacyAuthCredentialKeys.biometricPassword: 'must-not-export',
        LegacyAuthCredentialKeys.biometricEmail: 'user@example.com',
        'selected_language': 'en',
      });

      final prefs = await SharedPreferences.getInstance();
      final bundle = await AppSettingsBackup.exportFromPrefs(prefs);
      final values = bundle['values'] as Map<String, dynamic>;

      expect(
        values.containsKey(LegacyAuthCredentialKeys.biometricPassword),
        isFalse,
      );
      expect(
        values.containsKey(LegacyAuthCredentialKeys.biometricEmail),
        isFalse,
      );
      expect(values['selected_language'], 'en');
    });

    test('excludedFromBackupKeys_contains_legacy_password_keys', () {
      for (final key
          in LegacyAuthCredentialKeys.unsafePlaintextCredentialKeys) {
        expect(AppSettingsBackup.excludedFromBackupKeys.contains(key), isTrue);
      }
    });
  });

  group('Auth messages', () {
    test('biometric_requires_sign_in_message_is_user_safe', () {
      expect(kBiometricLoginRequiresSignInMessage, contains('sign in again'));
      expect(
        kBiometricLoginRequiresSignInMessage,
        contains('email and password'),
      );
    });
  });
}

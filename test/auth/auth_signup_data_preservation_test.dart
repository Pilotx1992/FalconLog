import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/auth/auth_signup_guard.dart';

void main() {
  group('signup guard messages', () {
    test('Google block message has no password-link promise', () {
      expect(
          kGoogleAccountExistsSignupMessage, contains('sign in with Google'));
      expect(kGoogleAccountExistsSignupMessage,
          isNot(contains('Account Settings')));
      expect(
          kGoogleAccountExistsSignupMessage, isNot(contains('add password')));
    });
  });

  group('register screen isolation from backup/Hive', () {
    test('register_screen does not import backup or flight log persistence',
        () {
      final source =
          File('lib/screens/register_screen.dart').readAsStringSync();
      expect(source.contains("import '../backup/"), isFalse);
      expect(source.contains('flight_logs'), isFalse);
      expect(source.contains('Hive'), isFalse);
      expect(source.contains('openBox'), isFalse);
    });

    test('auth_provider register path does not import backup services', () {
      final source =
          File('lib/providers/auth_provider.dart').readAsStringSync();
      expect(source.contains('backup_service'), isFalse);
      expect(source.contains('key_manager'), isFalse);
      expect(source.contains('Hive'), isFalse);
    });
  });

  group('failed signup guard does not imply side effects', () {
    test('google-only signup block returns before Firebase create-user',
        () async {
      final decision = await checkPasswordSignupAllowed(
        'user@gmail.com',
        fetchSignInMethods: (_) async => ['google.com'],
      );
      expect(decision.allowSignup, isFalse);
      // Caller must not invoke createUserWithEmailAndPassword when blocked.
    });
  });
}

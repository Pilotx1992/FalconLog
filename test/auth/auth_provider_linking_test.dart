import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/auth/auth_error_mapper.dart';
import 'package:falconlog/auth/auth_signup_guard.dart';

FirebaseAuthException _e(String code) =>
    FirebaseAuthException(code: code, message: 'raw');

void main() {
  group('register guard policy (no Firebase required)', () {
    test('google method blocks signup with Google-specific message', () async {
      final decision = await checkPasswordSignupAllowed(
        'user@gmail.com',
        fetchSignInMethods: (_) async => ['google.com'],
      );
      expect(decision.allowSignup, isFalse);
      expect(decision.blockMessage, kGoogleAccountExistsSignupMessage);
    });

    test('password method blocks signup with already-exists message', () async {
      final decision = await checkPasswordSignupAllowed(
        'user@example.com',
        fetchSignInMethods: (_) async => ['password'],
      );
      expect(decision.allowSignup, isFalse);
      expect(decision.blockMessage, kPasswordAccountExistsSignupMessage);
    });

    test('empty methods allow signup to proceed to Firebase', () async {
      final decision = await checkPasswordSignupAllowed(
        'new@example.com',
        fetchSignInMethods: (_) async => [],
      );
      expect(decision.allowSignup, isTrue);
    });

    test('null fetch does not block (firebase_auth 6 production path)', () async {
      final decision = await checkPasswordSignupAllowed(
        'user@example.com',
        fetchSignInMethods: (_) async => null,
      );
      expect(decision.allowSignup, isTrue);
    });
  });

  group('provider linking error mapping', () {
    test('email-already-in-use maps safely', () {
      expect(
        mapFirebaseAuthException(_e('email-already-in-use')),
        'An account already exists with this email.',
      );
    });

    test('account-exists-with-different-credential maps safely', () {
      expect(
        mapFirebaseAuthException(_e('account-exists-with-different-credential')),
        'This email is already registered with another sign-in method.',
      );
    });

    test('provider-already-linked maps safely', () {
      expect(
        mapFirebaseAuthException(_e('provider-already-linked')),
        'This sign-in method is already linked to another account.',
      );
    });

    test('credential-already-in-use maps safely', () {
      expect(
        mapFirebaseAuthException(_e('credential-already-in-use')),
        'This sign-in method is already linked to another account.',
      );
    });
  });

}

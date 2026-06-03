import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/auth/auth_signup_guard.dart';

void main() {
  group('evaluateSignInMethodsForPasswordSignup', () {
    test('no methods allows signup', () {
      final decision = evaluateSignInMethodsForPasswordSignup([]);
      expect(decision.allowSignup, isTrue);
    });

    test('google.com without password blocks with Google message', () {
      final decision = evaluateSignInMethodsForPasswordSignup(['google.com']);
      expect(decision.allowSignup, isFalse);
      expect(
        decision.blockMessage,
        'This email is already registered with Google. Please sign in with Google.',
      );
      expect(decision.blockMessage, isNot(contains('Account Settings')));
      expect(decision.blockMessage, isNot(contains('add password')));
    });

    test('password method blocks with login message', () {
      final decision = evaluateSignInMethodsForPasswordSignup(['password']);
      expect(decision.allowSignup, isFalse);
      expect(decision.blockMessage, kPasswordAccountExistsSignupMessage);
    });

    test('google and password blocks with login message', () {
      final decision = evaluateSignInMethodsForPasswordSignup(
        ['google.com', 'password'],
      );
      expect(decision.allowSignup, isFalse);
      expect(decision.blockMessage, kPasswordAccountExistsSignupMessage);
    });

    test('other provider blocks with generic provider message', () {
      final decision = evaluateSignInMethodsForPasswordSignup(['apple.com']);
      expect(decision.allowSignup, isFalse);
      expect(decision.blockMessage, kOtherProviderSignupMessage);
    });
  });

  group('checkPasswordSignupAllowed', () {
    test('null fetch defers to Firebase create-user', () async {
      final decision = await checkPasswordSignupAllowed(
        'user@example.com',
        fetchSignInMethods: (_) async => null,
      );
      expect(decision.allowSignup, isTrue);
    });

    test('google methods block before create-user', () async {
      final decision = await checkPasswordSignupAllowed(
        'user@example.com',
        fetchSignInMethods: (_) async => ['google.com'],
      );
      expect(decision.allowSignup, isFalse);
      expect(decision.blockMessage, contains('Google'));
    });
  });
}

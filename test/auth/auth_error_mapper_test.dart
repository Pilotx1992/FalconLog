import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/auth/auth_error_mapper.dart';
import 'package:falconlog/auth/auth_exception.dart';

FirebaseAuthException _e(String code) =>
    FirebaseAuthException(code: code, message: 'raw');

void main() {
  group('mapFirebaseAuthException', () {
    test('invalid-email', () {
      expect(
        mapFirebaseAuthException(_e('invalid-email')),
        'Please enter a valid email address.',
      );
    });

    test('login credential errors are generic', () {
      for (final code in [
        'user-not-found',
        'wrong-password',
        'invalid-credential'
      ]) {
        expect(
          mapFirebaseAuthException(_e(code)),
          'Invalid email or password.',
        );
      }
    });

    test('email-already-in-use', () {
      expect(
        mapFirebaseAuthException(_e('email-already-in-use')),
        'An account already exists with this email.',
      );
    });

    test('weak-password', () {
      expect(
        mapFirebaseAuthException(_e('weak-password')),
        'Password is too weak. Use at least 6 characters.',
      );
    });

    test('network-request-failed', () {
      expect(
        mapFirebaseAuthException(_e('network-request-failed')),
        'No internet connection. Please try again.',
      );
    });

    test('too-many-requests', () {
      expect(
        mapFirebaseAuthException(_e('too-many-requests')),
        'Too many attempts. Please try again later.',
      );
    });

    test('user-disabled', () {
      expect(
        mapFirebaseAuthException(_e('user-disabled')),
        'This account has been disabled.',
      );
    });

    test('operation-not-allowed', () {
      expect(
        mapFirebaseAuthException(_e('operation-not-allowed')),
        contains('not enabled'),
      );
    });

    test('unknown code uses safe fallback', () {
      expect(
        mapFirebaseAuthException(_e('internal-error')),
        'Authentication failed. Please try again.',
      );
    });
  });

  group('authErrorMessage', () {
    test('AuthException returns safe message', () {
      expect(
        authErrorMessage(const AuthException('Invalid email or password.')),
        'Invalid email or password.',
      );
    });

    test('Firebase wrong-password maps to generic login message', () {
      expect(
        authErrorMessage(_e('wrong-password')),
        'Invalid email or password.',
      );
    });

    test('Firebase user-not-found maps to generic login message', () {
      expect(
        authErrorMessage(_e('user-not-found')),
        'Invalid email or password.',
      );
    });

    test('Firebase invalid-credential maps to generic login message', () {
      expect(
        authErrorMessage(_e('invalid-credential')),
        'Invalid email or password.',
      );
    });

    test('unknown Firebase code maps to auth fallback', () {
      expect(
        authErrorMessage(_e('internal-error')),
        'Authentication failed. Please try again.',
      );
    });

    test('Firebase network error is mapped', () {
      expect(
        authErrorMessage(_e('network-request-failed')),
        'No internet connection. Please try again.',
      );
    });

    test('generic Exception does not leak raw message', () {
      expect(
        authErrorMessage(Exception('Internal socket timeout at 127.0.0.1')),
        kAuthGenericErrorMessage,
      );
    });

    test('unknown Object returns generic message', () {
      expect(authErrorMessage('unexpected failure'), kAuthGenericErrorMessage);
      expect(authErrorMessage(42), kAuthGenericErrorMessage);
    });
  });
}

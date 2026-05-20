import 'package:firebase_auth/firebase_auth.dart';

import 'auth_exception.dart';

/// Maps [FirebaseAuthException] codes to safe, user-friendly copy.
String mapFirebaseAuthException(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Invalid email or password.';
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'account-exists-with-different-credential':
      return 'This email is already registered with another sign-in method.';
    case 'provider-already-linked':
    case 'credential-already-in-use':
      return 'This sign-in method is already linked to another account.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'network-request-failed':
      return 'No internet connection. Please try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'operation-not-allowed':
      return 'Email and password sign-in is not enabled for this app.';
    default:
      return 'Authentication failed. Please try again.';
  }
}

AuthException toAuthException(FirebaseAuthException e) {
  return AuthException(mapFirebaseAuthException(e), code: e.code);
}

const String kAuthGenericErrorMessage =
    'Something went wrong. Please try again.';

/// Normalizes any thrown value to a user-safe message (no stack traces).
String authErrorMessage(Object error) {
  if (error is AuthException) {
    return error.message;
  }
  if (error is FirebaseAuthException) {
    return mapFirebaseAuthException(error);
  }
  return kAuthGenericErrorMessage;
}

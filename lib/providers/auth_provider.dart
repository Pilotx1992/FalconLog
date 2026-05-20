import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';
import '../auth/auth_error_mapper.dart';
import '../services/notification_service.dart';

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final _logger = Logger('AuthService');

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        NotificationService.showAuthSuccess('Sign in');
      }

      return result;
    } on FirebaseAuthException catch (e) {
      throw toAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await result.user?.updateDisplayName(displayName);
      await result.user?.reload();

      return result;
    } on FirebaseAuthException catch (e) {
      throw toAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _logger.info('Starting Google Sign-In process');

      // Check if Google Play services are available first
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        if (e.toString().contains('SERVICE_INVALID') ||
            e.toString().contains('Google Play Store') ||
            e.toString().contains('Failed to signout')) {
          _logger.warning('Google Play Services not available: $e');
          throw Exception(
              'Google Sign-In is not available on this device. Google Play Services are required.');
        }
        // For other errors, continue with sign-in attempt
        _logger.warning('Warning during Google Sign-In signout: $e');
      }

      // Check if Google Play services are available
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        _logger.info('Google Sign-In: User cancelled');
        return null;
      }

      _logger.info('Google Sign-In: User selected - ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      _logger.fine('Google Sign-In: Getting tokens...');
      _logger
          .fine('Access Token: ${googleAuth.accessToken != null ? "✓" : "✗"}');
      _logger.fine('ID Token: ${googleAuth.idToken != null ? "✓" : "✗"}');

      // Check if we got the tokens with retry mechanism
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        _logger.info('Google Sign-In: Tokens missing, trying to refresh...');

        // Try to refresh tokens
        await _googleSignIn.disconnect();
        final refreshedGoogleUser = await _googleSignIn.signIn();
        if (refreshedGoogleUser == null) {
          throw Exception('Failed to re-authenticate with Google');
        }
        final refreshedAuth = await refreshedGoogleUser.authentication;

        if (refreshedAuth.accessToken == null ||
            refreshedAuth.idToken == null) {
          throw Exception(
              'Failed to get Google authentication tokens after refresh');
        }

        // Use refreshed tokens
        final credential = GoogleAuthProvider.credential(
          accessToken: refreshedAuth.accessToken,
          idToken: refreshedAuth.idToken,
        );

        _logger.info('Google Sign-In: Using refreshed tokens');
        return await _auth.signInWithCredential(credential);
      }

      // Create credential with original tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      _logger.info('Google Sign-In: Signing in with Firebase...');
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw toAuthException(e);
    } catch (e) {
      _logger.severe('Google Sign-In Error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Gracefully handle Google Play Services not being available
      if (e.toString().contains('SERVICE_INVALID') ||
          e.toString().contains('Google Play Store') ||
          e.toString().contains('Failed to signout')) {
        _logger.warning(
            'Google Sign-In signout skipped - Google Play Services not available: $e');
      } else {
        _logger.warning('Warning during Google Sign-In signout: $e');
      }
    }
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw toAuthException(e);
    }
  }
}

// Loading state provider for auth operations
final authLoadingProvider = StateProvider<bool>((ref) => false);

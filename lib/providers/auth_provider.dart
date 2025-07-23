import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Web client ID for getting ID tokens
    serverClientId: '441066678931-oik5di8v6mo3de1r6qu942kh2rll9kgf.apps.googleusercontent.com',
    // Request specific scopes for authentication
    scopes: [
      'email',
      'profile',
      'openid',
    ],
  );

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
      NotificationService.showAuthError('sign in', e.code);
      throw _handleAuthException(e);
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
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Check if Google Play services are available first
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        if (e.toString().contains('SERVICE_INVALID') || 
            e.toString().contains('Google Play Store') ||
            e.toString().contains('Failed to signout')) {
          print('Google Play Services not available: $e');
          throw Exception('Google Sign-In is not available on this device. Google Play Services are required.');
        }
        // For other errors, continue with sign-in attempt
        print('Warning during Google Sign-In signout: $e');
      }
      
      // Check if Google Play services are available
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        print('Google Sign-In: User cancelled');
        return null;
      }

      print('Google Sign-In: User selected - ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print('Google Sign-In: Getting tokens...');
      print('Access Token: ${googleAuth.accessToken != null ? "✓" : "✗"}');
      print('ID Token: ${googleAuth.idToken != null ? "✓" : "✗"}');
      
      // Check if we got the tokens with retry mechanism
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Google Sign-In: Tokens missing, trying to refresh...');
        
        // Try to refresh tokens
        await googleUser.clearAuthCache();
        final refreshedAuth = await googleUser.authentication;
        
        if (refreshedAuth.accessToken == null || refreshedAuth.idToken == null) {
          throw Exception('Failed to get Google authentication tokens after refresh');
        }
        
        // Use refreshed tokens
        final credential = GoogleAuthProvider.credential(
          accessToken: refreshedAuth.accessToken,
          idToken: refreshedAuth.idToken,
        );
        
        print('Google Sign-In: Using refreshed tokens');
        return await _auth.signInWithCredential(credential);
      }
      
      // Create credential with original tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Google Sign-In: Signing in with Firebase...');
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      print('Google Sign-In Error: $e');
      if (e.toString().contains('sign_in_failed')) {
        throw Exception('Google Sign-In failed. Please check your internet connection and try again.');
      } else if (e.toString().contains('network_error')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Google Sign-In failed: ${e.toString()}');
      }
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
        print('Google Sign-In signout skipped - Google Play Services not available: $e');
      } else {
        print('Warning during Google Sign-In signout: $e');
      }
    }
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }
}

// Loading state provider for auth operations
final authLoadingProvider = StateProvider<bool>((ref) => false);

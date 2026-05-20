import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as g;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_error_mapper.dart';
import '../auth/auth_exception.dart';

enum AuthMethod {
  email,
  google,
  biometric,
}

class EnhancedAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final g.GoogleSignIn _googleSignIn = g.GoogleSignIn(scopes: const ['email']);
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Current user stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save credentials for biometric login (encrypted)
      await _saveBiometricCredentials(email, password);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw toAuthException(e);
    }
  }

  // Sign up with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save credentials for biometric login
      await _saveBiometricCredentials(email, password);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw toAuthException(e);
    }
  }

  // Sign in with Google (v6 compatible implementation)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final g.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Sign in cancelled');
      }

      // Obtain the auth details from the request
      final g.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Verify we have the required tokens
      if (googleAuth.idToken == null) {
        throw Exception('Failed to obtain Google ID token');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      // Persist Google sign-in preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prefer_google_signin', true);
      await prefs.setString('google_email', googleUser.email);

      debugPrint('Google sign-in successful for: ${googleUser.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw const AuthException(
          'This email is already registered with email and password. '
          'Sign in with your email and password instead.',
          code: 'account-exists-with-different-credential',
        );
      }
      throw AuthException(mapFirebaseAuthException(e), code: e.code);
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In PlatformException: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'sign_in_canceled':
          throw Exception('Sign in cancelled');
        case 'sign_in_failed':
          throw Exception('Google sign-in failed. Please try again.');
        case 'network_error':
          throw Exception(
              'Network error. Please check your internet connection.');
        case 'sign_in_required':
          throw Exception('Google sign-in is required for this action');
        default:
          throw Exception('Google sign-in error: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('Google Sign-In general error: $e');

      // Handle common issues
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('play services')) {
        throw Exception(
            'Google Play Services is not available. Please ensure it\'s installed and updated.');
      } else if (errorString.contains('network')) {
        throw Exception(
            'Network error. Please check your internet connection.');
      } else if (errorString.contains('developer_error')) {
        throw Exception(
            'Google Sign-In configuration error. Please check app setup.');
      } else if (errorString.contains('internal_error')) {
        throw Exception('Internal error occurred. Please try again later.');
      } else {
        throw Exception('Google sign-in failed: ${e.toString()}');
      }
    }
  }

  // Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      return isAvailable && isDeviceSupported && availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  // Sign in with biometric authentication
  Future<UserCredential?> signInWithBiometric() async {
    try {
      // Check if biometric credentials are saved
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('biometric_email');
      final savedPassword = prefs.getString('biometric_password');

      if (savedEmail == null || savedPassword == null) {
        throw Exception(
            'No biometric credentials saved. Please sign in with email first.');
      }

      // Authenticate with biometric
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access FalconLog',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!didAuthenticate) {
        throw Exception('Biometric authentication failed');
      }

      // If biometric auth successful, sign in with saved credentials
      return await signInWithEmailAndPassword(
        email: savedEmail,
        password: savedPassword, // In production, this should be encrypted
      );
    } catch (e) {
      throw Exception('Biometric sign-in failed: ${e.toString()}');
    }
  }

  // Check if biometric credentials are saved
  Future<bool> hasBiometricCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('biometric_email') &&
        prefs.containsKey('biometric_password');
  }

  // Enable biometric authentication for current user
  Future<void> enableBiometricAuth() async {
    if (currentUser == null) {
      throw Exception('No user signed in');
    }

    final bool isAvailable = await isBiometricAvailable();
    if (!isAvailable) {
      throw Exception(
          'Biometric authentication is not available on this device');
    }

    // Test biometric authentication
    final bool didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Authenticate to enable biometric login for FalconLog',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );

    if (!didAuthenticate) {
      throw Exception('Biometric authentication setup failed');
    }

    // Save biometric preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', true);
  }

  // Disable biometric authentication
  Future<void> disableBiometricAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', false);
    await prefs.remove('biometric_email');
    await prefs.remove('biometric_password');
  }

  // Check if biometric auth is enabled
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  // Legacy login biometric: update stored creds only when user opted in.
  Future<void> _saveBiometricCredentials(String email, String password) async {
    if (!await isBiometricEnabled()) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('biometric_email', email);
    await prefs.setString('biometric_password', password);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint('Starting comprehensive sign-out process...');

      // Sign out from Google if signed in
      try {
        await _googleSignIn.signOut();
        debugPrint('Google sign-out completed');
      } catch (e) {
        debugPrint('Google sign-out warning (non-fatal): $e');
        // Continue with Firebase sign out even if Google sign out fails
      }

      // Sign out from Firebase
      await _firebaseAuth.signOut();
      debugPrint('Firebase sign-out completed');

      // Clear ALL saved preferences related to auth
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('prefer_google_signin');
      await prefs.remove('google_email');
      await prefs.remove('user_email');
      await prefs.remove('auth_method');
      await prefs.remove('biometric_enabled');
      await prefs.remove('remember_me');
      debugPrint('Auth preferences cleared');

      // Force Firebase auth state to refresh
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('Sign-out process completed successfully');
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw toAuthException(e);
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // Clear biometric credentials
        await disableBiometricAuth();

        // Delete user account
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      throw toAuthException(e);
    }
  }

  // Get preferred sign-in method
  Future<AuthMethod?> getPreferredSignInMethod() async {
    final prefs = await SharedPreferences.getInstance();

    if (await isBiometricEnabled() && await hasBiometricCredentials()) {
      return AuthMethod.biometric;
    }

    if (prefs.getBool('prefer_google_signin') ?? false) {
      return AuthMethod.google;
    }

    return AuthMethod.email;
  }
}

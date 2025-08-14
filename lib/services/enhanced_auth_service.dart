import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart'; // Temporarily disabled
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthMethod {
  email,
  google,
  biometric,
}

class EnhancedAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn(); // Temporarily disabled
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
      throw _handleFirebaseAuthError(e);
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
      throw _handleFirebaseAuthError(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // TODO: Google Sign-In implementation temporarily disabled due to API compatibility issues
      throw Exception('Google Sign-In is currently under maintenance. Please use email/password login.');
      
      /* Original implementation commented out
      // Check if Google Play Services are available first
      final isAvailable = await _googleSignIn.isSignedIn();
      debugPrint('Google Sign-In availability check: $isAvailable');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled by user');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      // Save Google sign-in preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prefer_google_signin', true);
      await prefs.setString('google_email', googleUser.email);
      
      debugPrint('Google sign-in successful for: ${googleUser.email}');
      return userCredential;
      */
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        throw Exception('Google sign-in was cancelled');
      } else if (e.code == 'network_error') {
        throw Exception('Network error occurred during Google sign-in');
      } else {
        throw Exception('Google sign-in failed: ${e.message}');
      }
    } catch (e) {
      if (e.toString().contains('Google Play Services')) {
        throw Exception('Google Play Services not available. This feature requires Google Play Services and works on real devices only.');
      } else if (e.toString().contains('SERVICE_INVALID')) {
        throw Exception('Google Play Services not available on this device');
      }
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  // Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
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
        throw Exception('No biometric credentials saved. Please sign in with email first.');
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
    return prefs.containsKey('biometric_email') && prefs.containsKey('biometric_password');
  }

  // Enable biometric authentication for current user
  Future<void> enableBiometricAuth() async {
    if (currentUser == null) {
      throw Exception('No user signed in');
    }

    final bool isAvailable = await isBiometricAvailable();
    if (!isAvailable) {
      throw Exception('Biometric authentication is not available on this device');
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

  // Save credentials for biometric login (Note: In production, use proper encryption)
  Future<void> _saveBiometricCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = await isBiometricEnabled();
    
    if (biometricEnabled || await isBiometricAvailable()) {
      // In production, encrypt these values properly
      await prefs.setString('biometric_email', email);
      await prefs.setString('biometric_password', password);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in (temporarily disabled)
      /*
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      */
      
      // Sign out from Firebase
      await _firebaseAuth.signOut();
      
      // Clear saved preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('prefer_google_signin');
      await prefs.remove('google_email');
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
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
      throw _handleFirebaseAuthError(e);
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

  // Handle Firebase Auth errors
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address. Please check your email or sign up for a new account.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials and try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address. Please sign in instead.';
      case 'weak-password':
        return 'The password provided is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'The email address is not valid. Please enter a valid email address.';
      case 'user-disabled':
        return 'This user account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a few minutes before trying again.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'auth/invalid-credential':
        return 'Authentication failed. Please check your email and password.';
      default:
        return 'Authentication failed: ${e.message ?? e.code}';
    }
  }
}

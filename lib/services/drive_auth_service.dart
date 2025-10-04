import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../core/exceptions/backup_exceptions.dart';

/// A service class to handle Google Drive authentication logic.
class DriveAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  /// Returns the current signed-in Google account, if any.
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Returns true if the user is currently signed in.
  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Gets authentication headers for API requests.
  Future<Map<String, String>> getAuthHeaders({
    bool interactive = true,
    bool attemptSilent = true,
  }) async {
    try {
      GoogleSignInAccount? account;

      if (attemptSilent && !interactive) {
        account = await _googleSignIn.signInSilently();
      } else if (interactive) {
        account = await _googleSignIn.signIn();
      } else {
        account = _googleSignIn.currentUser;
      }

      if (account == null) {
        throw CloudAuthenticationException('User not authenticated');
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.accessToken == null) {
        throw CloudAuthenticationException('No access token available');
      }

      return {
        'Authorization': 'Bearer ${auth.accessToken}',
      };
    } catch (e) {
      debugPrint('Error getting auth headers: $e');
      throw CloudAuthenticationException(
          'Failed to get authentication headers: $e');
    }
  }

  /// Ensures the user is signed in and has granted the necessary Drive API scopes.
  Future<GoogleSignInAccount?> ensureAuthenticated() async {
    try {
      // First try silent sign-in to avoid user interaction if possible
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();

      if (account != null) {
        debugPrint(
            'Google Drive authentication restored silently for: ${account.email}');
        return account;
      }

      // If silent sign-in fails, try interactive sign-in
      account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('Google Drive authentication cancelled by user');
        return null;
      }

      debugPrint(
          'Google Drive authentication successful for: ${account.email}');

      // Verify we have the necessary scopes
      final auth = await account.authentication;
      if (auth.accessToken == null) {
        throw CloudAuthenticationException(
            'Failed to obtain access token for Drive API');
      }

      return account;
    } catch (e) {
      debugPrint('Error during Google Drive authentication: $e');
      if (e is CloudAuthenticationException) {
        rethrow;
      }
      throw CloudAuthenticationException(
          'Google Drive authentication failed: $e');
    }
  }

  /// Signs the user out from Google.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('Google sign out completed');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}

// --- Riverpod Providers ---

/// Provider for the [DriveAuthService] instance.
final driveAuthServiceProvider = Provider<DriveAuthService>((ref) {
  return DriveAuthService();
});

/// A StreamProvider that exposes the current signed-in Google account.
final googleAccountProvider = StreamProvider<GoogleSignInAccount?>((ref) {
  final authService = ref.watch(driveAuthServiceProvider);

  // Create a stream that emits the current user and updates when auth state changes
  return Stream.periodic(const Duration(seconds: 1))
      .map((_) => authService.currentUser)
      .distinct();
});

/// A provider that indicates if the user has granted Drive scope.
final driveScopeGrantedProvider = Provider<bool>((ref) {
  final authService = ref.watch(driveAuthServiceProvider);
  return authService.isSignedIn;
});

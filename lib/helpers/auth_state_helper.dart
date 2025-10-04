import 'package:firebase_auth/firebase_auth.dart';

class AuthStateHelper {
  // Get current user
  static User? get currentUser => FirebaseAuth.instance.currentUser;

  // Check if user is signed in
  static bool get isSignedIn => currentUser != null;

  // Alias for isSignedIn (used by NavigationService)
  static bool get isLoggedIn => isSignedIn;

  // Get user display name
  static String get displayName => currentUser?.displayName ?? 'Pilot';

  // Get user email
  static String get email => currentUser?.email ?? 'pilot@falconlog.com';

  // Get user photo URL
  static String? get photoURL => currentUser?.photoURL;

  // Get user ID
  static String? get uid => currentUser?.uid;

  // Check if email is verified
  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Get provider data
  static List<UserInfo> get providerData => currentUser?.providerData ?? [];

  // Check if user signed in with Google
  static bool get isGoogleUser {
    return providerData.any((provider) => provider.providerId == 'google.com');
  }

  // Check if user signed in with email/password
  static bool get isEmailUser {
    return providerData.any((provider) => provider.providerId == 'password');
  }

  // Get creation time
  static DateTime? get creationTime => currentUser?.metadata.creationTime;

  // Get last sign in time
  static DateTime? get lastSignInTime => currentUser?.metadata.lastSignInTime;

  // Reload user data
  static Future<void> reloadUser() async {
    await currentUser?.reload();
  }

  // Send email verification
  static Future<void> sendEmailVerification() async {
    await currentUser?.sendEmailVerification();
  }

  // Update display name
  static Future<void> updateDisplayName(String displayName) async {
    await currentUser?.updateDisplayName(displayName);
  }

  // Update photo URL
  static Future<void> updatePhotoURL(String photoURL) async {
    await currentUser?.updatePhotoURL(photoURL);
  }

  // Update password
  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user signed in');
    }

    // Re-authenticate user with current password
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);

    // Update password
    await user.updatePassword(newPassword);
  }

  // Sign out user
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}

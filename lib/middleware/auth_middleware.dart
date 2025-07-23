import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/navigation_service.dart';

class AuthMiddleware {
  static bool _isInitialized = false;
  
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _handleAuthStateChange(user);
    });
    
    _isInitialized = true;
  }
  
  static void _handleAuthStateChange(User? user) {
    // Don't navigate if we don't have a navigator yet
    if (NavigationService.navigatorKey.currentState == null || 
        !NavigationService.navigatorKey.currentState!.mounted) {
      return;
    }
    
    final currentContext = NavigationService.context;
    if (currentContext == null) return;
    
    if (user == null) {
      // User signed out - redirect to login if not already there
      final currentRoute = ModalRoute.of(currentContext)?.settings.name;
      final publicRoutes = ['/login', '/register', '/forgot-password'];
      
      if (currentRoute != null && !publicRoutes.contains(currentRoute)) {
        NavigationService.goToLogin();
      }
    } else {
      // User signed in - redirect to dashboard if on auth pages
      final currentRoute = ModalRoute.of(currentContext)?.settings.name;
      final authRoutes = ['/login', '/register', '/forgot-password'];
      
      if (currentRoute != null && authRoutes.contains(currentRoute)) {
        NavigationService.goToDashboard();
      }
    }
  }
  
  // Check if user should have access to route
  static bool canAccessRoute(String route) {
    final user = FirebaseAuth.instance.currentUser;
    final publicRoutes = ['/login', '/register', '/forgot-password', '/'];
    
    if (publicRoutes.contains(route)) {
      return true;
    }
    
    return user != null;
  }
  
  // Get appropriate initial route based on auth state
  static String getInitialRoute() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? '/home' : '/login';
  }
  
  // Validate user session
  static Future<bool> validateSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // Force refresh the token to check if it's still valid
      await user.getIdToken(true);
      return true;
    } catch (e) {
      // Token is invalid, sign out
      await FirebaseAuth.instance.signOut();
      return false;
    }
  }
  
  // Check if user needs to verify email
  static bool needsEmailVerification() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.emailVerified;
  }
  
  // Show email verification reminder
  static void showEmailVerificationReminder() {
    NavigationService.showSnackBar(
      'Please verify your email address to access all features',
      isError: false,
    );
  }
  
  // Resend verification email
  static Future<void> resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        NavigationService.showSnackBar(
          'Verification email sent successfully',
        );
      }
    } catch (e) {
      NavigationService.showSnackBar(
        'Failed to send verification email: ${e.toString()}',
        isError: true,
      );
    }
  }
}

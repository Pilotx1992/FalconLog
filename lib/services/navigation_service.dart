import 'package:flutter/material.dart';

import '../utils/app_snack_bar.dart';
import '../helpers/auth_state_helper.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  static BuildContext? get context => navigatorKey.currentContext;

  // Navigate to route with auth protection
  static Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
    bool requireAuth = true,
  }) {
    if (requireAuth && !AuthStateHelper.isLoggedIn) {
      return pushNamedAndClearStack('/login');
    }
    return navigatorKey.currentState!
        .pushNamed(routeName, arguments: arguments);
  }

  // Replace current route
  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    Object? arguments,
    TO? result,
    bool requireAuth = true,
  }) {
    if (requireAuth && !AuthStateHelper.isLoggedIn) {
      return pushNamedAndClearStack('/login');
    }
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  // Clear stack and navigate
  static Future<T?> pushNamedAndClearStack<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  // Pop current route
  static void pop<T extends Object?>([T? result]) {
    return navigatorKey.currentState!.pop(result);
  }

  // Check if can pop
  static bool canPop() {
    return navigatorKey.currentState!.canPop();
  }

  // Show snackbar
  static void showSnackBar(String message, {bool isError = false}) {
    final currentContext = context;
    if (currentContext == null) return;

    final messenger = ScaffoldMessenger.of(currentContext);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF3949ab),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: AppSnackBar.forOutcome(isError: isError),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => messenger.clearSnackBars(),
        ),
      ),
    );
  }

  // Show loading dialog
  static void showLoadingDialog({String message = 'Loading...'}) {
    final currentContext = context;
    if (currentContext == null) return;

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1a237e), Color(0xFF3949ab)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Hide loading dialog
  static void hideLoadingDialog() {
    if (navigatorKey.currentState!.canPop()) {
      navigatorKey.currentState!.pop();
    }
  }

  // Show confirmation dialog
  static Future<bool?> showConfirmationDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    final currentContext = context;
    if (currentContext == null) return Future.value(false);

    return showDialog<bool>(
      context: currentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                cancelText,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDestructive ? Colors.red : const Color(0xFF3949ab),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Navigation shortcuts for common routes
  static Future<void> goToLogin() => pushNamedAndClearStack('/login');
  static Future<void> goToDashboard() => pushNamedAndClearStack('/home');
  static Future<void> goToLogFlight() => pushNamed('/logFlight');
  static Future<void> goToFlights() => pushNamed('/flights');
  static Future<void> goToSummary() => pushNamed('/summary');
  static Future<void> goToSettings() => pushNamed('/settings');

  // Auth-specific navigation
  static Future<void> logout() async {
    final shouldLogout = await showConfirmationDialog(
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of your account?',
      confirmText: 'Sign Out',
      isDestructive: true,
    );

    if (shouldLogout == true) {
      showLoadingDialog(message: 'Signing out...');
      try {
        await AuthStateHelper.signOut();
        hideLoadingDialog();
        await goToLogin();
        showSnackBar('Signed out successfully');
      } catch (e) {
        hideLoadingDialog();
        showSnackBar(
          'Could not sign out. Please try again.',
          isError: true,
        );
      }
    }
  }
}

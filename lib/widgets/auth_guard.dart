import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';
import '../security/ui/security_wrapper.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;
  final bool requireAuth;

  const AuthGuard({
    super.key,
    required this.child,
    this.requireAuth = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1a237e),
                    Color(0xFF3949ab),
                    Color(0xFF5e35b1)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        }

        final isLoggedIn = snapshot.hasData && snapshot.data != null;

        // If auth is required and user is not logged in
        if (requireAuth && !isLoggedIn) {
          return const LoginScreen();
        }

        // If auth is not required or user is logged in
        return SecurityWrapper(child: child);
      },
    );
  }
}

// Helper function to wrap routes with auth guard
Route<dynamic>? generateAuthProtectedRoute(
    RouteSettings settings, Widget Function(BuildContext) builder) {
  return MaterialPageRoute<dynamic>(
    settings: settings,
    builder: (context) => AuthGuard(
      child: Builder(builder: builder),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/language_provider.dart';
import 'localization/app_localizations.dart';
import 'screens/dashboard_screen.dart';
import 'screens/log_flight_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/advanced_screen.dart';
import 'screens/all_flights_screen.dart';
import 'screens/edit_flight_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'debug/auth_debug_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/auth_guard.dart';
import 'services/navigation_service.dart';

class FalconLogApp extends ConsumerWidget {
  const FalconLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isRTL = ref.watch(isRTLProvider);
    
    return MaterialApp(
      title: 'FalconLog',
      navigatorKey: NavigationService.navigatorKey,
      locale: locale,
      supportedLocales: availableLanguages.map((lang) => lang.locale).toList(),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A7CCF), // Sky blue brand
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B2030),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFF2F7FA)),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      initialRoute: '/splash',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const AuthGuard(child: DashboardScreen()),
        '/dashboard': (context) => const AuthGuard(child: DashboardScreen()), // Alias for /home
        '/logFlight': (context) => const LogFlightScreen(),
        '/flights': (context) => const AllFlightsScreen(),
        '/summary': (context) => const SummaryScreen(),
        '/advanced': (context) => const AdvancedScreen(),
        '/settings': (context) => const SettingsScreen(),
  '/login': (context) => const AuthGuard(requireAuth: false, child: LoginScreen()),
        '/register': (context) => const AuthGuard(requireAuth: false, child: RegisterScreen()),
        '/forgot-password': (context) => const AuthGuard(requireAuth: false, child: ForgotPasswordScreen()),
        '/debug-auth': (context) => const AuthDebugScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name != null &&
            settings.name!.startsWith('/editFlight/')) {
          final id = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => AuthGuard(
              child: EditFlightScreen(flightId: id),
            ),
          );
        }
        return null;
      },
    );
  }
}

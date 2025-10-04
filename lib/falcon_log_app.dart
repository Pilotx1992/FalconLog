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
      // --- ابدأ التعديل هنا ---
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3949ab), // لون بنفسجي ليتناسب مع تصميمك
          // قم بتغيير السطر التالي إلى Brightness.light
          brightness: Brightness.light, 
        ),
        // يمكنك الآن تحديد ألوان إضافية للوضع الفاتح
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // خلفية فاتحة للشاشات
        dialogBackgroundColor: Colors.white, // خلفية بيضاء لمربعات الحوار
        cardColor: Colors.white, // خلفية بيضاء للكروت
        
        // تخصيص لون النص ليكون داكنًا في الوضع الفاتح
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF334155)), // لون نص داكن
          titleLarge: TextStyle(color: Color(0xFF334155)), // لون للعناوين الكبيرة
          titleMedium: TextStyle(color: Color(0xFF334155)), // لون للعناوين المتوسطة
        ),
        
        // تخصيص مظهر الـ AppBar ليكون متناسقًا
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // شفاف ليظهر التدرج اللوني
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white), // لون الأيقونات
          titleTextStyle: TextStyle( // تصميم نص العنوان
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // --- انتهى التعديل ---
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

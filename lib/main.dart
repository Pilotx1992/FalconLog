import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'falcon_log_app.dart';
import 'models/flight_log.dart';
import 'middleware/auth_middleware.dart';
import 'utils/performance_optimizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تحسين الأداء في البداية
  PerformanceOptimizer.optimizeUI();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Configure Firebase Auth Emulator only for emulators (not real devices)
  // This is disabled for real device deployment
  /* 
  if (kDebugMode) {
    try {
      // Force emulator connection for development with HTTP
      debugPrint('🔧 Debug mode detected - Connecting to Firebase Auth Emulator...');
      await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
      debugPrint('✅ Using Firebase Auth Emulator on 10.0.2.2:9099');
      debugPrint('🔧 Google Sign-In will work on emulator now!');
      debugPrint('🌐 HTTP cleartext traffic enabled for emulator');
    } catch (e) {
      debugPrint('⚠️ Firebase Auth Emulator not available: $e');
      debugPrint('💡 You can still use email/password auth');
      // Try alternative emulator address
      try {
        await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
        debugPrint('✅ Using Firebase Auth Emulator on 127.0.0.1:9099');
      } catch (e2) {
        debugPrint('⚠️ Alternative emulator address also failed: $e2');
      }
    }
  }
  */
  
  // Real device will use production Firebase Auth
  debugPrint('🔧 Using production Firebase Auth for real device');
  
  // Listen to Firebase Auth state changes (بدون تأثير على UI)
  FirebaseAuth.instance
    .authStateChanges()
    .listen((User? user) {
      if (user == null) {
        debugPrint('User is currently signed out!');
      } else {
        debugPrint('User is signed in!');
      }
    });
  
  // Initialize critical components immediately
  await _initializeCriticalComponents();
  
  // تشغيل التطبيق أولاً
  runApp(const ProviderScope(child: FalconLogApp()));
  
  // تأجيل العمليات الثقيلة بعد بناء الواجهة
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _initializeHeavyOperations();
  });
}

// تهيئة المكونات الأساسية فوراً
Future<void> _initializeCriticalComponents() async {
  try {
    debugPrint('Initializing critical components...');
    
    // Initialize Hive immediately for critical functionality
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(FlightTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PilotRoleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(FlightLogAdapter());

    // Open the main box
    await Hive.openBox<FlightLog>('flightLogsBox');
    
    debugPrint('Critical components initialized');
  } catch (e) {
    debugPrint('Error initializing critical components: $e');
  }
}

// تأجيل العمليات الثقيلة
Future<void> _initializeHeavyOperations() async {
  try {
    debugPrint('Starting heavy operations initialization...');
    
    // Add delay to prevent UI blocking
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Initialize Auth Middleware in background
    Future.microtask(() async {
      try {
        await AuthMiddleware.initialize();
        debugPrint('Auth Middleware initialized');
      } catch (e) {
        debugPrint('Error initializing Auth Middleware: $e');
      }
    });
    
    debugPrint('Heavy operations initialized successfully');
  } catch (e) {
    debugPrint('Error initializing heavy operations: $e');
  }
}

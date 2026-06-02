import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup/models/backup_metadata.dart';
import 'backup/services/backup_service.dart';
import 'backup/utils/backup_scheduler.dart';
import 'backup/utils/cleanup_old_workers.dart';
import 'backup/utils/restore_recovery_notice_store.dart';
import 'core/services/app_data_migration_service.dart';
import 'core/services/hive_initialization_service.dart';
import 'core/services/storage_migration_service.dart';
import 'falcon_log_app.dart';
import 'firebase_options.dart';
import 'auth/legacy_auth_credential_cleanup.dart';
import 'middleware/auth_middleware.dart';
import 'models/flight_log.dart';
import 'utils/performance_optimizer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PerformanceOptimizer.optimizeUI();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await LegacyAuthCredentialCleanup.removeUnsafePlaintextCredentials();

  debugPrint('Using production Firebase Auth configuration');

  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user == null) {
      debugPrint('User is currently signed out.');
    } else {
      debugPrint('User is signed in.');
    }
  });

  await _initializeCriticalComponents();

  // Initialize backup scheduler
  try {
    await BackupScheduler.initialize();
    debugPrint('Backup scheduler initialized successfully.');

    // Clean up old WorkManager tasks once, then restore the user's saved
    // auto-backup schedule so app restarts do not disable it.
    await WorkManagerCleanup.cleanupOldTasks();
    await BackupScheduler.restoreSavedSchedule();
    debugPrint('Saved backup schedule restored.');
  } catch (error, stackTrace) {
    debugPrint('Backup scheduler initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const ProviderScope(child: FalconLogApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _initializeHeavyOperations();
  });
}

Future<void> _initializeCriticalComponents() async {
  try {
    debugPrint('Initializing critical components...');

    await HiveInitializationService.initialize();
    await HiveInitializationService.openBox<FlightLog>('flightLogsBox');

    await AppDataMigrationService.runMigrationsIfNeeded();
    await StorageMigrationService.ensureCurrentSchemaRecorded();

    final pendingRestore =
        await BackupService.recoverPendingReplaceRestoreIfNeeded();
    if (pendingRestore.hadPendingJournal) {
      await RestoreRecoveryNoticeStore.save(pendingRestore);
      if (pendingRestore.rollbackSucceeded) {
        debugPrint('✅ ${pendingRestore.message}');
      } else {
        debugPrint('⚠️ ${pendingRestore.message}');
      }
    }

    // Initialize backup metadata box for backup system (MUST be typed!)
    await HiveInitializationService.openBox<BackupMetadata>('backupMetadata');
    debugPrint('Backup metadata box initialized.');

    debugPrint('Critical components initialized.');
  } catch (error, stackTrace) {
    debugPrint('Error initializing critical components: ');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _initializeHeavyOperations() async {
  try {
    debugPrint('Starting heavy operations initialization...');

    await Future.delayed(const Duration(milliseconds: 100));

    Future.microtask(() async {
      try {
        await AuthMiddleware.initialize();
        debugPrint('Auth middleware initialized.');
      } catch (error, stackTrace) {
        debugPrint('Error initializing auth middleware: ');
        debugPrintStack(stackTrace: stackTrace);
      }
    });

    debugPrint('Heavy operations initialized successfully.');
  } catch (error, stackTrace) {
    debugPrint('Error initializing heavy operations: ');
    debugPrintStack(stackTrace: stackTrace);
  }
}

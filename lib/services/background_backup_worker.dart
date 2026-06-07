import 'dart:async';
import 'dart:developer';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../firebase_options.dart';
import '../models/flight_log.dart';
import '../backup/services/backup_service.dart';

/// Task identifiers
class BackgroundBackupTasks {
  static const periodicEncryptedLocal = 'periodic_encrypted_local_backup';
}

/// Entry point for Workmanager. Must be a top-level function.
@pragma('vm:entry-point')
Future<bool> backgroundDispatcher() async {
  try {
    // Ensure Flutter bindings
    // WidgetsFlutterBinding.ensureInitialized(); // Avoid heavy UI binding in background
    // Init minimal platform services
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Open Hive (only if not already). Using try to avoid race.
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(FlightTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PilotRoleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(FlightLogAdapter());
    if (!Hive.isBoxOpen('flightLogsBox')) {
      await Hive.initFlutter();
      await Hive.openBox<FlightLog>('flightLogsBox');
    }

    Workmanager().executeTask((task, inputData) async {
      log('[BackgroundBackup] Executing task: $task');
      if (task == BackgroundBackupTasks.periodicEncryptedLocal) {
        try {
          final box = Hive.box<FlightLog>('flightLogsBox');
          final logs = box.values.toList();
          if (logs.isNotEmpty) {
            // Implement background backup using BackupService instance
            final backupService = BackupService();
            final success = await backupService.startBackup();
            log('[BackgroundBackup] Result: ${success ? 'Success' : 'Failed'}');
          } else {
            log('[BackgroundBackup] No logs to backup.');
          }
        } catch (e, st) {
          log('[BackgroundBackup] Error: $e');
          log(st.toString());
        }
      }
      return Future.value(true);
    });
    return true;
  } catch (e, st) {
    log('[BackgroundBackup] Initialization error: $e');
    log(st.toString());
    return false;
  }
}

/// Helper to register periodic task
class BackgroundBackupScheduler {
  static Future<void> initAndSchedule() async {
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      'encrypted_local_backup',
      BackgroundBackupTasks.periodicEncryptedLocal,
      frequency: const Duration(hours: 12), // adjust as needed
      initialDelay: const Duration(minutes: 10),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
      backoffPolicy: BackoffPolicy.exponential,
    );
  }
}

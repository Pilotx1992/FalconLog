import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// One-time cleanup utility to cancel old WorkManager tasks
/// This should be called once during app initialization to clean up
/// tasks from the old backup system implementation
class WorkManagerCleanup {
  static const String _cleanupDoneKey = 'falconlog_workmanager_cleanup_done_v2';

  /// Cancel all old backup-related WorkManager tasks
  static Future<void> cleanupOldTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_cleanupDoneKey) ?? false) {
        return;
      }

      await Workmanager().cancelByUniqueName('falconlog_backup_task');
      await Workmanager().cancelByUniqueName('encrypted_local_backup');
      await Workmanager().cancelByUniqueName('falconlog_backup_task_immediate');
      await Workmanager().cancelByTag('falconlog_backup');

      await prefs.setBool(_cleanupDoneKey, true);
      if (kDebugMode) {
        debugPrint(
            '[WorkManagerCleanup] Old backup WorkManager tasks cancelled');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WorkManagerCleanup] Error cleaning up old tasks: $e');
      }
    }
  }
}

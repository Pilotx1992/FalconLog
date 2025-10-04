import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

/// One-time cleanup utility to cancel old WorkManager tasks
/// This should be called once during app initialization to clean up
/// tasks from the old backup system implementation
class WorkManagerCleanup {
  /// Cancel all old backup-related WorkManager tasks
  static Future<void> cleanupOldTasks() async {
    try {
      // Cancel all tasks to ensure clean slate
      await Workmanager().cancelAll();
      if (kDebugMode) {
        debugPrint('[WorkManagerCleanup] All old WorkManager tasks cancelled');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WorkManagerCleanup] Error cleaning up old tasks: $e');
      }
    }
  }
}

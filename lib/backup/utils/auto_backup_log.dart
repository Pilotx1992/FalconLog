import 'package:flutter/foundation.dart';

/// Structured auto-backup logs visible in `adb logcat` via [debugPrint].
class AutoBackupLog {
  AutoBackupLog._();

  static void qa(String message) => _print('AutoBackupQA', message);

  static void reconciler(String message) =>
      _print('AutoBackupReconciler', message);

  static void worker(String message) => _print('AutoBackupWorker', message);

  static void stateStore(String message) =>
      _print('AutoBackupStateStore', message);

  /// Due-engine messages (subset of QA diagnostics).
  static void dueEngine(String message) => _print('AutoBackupDueEngine', message);

  static void scheduler(String message) =>
      _print('AutoBackupScheduler', message);

  static void lifecycle(String message) =>
      _print('AutoBackupLifecycle', message);

  static void _print(String tag, String message) {
    debugPrint('[$tag] $message');
  }
}

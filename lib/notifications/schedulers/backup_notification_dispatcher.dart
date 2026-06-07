import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../domain/notification_preferences.dart';
import '../services/local_notification_service.dart';
import '../services/notification_permission_service.dart';

/// Shows backup result notifications when preferences and permission allow.
class BackupNotificationDispatcher {
  BackupNotificationDispatcher._();

  static final _logger = Logger('BackupNotificationDispatcher');

  @visibleForTesting
  static Future<NotificationPreferences> Function()? loadPreferencesOverride;

  @visibleForTesting
  static Future<bool> Function()? areNotificationsEnabledOverride;

  @visibleForTesting
  static Future<void> Function()? showCompletedOverride;

  @visibleForTesting
  static Future<void> Function(String reason)? showFailedOverride;

  static Future<void> onBackupSuccess() async {
    try {
      if (!await _shouldNotify()) return;
      final show =
          showCompletedOverride ?? LocalNotificationService.showBackupCompleted;
      await show();
    } catch (e, stackTrace) {
      _logger.warning('onBackupSuccess notification failed', e, stackTrace);
    }
  }

  static Future<void> onBackupFailure({String reason = ''}) async {
    try {
      if (!await _shouldNotify()) return;
      final show =
          showFailedOverride ?? LocalNotificationService.showBackupFailed;
      await show(reason);
    } catch (e, stackTrace) {
      _logger.warning('onBackupFailure notification failed', e, stackTrace);
    }
  }

  static Future<bool> _shouldNotify() async {
    final loadPrefs =
        loadPreferencesOverride ?? NotificationPreferencesRepository().load;
    final prefs = await loadPrefs();
    if (!prefs.shouldShowBackupNotifications) return false;

    final enabledCheck = areNotificationsEnabledOverride ??
        NotificationPermissionService.areNotificationsEnabled;
    return enabledCheck();
  }
}

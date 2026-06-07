import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

/// Android 13+ notification permission without permission_handler.
class NotificationPermissionService {
  NotificationPermissionService._();

  static final _logger = Logger('NotificationPermissionService');
  static const MethodChannel _settingsChannel =
      MethodChannel('com.falcon_log.falconlog/notifications');

  @visibleForTesting
  static Future<bool> Function()? areEnabledOverride;

  @visibleForTesting
  static Future<bool?> Function()? requestOverride;

  static Future<bool> areNotificationsEnabled() async {
    final override = areEnabledOverride;
    if (override != null) {
      try {
        return await override();
      } catch (_) {
        return false;
      }
    }
    try {
      final android = _androidPlugin;
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        return enabled ?? false;
      }
      // iOS / other: assume enabled when plugin cannot check.
      return true;
    } catch (e, stackTrace) {
      _logger.warning('areNotificationsEnabled failed', e, stackTrace);
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    final override = requestOverride;
    if (override != null) {
      try {
        return await override() ?? false;
      } catch (_) {
        return false;
      }
    }
    try {
      final android = _androidPlugin;
      if (android == null) return true;
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    } catch (e, stackTrace) {
      _logger.warning('requestPermission failed', e, stackTrace);
      return false;
    }
  }

  static Future<void> openNotificationSettings() async {
    try {
      await _settingsChannel.invokeMethod<void>('openNotificationSettings');
    } catch (e, stackTrace) {
      _logger.warning('openNotificationSettings failed', e, stackTrace);
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    return FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
  }
}

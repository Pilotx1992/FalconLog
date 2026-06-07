import 'package:shared_preferences/shared_preferences.dart';

import 'notification_payload.dart';

/// Persists notification tap payloads for cold-start routing (not app backup).
class PendingNotificationRouteStore {
  PendingNotificationRouteStore._();

  static Future<String?> takePayloadIfUnderAttemptLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = prefs.getString(NotificationPayload.pendingPayloadKey);
      if (payload == null || payload.isEmpty) return null;

      final attempts =
          prefs.getInt(NotificationPayload.pendingAttemptCountKey) ?? 0;
      if (attempts >= NotificationPayload.maxPendingNavigationAttempts) {
        return null;
      }
      return payload;
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePayload(String payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(NotificationPayload.pendingPayloadKey, payload);
      await prefs.setInt(NotificationPayload.pendingAttemptCountKey, 0);
    } catch (_) {
      // Best-effort.
    }
  }

  static Future<void> recordFailedNavigationAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attempts =
          prefs.getInt(NotificationPayload.pendingAttemptCountKey) ?? 0;
      await prefs.setInt(
        NotificationPayload.pendingAttemptCountKey,
        attempts + 1,
      );
    } catch (_) {
      // Best-effort.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(NotificationPayload.pendingPayloadKey);
      await prefs.remove(NotificationPayload.pendingAttemptCountKey);
    } catch (_) {
      // Best-effort.
    }
  }
}

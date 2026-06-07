import 'package:shared_preferences/shared_preferences.dart';

/// Anti-spam store for immediate currency reminders (not included in app backup).
class CurrencyReminderLastShownStore {
  CurrencyReminderLastShownStore._();

  static String _dateKey(int notificationId) =>
      'falconlog_currency_last_shown_date_$notificationId';

  static String _daysLeftKey(int notificationId) =>
      'falconlog_currency_last_shown_days_$notificationId';

  /// Returns true if a notification was already shown today for [notificationId].
  static Future<bool> wasShownToday({
    required int notificationId,
    DateTime? now,
    @Deprecated('No longer used for combined daily reminders')
    int? daysLeft,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString(_dateKey(notificationId));
      if (storedDate == null) return false;

      final today = _formatDate(now ?? DateTime.now());
      return storedDate == today;
    } catch (_) {
      return false;
    }
  }

  static Future<void> recordShown({
    required int notificationId,
    DateTime? now,
    @Deprecated('No longer used for combined daily reminders')
    int? daysLeft,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _dateKey(notificationId),
        _formatDate(now ?? DateTime.now()),
      );
      if (daysLeft != null) {
        await prefs.setInt(_daysLeftKey(notificationId), daysLeft);
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  static String _formatDate(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

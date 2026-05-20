import 'package:shared_preferences/shared_preferences.dart';

import 'currency_alert_settings.dart';

class CurrencyAlertSettingsRepository {
  Future<CurrencyAlertSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final completed =
        prefs.getBool(CurrencyAlertSettings.prefKeySetupCompleted) ?? false;
    final day = prefs.getInt(CurrencyAlertSettings.prefKeyDayAlertDays) ??
        CurrencyAlertSettings.defaultDayAlertDays;
    final night = prefs.getInt(CurrencyAlertSettings.prefKeyNightAlertDays) ??
        CurrencyAlertSettings.defaultNightAlertDays;
    return CurrencyAlertSettings(
      dayAlertDays: day,
      nightAlertDays: night,
      hasCompletedSetup: completed,
    );
  }

  Future<void> completeSetup({
    required int dayAlertDays,
    required int nightAlertDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      CurrencyAlertSettings.prefKeyDayAlertDays,
      dayAlertDays,
    );
    await prefs.setInt(
      CurrencyAlertSettings.prefKeyNightAlertDays,
      nightAlertDays,
    );
    await prefs.setBool(CurrencyAlertSettings.prefKeySetupCompleted, true);
  }

  Future<void> updateIntervals({
    required int dayAlertDays,
    required int nightAlertDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      CurrencyAlertSettings.prefKeyDayAlertDays,
      dayAlertDays,
    );
    await prefs.setInt(
      CurrencyAlertSettings.prefKeyNightAlertDays,
      nightAlertDays,
    );
  }

  /// Test-only: clears setup flag and prefs.
  Future<void> resetSetupForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CurrencyAlertSettings.prefKeyDayAlertDays);
    await prefs.remove(CurrencyAlertSettings.prefKeyNightAlertDays);
    await prefs.remove(CurrencyAlertSettings.prefKeySetupCompleted);
  }
}

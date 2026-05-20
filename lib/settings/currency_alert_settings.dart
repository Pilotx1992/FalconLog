/// Manual currency alert interval settings (day/night reminder days).
class CurrencyAlertSettings {
  final int dayAlertDays;
  final int nightAlertDays;
  final bool hasCompletedSetup;

  const CurrencyAlertSettings({
    required this.dayAlertDays,
    required this.nightAlertDays,
    required this.hasCompletedSetup,
  });

  static const int defaultDayAlertDays = 15;
  static const int defaultNightAlertDays = 10;
  static const int minAlertDays = 1;
  static const int maxAlertDays = 365;

  static const String prefKeyDayAlertDays = 'falconlog_currency_day_alert_days';
  static const String prefKeyNightAlertDays =
      'falconlog_currency_night_alert_days';
  static const String prefKeySetupCompleted =
      'falconlog_currency_alert_setup_completed';

  static const CurrencyAlertSettings defaults = CurrencyAlertSettings(
    dayAlertDays: defaultDayAlertDays,
    nightAlertDays: defaultNightAlertDays,
    hasCompletedSetup: false,
  );

  CurrencyAlertSettings copyWith({
    int? dayAlertDays,
    int? nightAlertDays,
    bool? hasCompletedSetup,
  }) {
    return CurrencyAlertSettings(
      dayAlertDays: dayAlertDays ?? this.dayAlertDays,
      nightAlertDays: nightAlertDays ?? this.nightAlertDays,
      hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
    );
  }
}

/// Validates manual day/night alert input (digits only, 1–365).
String? validateCurrencyAlertDays(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  final trimmed = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
    return 'Enter a whole number';
  }
  final parsed = int.tryParse(trimmed);
  if (parsed == null) {
    return 'Enter a whole number';
  }
  if (parsed < CurrencyAlertSettings.minAlertDays) {
    return 'Minimum is ${CurrencyAlertSettings.minAlertDays} day';
  }
  if (parsed > CurrencyAlertSettings.maxAlertDays) {
    return 'Maximum is ${CurrencyAlertSettings.maxAlertDays} days';
  }
  return null;
}

/// Parses validated input to int; returns null if invalid.
int? parseCurrencyAlertDays(String? value) {
  if (validateCurrencyAlertDays(value) != null) return null;
  return int.parse(value!.trim());
}

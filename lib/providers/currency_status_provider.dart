import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flight_log.dart';
import '../settings/currency_alert_settings_provider.dart';
import 'flight_logs_provider.dart';

class CurrencyStatus {
  final bool dayDue;
  final String dayMessage;
  final bool nightDue;
  final String nightMessage;
  CurrencyStatus({
    this.dayDue = false,
    this.dayMessage = '',
    this.nightDue = false,
    this.nightMessage = '',
  });
}

/// Pure currency due calculation from logs and manual alert intervals.
CurrencyStatus computeCurrencyStatus({
  required List<FlightLog> logs,
  required int dayAlertDays,
  required int nightAlertDays,
  required DateTime now,
}) {
  if (logs.isEmpty) {
    return CurrencyStatus(
      dayDue: false,
      nightDue: false,
      dayMessage: 'No day flights recorded.',
      nightMessage: 'No night flights recorded.',
    );
  }

  DateTime? lastDayFlightDate;
  DateTime? lastNightFlightDate;

  for (final log in logs) {
    if (log.isDayFlight) {
      if (lastDayFlightDate == null || log.date.isAfter(lastDayFlightDate)) {
        lastDayFlightDate = log.date;
      }
    } else {
      if (lastNightFlightDate == null || log.date.isAfter(lastNightFlightDate)) {
        lastNightFlightDate = log.date;
      }
    }
  }

  final dayDue = lastDayFlightDate == null ||
      now.difference(lastDayFlightDate).inDays >= dayAlertDays;
  final nightDue = lastNightFlightDate == null ||
      now.difference(lastNightFlightDate).inDays >= nightAlertDays;

  String dayMessage;
  if (lastDayFlightDate != null) {
    final daysSince = now.difference(lastDayFlightDate).inDays;
    if (dayDue) {
      dayMessage =
          'Last day flight: $daysSince days ago (alert every $dayAlertDays days)';
    } else {
      final expiry = lastDayFlightDate.add(Duration(days: dayAlertDays));
      final remaining = expiry.difference(now).inDays;
      dayMessage =
          'Day currency valid: $remaining days remaining (alert every $dayAlertDays days)';
    }
  } else {
    dayMessage = 'No day flights recorded.';
  }

  String nightMessage;
  if (lastNightFlightDate != null) {
    final daysSince = now.difference(lastNightFlightDate).inDays;
    if (nightDue) {
      nightMessage =
          'Last night flight: $daysSince days ago (alert every $nightAlertDays days)';
    } else {
      final expiry = lastNightFlightDate.add(Duration(days: nightAlertDays));
      final remaining = expiry.difference(now).inDays;
      nightMessage =
          'Night currency valid: $remaining days remaining (alert every $nightAlertDays days)';
    }
  } else {
    nightMessage = 'No night flights recorded.';
  }

  return CurrencyStatus(
    dayDue: dayDue,
    nightDue: nightDue,
    dayMessage: dayMessage,
    nightMessage: nightMessage,
  );
}

final currencyStatusProvider = Provider<CurrencyStatus>((ref) {
  final logsAsync = ref.watch(flightLogsProvider);
  final settingsAsync = ref.watch(currencyAlertSettingsProvider);

  if (settingsAsync.isLoading) {
    return CurrencyStatus(
      dayDue: false,
      nightDue: false,
      dayMessage: 'Loading currency status...',
      nightMessage: 'Loading currency status...',
    );
  }

  if (settingsAsync.hasError) {
    return CurrencyStatus(
      dayDue: false,
      nightDue: false,
      dayMessage: 'Error loading currency status.',
      nightMessage: 'Error loading currency status.',
    );
  }

  final settings = settingsAsync.value!;
  final dayInterval = settings.dayAlertDays;
  final nightInterval = settings.nightAlertDays;
  final now = DateTime.now();

  return logsAsync.when(
    data: (logs) => computeCurrencyStatus(
      logs: logs,
      dayAlertDays: dayInterval,
      nightAlertDays: nightInterval,
      now: now,
    ),
    loading: () => CurrencyStatus(
      dayDue: false,
      nightDue: false,
      dayMessage: 'Loading currency status...',
      nightMessage: 'Loading currency status...',
    ),
    error: (err, stack) => CurrencyStatus(
      dayDue: false,
      nightDue: false,
      dayMessage: 'Error loading currency status.',
      nightMessage: 'Error loading currency status.',
    ),
  );
});

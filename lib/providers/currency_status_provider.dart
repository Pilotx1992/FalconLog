import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flight_log.dart';
import '../settings/currency_alert_settings_provider.dart';
import 'flight_logs_provider.dart';

/// Unified subtitle for day/night currency alerts.
String formatLastFlightDaysAgo(int days) =>
    'Last flight: $days ${days == 1 ? 'day' : 'days'} ago';

/// Currency summary for one kind (day or night).
class CurrencyKindRow {
  final DateTime? lastFlightDate;
  /// Null when no flights of this kind; calendar days until expiry (0 = expires today; negative = expired).
  final int? daysRemaining;
  final bool outOfCurrency;

  const CurrencyKindRow({
    this.lastFlightDate,
    this.daysRemaining,
    this.outOfCurrency = false,
  });

  static const empty = CurrencyKindRow();
}

class CurrencyStatus {
  final CurrencyKindRow day;
  final CurrencyKindRow night;
  final String dayMessage;
  final String nightMessage;
  final bool hasFlights;

  bool get dayDue => day.outOfCurrency;
  bool get nightDue => night.outOfCurrency;
  bool get hasAlert => day.outOfCurrency || night.outOfCurrency;

  const CurrencyStatus({
    this.day = CurrencyKindRow.empty,
    this.night = CurrencyKindRow.empty,
    this.dayMessage = '',
    this.nightMessage = '',
    this.hasFlights = false,
  });

  bool get isLoading =>
      dayMessage == 'Loading…' && nightMessage == 'Loading…';

  bool get hasError =>
      dayMessage == 'Could not load status' &&
      nightMessage == 'Could not load status';
}

CurrencyKindRow _computeKindRow({
  required DateTime? lastFlightDate,
  required int alertIntervalDays,
  required DateTime now,
  required bool treatMissingAsOut,
}) {
  if (lastFlightDate == null) {
    return CurrencyKindRow(
      daysRemaining: null,
      outOfCurrency: treatMissingAsOut,
    );
  }

  final lastLocal = DateTime(
    lastFlightDate.year,
    lastFlightDate.month,
    lastFlightDate.day,
  );
  final today = DateTime(now.year, now.month, now.day);
  final expiry = lastLocal.add(Duration(days: alertIntervalDays));
  final remaining = expiry.difference(today).inDays;
  final outOfCurrency = remaining < 0;

  return CurrencyKindRow(
    lastFlightDate: lastFlightDate,
    daysRemaining: remaining,
    outOfCurrency: outOfCurrency,
  );
}

String _lastFlightMessage(DateTime? lastFlightDate, DateTime now, bool due) {
  if (!due) return '';
  if (lastFlightDate == null) return 'Last flight: none';
  return formatLastFlightDaysAgo(now.difference(lastFlightDate).inDays);
}

/// Pure currency due calculation from logs and manual alert intervals.
CurrencyStatus computeCurrencyStatus({
  required List<FlightLog> logs,
  required int dayAlertDays,
  required int nightAlertDays,
  required DateTime now,
}) {
  if (logs.isEmpty) {
    return const CurrencyStatus();
  }

  DateTime? lastDayFlightDate;
  DateTime? lastNightFlightDate;

  for (final log in logs) {
    if (log.isDayFlight) {
      if (lastDayFlightDate == null || log.date.isAfter(lastDayFlightDate)) {
        lastDayFlightDate = log.date;
      }
    } else {
      if (lastNightFlightDate == null ||
          log.date.isAfter(lastNightFlightDate)) {
        lastNightFlightDate = log.date;
      }
    }
  }

  final day = _computeKindRow(
    lastFlightDate: lastDayFlightDate,
    alertIntervalDays: dayAlertDays,
    now: now,
    treatMissingAsOut: true,
  );
  final night = _computeKindRow(
    lastFlightDate: lastNightFlightDate,
    alertIntervalDays: nightAlertDays,
    now: now,
    treatMissingAsOut: true,
  );

  return CurrencyStatus(
    day: day,
    night: night,
    dayMessage: _lastFlightMessage(lastDayFlightDate, now, day.outOfCurrency),
    nightMessage:
        _lastFlightMessage(lastNightFlightDate, now, night.outOfCurrency),
    hasFlights: true,
  );
}

final currencyStatusProvider = Provider<CurrencyStatus>((ref) {
  final logsAsync = ref.watch(flightLogsProvider);
  final settingsAsync = ref.watch(currencyAlertSettingsProvider);

  if (settingsAsync.isLoading) {
    return const CurrencyStatus(
      dayMessage: 'Loading…',
      nightMessage: 'Loading…',
    );
  }

  if (settingsAsync.hasError) {
    return const CurrencyStatus(
      dayMessage: 'Could not load status',
      nightMessage: 'Could not load status',
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
    loading: () => const CurrencyStatus(
      dayMessage: 'Loading…',
      nightMessage: 'Loading…',
    ),
    error: (err, stack) => const CurrencyStatus(
      dayMessage: 'Could not load status',
      nightMessage: 'Could not load status',
    ),
  );
});

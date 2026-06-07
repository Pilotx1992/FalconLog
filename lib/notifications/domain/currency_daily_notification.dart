import '../../models/flight_log.dart';

/// Result of currency remaining calculation for one kind (day or night).
class CurrencyKindRemaining {
  const CurrencyKindRemaining({
    required this.lastFlightDate,
    required this.remainingDays,
  });

  final DateTime lastFlightDate;
  final int remainingDays;
}

/// Combined local notification content for the daily currency countdown.
class CurrencyDailyNotificationContent {
  const CurrencyDailyNotificationContent({
    required this.title,
    required this.body,
    required this.lines,
  });

  final String title;
  final String body;
  final List<String> lines;
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Latest flight date for [isDay] flights using [FlightLog.date] only.
DateTime? findLastFlightDate(List<FlightLog> logs, {required bool isDay}) {
  DateTime? last;
  for (final log in logs) {
    if (log.isDayFlight != isDay) continue;
    final flightDate = dateOnly(log.date);
    if (last == null || flightDate.isAfter(last)) {
      last = flightDate;
    }
  }
  return last;
}

/// expiry = lastFlightDate + alertIntervalDays; remaining = calendar days until expiry.
int computeRemainingCalendarDays({
  required DateTime lastFlightDate,
  required int alertIntervalDays,
  required DateTime now,
}) {
  final lastLocal = dateOnly(lastFlightDate);
  final today = dateOnly(now);
  final expiry = lastLocal.add(Duration(days: alertIntervalDays));
  return expiry.difference(today).inDays;
}

/// Notifications start the calendar day after the last flight (not on flight day).
bool shouldNotifyAfterLastFlight({
  required DateTime lastFlightDate,
  required DateTime now,
}) {
  final lastLocal = dateOnly(lastFlightDate);
  final today = dateOnly(now);
  return today.isAfter(lastLocal);
}

String formatCurrencyKindStatusLine(int remainingDays) {
  if (remainingDays > 0) {
    return '$remainingDays ${remainingDays == 1 ? 'day' : 'days'} remaining';
  }
  if (remainingDays == 0) {
    return 'expires today';
  }
  final expiredDays = -remainingDays;
  return 'expired $expiredDays ${expiredDays == 1 ? 'day' : 'days'} ago';
}

String formatCurrencyKindNotificationLine({
  required String kindLabel,
  required int remainingDays,
}) {
  return '$kindLabel: ${formatCurrencyKindStatusLine(remainingDays)}';
}

CurrencyKindRemaining? computeKindRemaining({
  required List<FlightLog> logs,
  required bool isDay,
  required int alertIntervalDays,
  required DateTime now,
}) {
  final lastFlight = findLastFlightDate(logs, isDay: isDay);
  if (lastFlight == null) return null;
  if (!shouldNotifyAfterLastFlight(lastFlightDate: lastFlight, now: now)) {
    return null;
  }
  return CurrencyKindRemaining(
    lastFlightDate: lastFlight,
    remainingDays: computeRemainingCalendarDays(
      lastFlightDate: lastFlight,
      alertIntervalDays: alertIntervalDays,
      now: now,
    ),
  );
}

/// Builds one combined daily notification, or null when nothing to report.
CurrencyDailyNotificationContent? buildCombinedCurrencyDailyNotification({
  required List<FlightLog> logs,
  required int dayAlertDays,
  required int nightAlertDays,
  required DateTime now,
}) {
  final lines = <String>[];

  final day = computeKindRemaining(
    logs: logs,
    isDay: true,
    alertIntervalDays: dayAlertDays,
    now: now,
  );
  if (day != null) {
    lines.add(
      formatCurrencyKindNotificationLine(
        kindLabel: 'Day currency',
        remainingDays: day.remainingDays,
      ),
    );
  }

  final night = computeKindRemaining(
    logs: logs,
    isDay: false,
    alertIntervalDays: nightAlertDays,
    now: now,
  );
  if (night != null) {
    lines.add(
      formatCurrencyKindNotificationLine(
        kindLabel: 'Night currency',
        remainingDays: night.remainingDays,
      ),
    );
  }

  if (lines.isEmpty) return null;

  return CurrencyDailyNotificationContent(
    title: 'Currency reminder',
    body: lines.join('\n'),
    lines: lines,
  );
}

/// Local hour (0–23) when the daily currency notification is expected.
const int currencyDailyNotificationHour = 9;

/// True when [now] is at or after the daily notification window (9:00 local).
bool isPastDailyNotificationHour(DateTime now) =>
    now.hour >= currencyDailyNotificationHour;

/// Delay until the next local 9:00 AM (for WorkManager initial delay).
Duration delayUntilNext9Am({DateTime? now}) {
  final local = now ?? DateTime.now();
  var next = DateTime(local.year, local.month, local.day, 9);
  if (!next.isAfter(local)) {
    next = next.add(const Duration(days: 1));
  }
  return next.difference(local);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight_log.dart';
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

final currencyStatusProvider = Provider<CurrencyStatus>((ref) {
  final logsAsync = ref.watch(flightLogsProvider);

  return logsAsync.when(
    data: (logs) {
      final now = DateTime.now();

      // Calculate total flight hours
      double totalHours = logs.fold(0.0,
          (sum, log) => sum + (log.durationHours + log.durationMinutes / 60.0));
      double nightHours = logs.where((log) => !log.isDayFlight).fold(0.0,
          (sum, log) => sum + (log.durationHours + log.durationMinutes / 60.0));

      // Determine currency intervals based on pilot experience
      int dayCurrencyInterval;
      int nightCurrencyInterval;

      if (totalHours >= 0 && totalHours <= 599) {
        // 0-599 hours
        dayCurrencyInterval = 15;
        nightCurrencyInterval = 10;
      } else if (totalHours >= 600 && totalHours <= 799 && nightHours >= 125) {
        // 600-799 hours with minimum 125 night hours
        dayCurrencyInterval = 21;
        nightCurrencyInterval = 15;
      } else if (totalHours >= 800 && nightHours >= 200) {
        // 800+ hours with minimum 200 night hours
        dayCurrencyInterval = 30;
        nightCurrencyInterval = 21;
      } else {
        // Default to most restrictive if requirements not met
        dayCurrencyInterval = 15;
        nightCurrencyInterval = 10;
      }

      final dayFlights = logs.where((log) => log.isDayFlight);
      final nightFlights = logs.where((log) => !log.isDayFlight);

      DateTime? lastDayFlightDate = _latestFlightDate(dayFlights);
      DateTime? lastNightFlightDate = _latestFlightDate(nightFlights);

      bool dayDue = lastDayFlightDate == null ||
          now.difference(lastDayFlightDate).inDays >= dayCurrencyInterval;
      bool nightDue = lastNightFlightDate == null ||
          now.difference(lastNightFlightDate).inDays >= nightCurrencyInterval;

      // Calculate expiry dates
      String dayMessage = '';
      String nightMessage = '';

      if (lastDayFlightDate != null) {
        final daysSinceLastFlight = now.difference(lastDayFlightDate).inDays;
        if (dayDue) {
          dayMessage = 'Last day flight: $daysSinceLastFlight days ago';
        } else {
          final dayExpiryDate =
              lastDayFlightDate.add(Duration(days: dayCurrencyInterval));
          final daysRemaining = dayExpiryDate.difference(now).inDays;
          dayMessage = 'Day currency valid ($daysRemaining days remaining)';
        }
      } else {
        dayMessage = 'No day flights recorded.';
      }

      if (lastNightFlightDate != null) {
        final daysSinceLastFlight = now.difference(lastNightFlightDate).inDays;
        if (nightDue) {
          nightMessage = 'Last night flight: $daysSinceLastFlight days ago';
        } else {
          final nightExpiryDate =
              lastNightFlightDate.add(Duration(days: nightCurrencyInterval));
          final daysRemaining = nightExpiryDate.difference(now).inDays;
          nightMessage = 'Night currency valid ($daysRemaining days remaining)';
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
    },
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


DateTime? _latestFlightDate(Iterable<FlightLog> flights) {
  DateTime? latest;
  for (final flight in flights) {
    final flightDate = flight.date;
    if (latest == null || flightDate.isAfter(latest)) {
      latest = flightDate;
    }
  }
  return latest;
}

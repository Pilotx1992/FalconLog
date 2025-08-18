import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight_log.dart';

// Cached summary provider for better performance
final summaryProvider = Provider.family<FlightDataSummary, List<FlightLog>>((
  ref,
  logs,
) {
  // Early return for empty logs
  if (logs.isEmpty) {
    return FlightDataSummary(
      totalFlightHours: 0,
      totalFlights: 0,
      dayTimeHours: 0,
      nightTimeHours: 0,
      lastMission: null,
    );
  }

  double totalHours = 0;
  double dayHours = 0;
  double nightHours = 0;

  // More efficient loop with single pass
  for (final log in logs) {
    final duration = log.durationHours + (log.durationMinutes / 60.0);
    totalHours += duration;
    if (log.isDayFlight) {
      dayHours += duration;
    } else {
      nightHours += duration;
    }
  }

  return FlightDataSummary(
    totalFlightHours: totalHours,
    totalFlights: logs.length,
    dayTimeHours: dayHours,
    nightTimeHours: nightHours,
    lastMission: logs.first, // logs is not empty here
  );
});

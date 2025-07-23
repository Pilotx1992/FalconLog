import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight_log.dart';

final summaryProvider = Provider.family<FlightDataSummary, List<FlightLog>>((
  ref,
  logs,
) {
  double totalHours = 0;
  double dayHours = 0;
  double nightHours = 0;

  for (var log in logs) {
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
    lastMission: logs.isNotEmpty ? logs.first : null,
  );
});

import '../../models/flight_log.dart';

double durationInHours(FlightLog log) =>
    log.durationHours + (log.durationMinutes / 60.0);

/// HH:MM — same convention as dashboard [_formatHours].
String formatDurationHhMm(double hours) {
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Decimal hours with one decimal place for pivot/summary tables.
String formatHoursDecimal(double hours) => hours.toStringAsFixed(1);

import 'report_date_range.dart';

class FlightReportSummary {
  const FlightReportSummary({
    required this.range,
    required this.totalFlights,
    required this.totalHours,
    required this.dayHours,
    required this.nightHours,
    required this.totalLandings,
    required this.aircraftCount,
    this.firstFlightDate,
    this.lastFlightDate,
    required this.isEmpty,
  });

  final ReportDateRange range;
  final int totalFlights;
  final double totalHours;
  final double dayHours;
  final double nightHours;
  final int totalLandings;
  final int aircraftCount;
  final DateTime? firstFlightDate;
  final DateTime? lastFlightDate;
  final bool isEmpty;

  factory FlightReportSummary.empty(ReportDateRange range) {
    return FlightReportSummary(
      range: range,
      totalFlights: 0,
      totalHours: 0,
      dayHours: 0,
      nightHours: 0,
      totalLandings: 0,
      aircraftCount: 0,
      isEmpty: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightReportSummary &&
          other.range.kind == range.kind &&
          other.range.start == range.start &&
          other.range.end == range.end &&
          other.totalFlights == totalFlights &&
          other.totalHours == totalHours &&
          other.dayHours == dayHours &&
          other.nightHours == nightHours &&
          other.totalLandings == totalLandings &&
          other.aircraftCount == aircraftCount &&
          other.firstFlightDate == firstFlightDate &&
          other.lastFlightDate == lastFlightDate &&
          other.isEmpty == isEmpty;

  @override
  int get hashCode => Object.hash(
        range.kind,
        range.start,
        range.end,
        totalFlights,
        totalHours,
        dayHours,
        nightHours,
        totalLandings,
        aircraftCount,
        firstFlightDate,
        lastFlightDate,
        isEmpty,
      );
}

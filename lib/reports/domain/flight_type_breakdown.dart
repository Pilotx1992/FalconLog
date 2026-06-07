class FlightTypeBreakdownRow {
  const FlightTypeBreakdownRow({
    required this.label,
    required this.flights,
    required this.hours,
    required this.dayHours,
    required this.nightHours,
    required this.percentOfFlights,
  });

  final String label;
  final int flights;
  final double hours;
  final double dayHours;
  final double nightHours;
  final double percentOfFlights;
}

class FlightTypeBreakdown {
  const FlightTypeBreakdown({
    required this.rows,
    required this.totalFlights,
    required this.totalHours,
  });

  final List<FlightTypeBreakdownRow> rows;
  final int totalFlights;
  final double totalHours;

  static const empty = FlightTypeBreakdown(
    rows: [],
    totalFlights: 0,
    totalHours: 0,
  );
}

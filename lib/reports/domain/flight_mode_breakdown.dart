class FlightModeBreakdownRow {
  const FlightModeBreakdownRow({
    required this.label,
    required this.flights,
    required this.hours,
  });

  final String label;
  final int flights;
  final double hours;
}

class FlightModeBreakdown {
  const FlightModeBreakdown({required this.rows});

  final List<FlightModeBreakdownRow> rows;

  static const empty = FlightModeBreakdown(rows: []);
}

class FlightConditionBreakdownRow {
  const FlightConditionBreakdownRow({
    required this.label,
    required this.flights,
    required this.hours,
  });

  final String label;
  final int flights;
  final double hours;
}

class FlightConditionBreakdown {
  const FlightConditionBreakdown({required this.rows});

  final List<FlightConditionBreakdownRow> rows;

  static const empty = FlightConditionBreakdown(rows: []);
}

class PeriodBucket {
  const PeriodBucket({
    required this.label,
    required this.flights,
    required this.hours,
    required this.dayHours,
    required this.nightHours,
  });

  final String label;
  final int flights;
  final double hours;
  final double dayHours;
  final double nightHours;
}

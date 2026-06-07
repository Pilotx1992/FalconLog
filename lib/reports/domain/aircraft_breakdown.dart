class AircraftBreakdownRow {
  const AircraftBreakdownRow({
    required this.key,
    required this.aircraftType,
    this.registration,
    required this.flights,
    required this.hours,
    required this.dayHours,
    required this.nightHours,
    required this.landings,
  });

  final String key;
  final String aircraftType;
  final String? registration;
  final int flights;
  final double hours;
  final double dayHours;
  final double nightHours;
  final int landings;
}

class AircraftBreakdown {
  const AircraftBreakdown({
    required this.byAircraftType,
    required this.byRegistration,
    required this.hasRegistrationData,
  });

  final List<AircraftBreakdownRow> byAircraftType;
  final List<AircraftBreakdownRow> byRegistration;
  final bool hasRegistrationData;

  static const empty = AircraftBreakdown(
    byAircraftType: [],
    byRegistration: [],
    hasRegistrationData: false,
  );
}

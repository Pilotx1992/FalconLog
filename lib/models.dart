// FlightType enum
enum FlightType { local, mission, xc, zone, range, formation, currencyFlight, landingGround, navalOps, lowLevel }

// PilotRole enum
enum PilotRole { IP, MTP, PIC, CPG_GUNNER }

// Extensions for enum display names
extension FlightTypeExtension on FlightType {
  String get name {
    switch (this) {
      case FlightType.local:
        return 'Local';
      case FlightType.mission:
        return 'Mission';
      case FlightType.xc:
        return 'Cross Country';
      case FlightType.zone:
        return 'Zone';
      case FlightType.range:
        return 'Range';
      case FlightType.formation:
        return 'Formation';
      case FlightType.currencyFlight:
        return 'Currency';
      case FlightType.landingGround:
        return 'Landing Ground';
      case FlightType.navalOps:
        return 'Naval OPS';
      case FlightType.lowLevel:
        return 'Low Level';
    }
  }
}

extension PilotRoleExtension on PilotRole {
  String get name {
    switch (this) {
      case PilotRole.IP:
        return 'IP';
      case PilotRole.MTP:
        return 'MTP';
      case PilotRole.PIC:
        return 'PIC';
      case PilotRole.CPG_GUNNER:
        return 'CPG GUNNER';
    }
  }
}

// FlightLog model
class FlightLog {
  final String id;
  final DateTime date;
  final List<FlightType> flightTypes;
  final int durationHours;
  final int durationMinutes;
  final String aircraftType;
  final PilotRole pilotRole;
  final String base;
  final bool isDayFlight;
  final bool isSimulated;
  final DateTime createdAt;

  FlightLog({
    required this.id,
    required this.date,
    required this.flightTypes,
    required this.durationHours,
    required this.durationMinutes,
    required this.aircraftType,
    required this.pilotRole,
    required this.base,
    required this.isDayFlight,
    required this.isSimulated,
    required this.createdAt,
  });
}

// CurrencyStatus model
class CurrencyStatus {
  final bool isDue;
  final String? alertType; // 'Day' or 'Night'
  final DateTime? lastFlightDate;
  final int? requiredInterval;
  final String message;

  CurrencyStatus({
    required this.isDue,
    this.alertType,
    this.lastFlightDate,
    this.requiredInterval,
    required this.message,
  });
}

// FlightDataSummary model
class FlightDataSummary {
  final double totalFlightHours;
  final int totalFlights;
  final double dayTimeHours;
  final double nightTimeHours;

  FlightDataSummary({
    required this.totalFlightHours,
    required this.totalFlights,
    required this.dayTimeHours,
    required this.nightTimeHours,
  });
}

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'flight_log.g.dart';

@HiveType(typeId: 0)
enum FlightType {
  @HiveField(0)
  local,
  @HiveField(1)
  mission,
  @HiveField(2)
  xc,
  @HiveField(3)
  zone,
  @HiveField(4)
  range,
  @HiveField(5)
  formation,
  @HiveField(6)
  currencyFlight,
  @HiveField(7)
  landingGround,
  @HiveField(8)
  navalOps,
  @HiveField(9)
  lowLevel,
}

@HiveType(typeId: 1)
enum PilotRole {
  @HiveField(0)
  IP,
  @HiveField(1)
  MTP,
  @HiveField(2)
  PIC,
  @HiveField(3)
  CPG_GUNNER,
}

@HiveType(typeId: 2)
class FlightLog extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  DateTime date;
  @HiveField(2)
  List<FlightType> flightTypes;
  @HiveField(3)
  int durationHours;
  @HiveField(4)
  int durationMinutes;
  @HiveField(5)
  String aircraftType;
  @HiveField(6)
  PilotRole pilotRole;
  @HiveField(7)
  bool isDayFlight;
  @HiveField(8)
  bool isSimulated;
  @HiveField(9)
  DateTime createdAt;

  FlightLog({
    String? id,
    required this.date,
    required this.flightTypes,
    required this.durationHours,
    required this.durationMinutes,
    required this.aircraftType,
    required this.pilotRole,
    required this.isDayFlight,
    required this.isSimulated,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory FlightLog.fromMap(Map<String, dynamic> map) {
    return FlightLog(
      id: map['id'],
      date: DateTime.parse(map['date']),
      flightTypes: (map['flightTypes'] as List)
          .map((type) => FlightType.values.firstWhere((e) => e.toString() == type))
          .toList(),
      durationHours: map['durationHours'],
      durationMinutes: map['durationMinutes'],
      aircraftType: map['aircraftType'],
      pilotRole: PilotRole.values.firstWhere((e) => e.toString() == map['pilotRole']),
      isDayFlight: map['isDayFlight'],
      isSimulated: map['isSimulated'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  static FlightLog fromJson(Map<String, dynamic> json) {
    return FlightLog(
      id: json['id'],
      date: DateTime.parse(json['date']),
      flightTypes: (json['flightTypes'] as List<dynamic>)
          .map((e) => FlightType.values.byName(e))
          .toList(),
      durationHours: json['durationHours'],
      durationMinutes: json['durationMinutes'],
      aircraftType: json['aircraftType'],
      pilotRole: PilotRole.values.byName(json['pilotRole']),
      isDayFlight: json['isDayFlight'] ?? true,
      isSimulated: json['isSimulated'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }
}

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

class FlightDataSummary {
  final double totalFlightHours;
  final int totalFlights;
  final double dayTimeHours;
  final double nightTimeHours;
  final FlightLog? lastMission;

  FlightDataSummary({
    required this.totalFlightHours,
    required this.totalFlights,
    required this.dayTimeHours,
    required this.nightTimeHours,
    this.lastMission,
  });
}

// JSON serialization extensions
extension FlightLogJson on FlightLog {
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'flightTypes': flightTypes.map((e) => e.name).toList(),
    'durationHours': durationHours,
    'durationMinutes': durationMinutes,
    'aircraftType': aircraftType,
    'pilotRole': pilotRole.name,
    'isDayFlight': isDayFlight,
    'isSimulated': isSimulated,
    'createdAt': createdAt.toIso8601String(),
  };
}

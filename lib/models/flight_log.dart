import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

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
  ip,
  @HiveField(1)
  mtp,
  @HiveField(2)
  pic,
  @HiveField(3)
  cpgGunner,
  @HiveField(4)
  wzo,
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
  @HiveField(10)
  DateTime? dateUpdated;
  @HiveField(11)
  String? registration;
  @HiveField(12)
  String? departure;
  @HiveField(13)
  String? arrival;
  @HiveField(14)
  double? flightTime;
  @HiveField(15)
  double? picTime;
  @HiveField(16)
  double? sicTime;
  @HiveField(17)
  double? nightTime;
  @HiveField(18)
  double? ifrTime;
  @HiveField(19)
  double? crossCountry;
  @HiveField(20)
  int? dayLandings;
  @HiveField(21)
  int? nightLandings;
  @HiveField(22)
  String? remarks;
  @HiveField(23)
  DateTime? updatedAt;

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
    this.dateUpdated,
    this.registration,
    this.departure,
    this.arrival,
    this.flightTime,
    this.picTime,
    this.sicTime,
    this.nightTime,
    this.ifrTime,
    this.crossCountry,
    this.dayLandings,
    this.nightLandings,
    this.remarks,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // Convenience getters that handle null values
  double get safeFlightTime => flightTime ?? 0.0;
  double get safePicTime => picTime ?? 0.0;
  double get safeSicTime => sicTime ?? 0.0;
  double get safeNightTime => nightTime ?? 0.0;
  double get safeIfrTime => ifrTime ?? 0.0;
  double get safeCrossCountry => crossCountry ?? 0.0;
  int get safeDayLandings => dayLandings ?? 0;
  int get safeNightLandings => nightLandings ?? 0;

  factory FlightLog.fromMap(Map<String, dynamic> map) {
    return FlightLog(
      id: map['id'],
      date: DateTime.parse(map['date']),
      flightTypes: (map['flightTypes'] as List)
          .map((type) =>
              FlightType.values.firstWhere((e) => e.toString() == type))
          .toList(),
      durationHours: map['durationHours'],
      durationMinutes: map['durationMinutes'],
      aircraftType: map['aircraftType'],
      pilotRole:
          PilotRole.values.firstWhere((e) => e.toString() == map['pilotRole']),
      isDayFlight: map['isDayFlight'],
      isSimulated: map['isSimulated'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  static FlightLog fromJson(Map<String, dynamic> json) {
    return FlightLog(
      id: json['id']?.toString(),
      date: _parseRequiredDateTime(json['date'], 'date'),
      flightTypes: _parseFlightTypes(json['flightTypes']),
      durationHours: _parseRequiredInt(json['durationHours'], 'durationHours'),
      durationMinutes:
          _parseRequiredInt(json['durationMinutes'], 'durationMinutes'),
      aircraftType: _parseRequiredString(json['aircraftType'], 'aircraftType'),
      pilotRole: _safeParsePilotRole(json['pilotRole']),
      isDayFlight: _parseBool(json['isDayFlight'], defaultValue: true),
      isSimulated: _parseBool(json['isSimulated'], defaultValue: false),
      createdAt: _parseOptionalDateTime(json['createdAt']),
      dateUpdated: _parseOptionalDateTime(json['dateUpdated']),
      registration: _parseOptionalString(
        _firstPresent(json, const ['registration', 'aircraftRegistration']),
      ),
      departure: _parseOptionalString(
        _firstPresent(json, const ['departure', 'from']),
      ),
      arrival: _parseOptionalString(
        _firstPresent(json, const ['arrival', 'to']),
      ),
      flightTime: _parseOptionalDouble(json['flightTime']),
      picTime: _parseOptionalDouble(json['picTime']),
      sicTime: _parseOptionalDouble(json['sicTime']),
      nightTime: _parseOptionalDouble(json['nightTime']),
      ifrTime: _parseOptionalDouble(json['ifrTime']),
      crossCountry: _parseOptionalDouble(json['crossCountry']),
      dayLandings: _parseOptionalInt(json['dayLandings']),
      nightLandings: _parseOptionalInt(json['nightLandings']),
      remarks: _parseOptionalString(
        _firstPresent(json, const ['remarks', 'notes']),
      ),
      updatedAt: _parseOptionalDateTime(json['updatedAt']),
    );
  }

  static List<FlightType> _parseFlightTypes(dynamic value) {
    if (value is! List) {
      throw const FormatException('flightTypes must be a list');
    }
    return value
        .map((e) => _safeParseFlightType(e))
        .where((type) => type != null)
        .cast<FlightType>()
        .toList();
  }

  static dynamic _firstPresent(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) {
        return json[key];
      }
    }
    return null;
  }

  static String _parseRequiredString(dynamic value, String fieldName) {
    if (value == null) {
      throw FormatException('$fieldName is required');
    }
    return value.toString();
  }

  static String? _parseOptionalString(dynamic value) {
    return value?.toString();
  }

  static int _parseRequiredInt(dynamic value, String fieldName) {
    final parsed = _parseOptionalInt(value);
    if (parsed == null) {
      throw FormatException('$fieldName is required');
    }
    return parsed;
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value.isFinite && value % 1 == 0) {
      return value.toInt();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.parse(trimmed);
    }
    throw FormatException('Expected integer value, got ${value.runtimeType}');
  }

  static double? _parseOptionalDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.parse(trimmed);
    }
    throw FormatException('Expected decimal value, got ${value.runtimeType}');
  }

  static bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    throw FormatException('Expected boolean value, got ${value.runtimeType}');
  }

  static DateTime _parseRequiredDateTime(dynamic value, String fieldName) {
    final parsed = _parseOptionalDateTime(value);
    if (parsed == null) {
      throw FormatException('$fieldName is required');
    }
    return parsed;
  }

  static DateTime? _parseOptionalDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.parse(trimmed);
    }
    throw FormatException('Expected DateTime value, got ${value.runtimeType}');
  }

  static FlightType? _safeParseFlightType(dynamic value) {
    try {
      if (value is String) {
        // Manual name lookup for older Dart versions
        for (final enumValue in FlightType.values) {
          final enumName = enumValue.toString();
          if (enumName == value || enumName.split('.').last == value) {
            return enumValue;
          }
        }
        final index = int.tryParse(value);
        if (index != null && index >= 0 && index < FlightType.values.length) {
          return FlightType.values[index];
        }
      } else if (value is int &&
          value >= 0 &&
          value < FlightType.values.length) {
        return FlightType.values[value];
      }
    } catch (e) {
      // Ignore invalid enum values
    }
    return null;
  }

  static PilotRole _safeParsePilotRole(dynamic value) {
    try {
      if (value is String) {
        // Manual name lookup for older Dart versions
        for (final enumValue in PilotRole.values) {
          final enumName = enumValue.toString();
          if (enumName == value || enumName.split('.').last == value) {
            return enumValue;
          }
        }
        final index = int.tryParse(value);
        if (index != null && index >= 0 && index < PilotRole.values.length) {
          return PilotRole.values[index];
        }
      } else if (value is int &&
          value >= 0 &&
          value < PilotRole.values.length) {
        return PilotRole.values[value];
      }
    } catch (e) {
      // Fallback to default value
    }
    return PilotRole.pic; // Default value
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
  Map<String, dynamic> toJson() {
    try {
      if (kDebugMode) {
        print(
            '🐛 DEBUG: Converting FlightLog to JSON - ID: $id, flightTypes: ${flightTypes.length}');
      }

      final result = {
        'id': id,
        'date': date.toIso8601String(),
        'flightTypes': flightTypes.map((e) => _safeEnumName(e)).toList(),
        'durationHours': durationHours,
        'durationMinutes': durationMinutes,
        'aircraftType': aircraftType,
        'pilotRole': _safeEnumName(pilotRole),
        'isDayFlight': isDayFlight,
        'isSimulated': isSimulated,
        'createdAt': createdAt.toIso8601String(),
        'dateUpdated': dateUpdated?.toIso8601String(),
        'registration': registration,
        'departure': departure,
        'arrival': arrival,
        'flightTime': flightTime,
        'picTime': picTime,
        'sicTime': sicTime,
        'nightTime': nightTime,
        'ifrTime': ifrTime,
        'crossCountry': crossCountry,
        'dayLandings': dayLandings,
        'nightLandings': nightLandings,
        'remarks': remarks,
        'updatedAt': updatedAt?.toIso8601String(),
      };

      if (kDebugMode) {
        print('🐛 DEBUG: FlightLog JSON conversion successful');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('💥 DEBUG: Error in FlightLog.toJson(): $e');
        print(
            '💥 DEBUG: FlightLog ID: $id, flightTypes: $flightTypes, pilotRole: $pilotRole');
      }

      // Fallback to basic data if conversion fails
      return {
        'id': id,
        'date': date.toIso8601String(),
        'flightTypes': flightTypes
            .map((e) => e.index)
            .toList(), // Use index instead of name
        'durationHours': durationHours,
        'durationMinutes': durationMinutes,
        'aircraftType': aircraftType,
        'pilotRole': pilotRole.index, // Use index instead of name
        'isDayFlight': isDayFlight,
        'isSimulated': isSimulated,
        'createdAt': createdAt.toIso8601String(),
      };
    }
  }

  static String _safeEnumName(dynamic enumValue) {
    try {
      // Use toString() and extract name after the dot
      // Example: "FlightType.local" -> "local"
      final fullString = enumValue.toString();
      final name = fullString.split('.').last;
      return name;
    } catch (e) {
      if (kDebugMode) {
        print('💥 DEBUG: Error getting enum name: $e, using index instead');
      }
      return enumValue.index.toString();
    }
  }
}

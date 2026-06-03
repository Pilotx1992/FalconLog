import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Stable aircraft type entry (UUID + display name).
class AircraftTypeRecord {
  final String id;
  final String name;

  const AircraftTypeRecord({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory AircraftTypeRecord.fromJson(Map<String, dynamic> json) {
    return AircraftTypeRecord(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  static AircraftTypeRecord fromName(String name, {String? id}) {
    return AircraftTypeRecord(
      id: id ?? const Uuid().v4(),
      name: name.trim(),
    );
  }
}

/// Reads/writes aircraft types with stable UUIDs in SharedPreferences.
class AircraftTypesStorage {
  AircraftTypesStorage._();

  static const String legacyKey = 'aircraftTypes';
  static const String v2Key = 'aircraft_types_v2';

  static List<AircraftTypeRecord> decodeV2Json(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => AircraftTypeRecord.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.id.isNotEmpty && r.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String encodeV2Json(List<AircraftTypeRecord> records) {
    final sorted = [...records]..sort((a, b) => a.name.compareTo(b.name));
    return json.encode(sorted.map((r) => r.toJson()).toList());
  }

  /// Deterministic map for backup: key = record id.
  static Map<String, dynamic> toBackupMap(List<AircraftTypeRecord> records) {
    final map = <String, dynamic>{};
    final sorted = [...records]..sort((a, b) => a.id.compareTo(b.id));
    for (final record in sorted) {
      map[record.id] = record.toJson();
    }
    return map;
  }

  static List<AircraftTypeRecord> fromBackupMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return [];
    final records = <AircraftTypeRecord>[];
    for (final entry in raw.entries) {
      if (entry.value is Map<String, dynamic>) {
        final record = AircraftTypeRecord.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (record.id.isNotEmpty && record.name.isNotEmpty) {
          records.add(record);
        }
      }
    }
    records.sort((a, b) => a.name.compareTo(b.name));
    return records;
  }
}

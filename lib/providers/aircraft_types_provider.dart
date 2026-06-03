import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backup/models/aircraft_type_record.dart';

final aircraftTypesProvider =
    StateNotifierProvider<AircraftTypesNotifier, List<String>>(
  (ref) => AircraftTypesNotifier(),
);

class AircraftTypesNotifier extends StateNotifier<List<String>> {
  static const String key = AircraftTypesStorage.legacyKey;

  AircraftTypesNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    await reload();
  }

  /// Reload from SharedPreferences (e.g. after backup restore).
  Future<void> reload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = await _readRecords(prefs);
      state = records.map((r) => r.name).toList()..sort();
    } catch (e) {
      log('Error loading aircraft types: $e', name: 'AircraftTypesProvider');
      state = [];
    }
  }

  Future<List<AircraftTypeRecord>> _readRecords(SharedPreferences prefs) async {
    final v2 = prefs.getString(AircraftTypesStorage.v2Key);
    if (v2 != null && v2.isNotEmpty) {
      return AircraftTypesStorage.decodeV2Json(v2);
    }
    final legacy = prefs.getStringList(key) ?? [];
    return legacy
        .where((name) => name.trim().isNotEmpty)
        .map((name) => AircraftTypeRecord.fromName(name))
        .toList();
  }

  Future<void> _persist(List<AircraftTypeRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = [...records]..sort((a, b) => a.name.compareTo(b.name));
    await prefs.setString(
      AircraftTypesStorage.v2Key,
      AircraftTypesStorage.encodeV2Json(sorted),
    );
    await prefs.setStringList(
      key,
      sorted.map((r) => r.name).toList(),
    );
    state = sorted.map((r) => r.name).toList();
  }

  Future<void> addAircraftType(String type) async {
    try {
      final trimmed = type.trim();
      if (trimmed.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final records = await _readRecords(prefs);
      if (records.any((r) => r.name.toLowerCase() == trimmed.toLowerCase())) {
        return;
      }

      records.add(AircraftTypeRecord.fromName(trimmed));
      await _persist(records);
    } catch (e) {
      log('Error adding aircraft type: $e', name: 'AircraftTypesProvider');
    }
  }

  Future<void> removeAircraftType(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = await _readRecords(prefs);
      final updated = records
          .where((r) => r.name.toLowerCase() != type.toLowerCase())
          .toList();
      if (updated.length == records.length) return;
      await _persist(updated);
    } catch (e) {
      log('Error removing aircraft type: $e', name: 'AircraftTypesProvider');
    }
  }
}

import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final aircraftTypesProvider =
    StateNotifierProvider<AircraftTypesNotifier, List<String>>(
  (ref) => AircraftTypesNotifier(),
);

class AircraftTypesNotifier extends StateNotifier<List<String>> {
  static const String key = 'aircraftTypes';
  AircraftTypesNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final aircraftTypes = prefs.getStringList(key) ?? [];
      state = aircraftTypes;
    } catch (e) {
      log('Error initializing aircraft types: $e', name: 'AircraftTypesProvider');
      state = [];
    }
  }

  Future<void> addAircraftType(String type) async {
    try {
      if (type.isEmpty || state.contains(type)) return;
      final updated = [...state, type]..sort();
      state = updated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, updated);
    } catch (e) {
      log('Error adding aircraft type: $e', name: 'AircraftTypesProvider');
    }
  }

  Future<void> removeAircraftType(String type) async {
    try {
      if (!state.contains(type)) return;
      final updated = state.where((item) => item != type).toList();
      state = updated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, updated);
    } catch (e) {
      log('Error removing aircraft type: $e', name: 'AircraftTypesProvider');
    }
  }
}

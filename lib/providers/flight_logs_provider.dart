import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/flight_log.dart';

final flightLogsProvider =
    StateNotifierProvider<FlightLogsNotifier, AsyncValue<List<FlightLog>>>(
  (ref) => FlightLogsNotifier(),
);

class FlightLogsNotifier extends StateNotifier<AsyncValue<List<FlightLog>>> {
  static const String boxName = 'flightLogsBox';
  Box<FlightLog>? _box;

  FlightLogsNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Wait for Hive to be fully initialized
      int attempts = 0;
      while (!Hive.isBoxOpen(boxName) && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
        if (attempts % 5 == 0) {
          debugPrint('Waiting for Hive box to be ready... attempt $attempts');
        }
      }
      
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box<FlightLog>(boxName);
        _updateState();
        debugPrint('FlightLogsProvider initialized successfully');
      } else {
        throw Exception('Hive box could not be opened after waiting');
      }
    } catch (e, stack) {
      debugPrint('Error in FlightLogsProvider._init: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  void _updateState() {
    final logs = _box?.values.toList() ?? [];
    // Sort by createdAt in descending order (newest first)
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncValue.data(logs);
  }

  Future<void> addFlightLog(FlightLog log) async {
    try {
      await _box?.put(log.id, log);
      _updateState();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateFlightLog(FlightLog log) async {
    try {
      await _box?.put(log.id, log);
      _updateState();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteFlightLog(String id) async {
    try {
      await _box?.delete(id);
      _updateState();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> restoreFlightLogs(List<FlightLog> logs) async {
    try {
      // Clear all existing logs
      await _box?.clear();
      
      // Add all restored logs
      for (final log in logs) {
        await _box?.put(log.id, log);
      }
      
      _updateState();
      debugPrint('Restored ${logs.length} flight logs');
    } catch (e, stack) {
      debugPrint('Error restoring flight logs: $e');
      state = AsyncValue.error(e, stack);
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/flight_log.dart';
import '../core/services/hive_initialization_service.dart';

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
      // Use centralized Hive service to get or open the box
      _box = await HiveInitializationService.openBox<FlightLog>(
        boxName,
        timeout: const Duration(seconds: 30),
        maxRetries: 3,
      );

      debugPrint(
          'FlightLogsProvider: Box opened successfully with ${_box!.length} logs');
      _updateState();
      debugPrint('FlightLogsProvider initialized successfully');
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

  /// Clear all flight logs from the database
  Future<void> clearAllFlights() async {
    try {
      await _box?.clear();
      _updateState();
      debugPrint('All flight logs cleared');
    } catch (e, stack) {
      debugPrint('Error clearing all flight logs: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refresh the provider by re-reading data from Hive
  /// Useful after external changes to the box (e.g., from backup restore)
  void refresh() {
    debugPrint('FlightLogsProvider: Refreshing data from Hive...');
    _updateState();
    debugPrint(
        'FlightLogsProvider: Refresh complete with ${_box?.length ?? 0} logs');
  }
}

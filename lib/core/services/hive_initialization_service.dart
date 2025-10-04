import 'dart:async';
import 'dart:developer';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/flight_log.dart';
import '../../backup/models/backup_metadata.dart';
import 'hive_migration_service.dart';

/// Centralized Hive initialization service to prevent race conditions
class HiveInitializationService {
  static HiveInitializationService? _instance;
  static final Map<String, Box> _openedBoxes = {};
  static final Map<String, Completer<Box>> _pendingBoxes = {};
  static bool _isInitialized = false;
  static final Completer<void> _initCompleter = Completer<void>();

  HiveInitializationService._();

  /// Get singleton instance
  static HiveInitializationService get instance {
    _instance ??= HiveInitializationService._();
    return _instance!;
  }

  /// Initialize Hive once globally
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    if (_initCompleter.isCompleted) {
      return;
    }

    try {
      log('[HiveInit] Starting Hive initialization...');

      // Initialize Hive Flutter
      await Hive.initFlutter();

      // Register all adapters with proper type IDs
      _registerAdapters();

      _isInitialized = true;
      _initCompleter.complete();

      log('[HiveInit] Hive initialization completed successfully');
    } catch (e, stackTrace) {
      log('[HiveInit] Hive initialization failed: $e');
      log('[HiveInit] Stack trace: $stackTrace');

      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stackTrace);
      }
      rethrow;
    }
  }

  /// Register all Hive adapters with consistent type IDs
  static void _registerAdapters() {
    // Flight Log adapters (existing)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FlightTypeAdapter());
      log('[HiveInit] Registered FlightTypeAdapter with ID 0');
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PilotRoleAdapter());
      log('[HiveInit] Registered PilotRoleAdapter with ID 1');
    }

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FlightLogAdapter());
      log('[HiveInit] Registered FlightLogAdapter with ID 2');
    }

    // Enhanced backup system adapters
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(BackupMetadataAdapter());
      log('[HiveInit] Registered BackupMetadataAdapter with ID 100');
    }

    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(BackupLocationAdapter());
      log('[HiveInit] Registered BackupLocationAdapter with ID 101');
    }

    if (!Hive.isAdapterRegistered(102)) {
      Hive.registerAdapter(BackupHealthAdapter());
      log('[HiveInit] Registered BackupHealthAdapter with ID 102');
    }

    // Add more adapters here as needed with consistent IDs
  }

  /// Safely open a Hive box with timeout and retry logic
  static Future<Box<T>> openBox<T>(
    String name, {
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
  }) async {
    // Wait for initialization to complete
    if (!_isInitialized) {
      await _initCompleter.future;
    }

    // Check if box is already open
    if (_openedBoxes.containsKey(name)) {
      return _openedBoxes[name] as Box<T>;
    }

    // Check if box opening is in progress
    if (_pendingBoxes.containsKey(name)) {
      final box = await _pendingBoxes[name]!.future;
      return box as Box<T>;
    }

    // Start opening the box
    final completer = Completer<Box>();
    _pendingBoxes[name] = completer;

    try {
      log('[HiveInit] Opening box: $name');

      // Try opening with retry logic
      Box<T>? box;
      Exception? lastException;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          // Check if already open (race condition protection)
          if (Hive.isBoxOpen(name)) {
            box = Hive.box<T>(name);
            log('[HiveInit] Box $name was already open (attempt $attempt)');
            break;
          }

          // Open the box with timeout
          box = await Hive.openBox<T>(name).timeout(timeout);
          log('[HiveInit] Successfully opened box: $name (attempt $attempt)');
          break;
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          log('[HiveInit] Attempt $attempt failed for box $name: $e');

          // Check if this is data corruption (null/double cast error)
          if (e.toString().contains(
                  'type \'Null\' is not a subtype of type \'double\'') &&
              name == 'flightLogsBox' &&
              attempt == 1) {
            log('[HiveInit] Detected data corruption in $name, attempting fix...');

            final fixResult =
                await HiveMigrationService.fixCorruptedFlightLogData();
            if (fixResult) {
              log('[HiveInit] Data corruption fix successful, trying to open fresh box...');
              // Try to open the box again after corruption fix
              try {
                box = await Hive.openBox<T>(name).timeout(timeout);
                log('[HiveInit] Successfully opened box after corruption fix: $name');
                break;
              } catch (fixError) {
                log('[HiveInit] Still failed after corruption fix: $fixError');
                lastException = fixError is Exception
                    ? fixError
                    : Exception(fixError.toString());
              }
            } else {
              log('[HiveInit] Data corruption fix failed');
            }
          }

          if (attempt < maxRetries) {
            // Wait before retry with exponential backoff
            await Future.delayed(Duration(milliseconds: 100 * attempt));
          }
        }
      }

      if (box == null) {
        throw lastException ??
            Exception('Failed to open box $name after $maxRetries attempts');
      }

      // Cache the opened box
      _openedBoxes[name] = box;
      completer.complete(box);

      return box;
    } catch (e, stackTrace) {
      log('[HiveInit] Failed to open box $name: $e');
      log('[HiveInit] Stack trace: $stackTrace');

      completer.completeError(e, stackTrace);
      rethrow;
    } finally {
      _pendingBoxes.remove(name);
    }
  }

  /// Get an already opened box (throws if not opened)
  static Box<T> getBox<T>(String name) {
    if (!_openedBoxes.containsKey(name)) {
      throw StateError('Box $name is not open. Call openBox first.');
    }
    return _openedBoxes[name] as Box<T>;
  }

  /// Check if a box is open
  static bool isBoxOpen(String name) {
    return _openedBoxes.containsKey(name) && Hive.isBoxOpen(name);
  }

  /// Close a specific box
  static Future<void> closeBox(String name) async {
    try {
      if (_openedBoxes.containsKey(name)) {
        await _openedBoxes[name]!.close();
        _openedBoxes.remove(name);
        log('[HiveInit] Closed box: $name');
      }
    } catch (e) {
      log('[HiveInit] Error closing box $name: $e');
    }
  }

  /// Close all boxes
  static Future<void> closeAllBoxes() async {
    final futures = <Future>[];

    for (final entry in _openedBoxes.entries) {
      futures.add(entry.value.close().catchError((e) {
        log('[HiveInit] Error closing box ${entry.key}: $e');
      }));
    }

    await Future.wait(futures);
    _openedBoxes.clear();
    log('[HiveInit] All boxes closed');
  }

  /// Get initialization status
  static bool get isInitialized => _isInitialized;

  /// Get list of opened boxes
  static List<String> get openedBoxNames => _openedBoxes.keys.toList();

  /// Reset the service (for testing)
  static Future<void> reset() async {
    await closeAllBoxes();
    _isInitialized = false;
    _instance = null;
    // Note: Cannot reset _initCompleter as Completer can only complete once
  }
}

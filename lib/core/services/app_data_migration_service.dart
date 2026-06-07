import 'dart:developer';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../backup/models/aircraft_type_record.dart';
import '../../models/flight_log.dart';

/// Idempotent startup migrations for stable IDs and schema upgrades.
class AppDataMigrationService {
  AppDataMigrationService._();

  static const String migrationVersionKey =
      'falconlog_app_data_migration_version';
  static const int targetMigrationVersion = 2;

  /// Run before app reads user data. Never clears boxes on failure.
  static Future<void> runMigrationsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(migrationVersionKey) ?? 0;

    if (current >= targetMigrationVersion) {
      return;
    }

    var workingVersion = current;

    if (workingVersion < 1) {
      final ok = await _migrateFlightLogStableIds();
      if (!ok) {
        log('[Migration] Flight log ID migration failed; keeping version $workingVersion');
        return;
      }
      workingVersion = 1;
    }

    if (workingVersion < 2) {
      final ok = await _migrateAircraftTypesToStableIds(prefs);
      if (!ok) {
        log('[Migration] Aircraft type migration failed; keeping version ${workingVersion > 0 ? workingVersion : 0}');
        if (workingVersion > current) {
          await prefs.setInt(migrationVersionKey, workingVersion);
        }
        return;
      }
      workingVersion = 2;
    }

    if (workingVersion >= targetMigrationVersion) {
      final verified = await _verifyMigration();
      if (verified) {
        await prefs.setInt(migrationVersionKey, targetMigrationVersion);
        log('[Migration] Completed at version $targetMigrationVersion');
      } else {
        log('[Migration] Verification failed; not marking complete');
      }
    }
  }

  static Future<bool> _migrateFlightLogStableIds() async {
    try {
      if (!Hive.isBoxOpen('flightLogsBox')) {
        return true;
      }
      final box = Hive.box<FlightLog>('flightLogsBox');
      final keys = box.keys.toList();

      for (final key in keys) {
        final log = box.get(key);
        if (log == null) continue;

        var id = log.id.trim();
        if (id.isEmpty) {
          id = const Uuid().v4();
          log.id = id;
        }

        final storageKey = id;
        if (key.toString() != storageKey) {
          await box.put(storageKey, log);
          if (key.toString() != storageKey) {
            await box.delete(key);
          }
        } else if (log.id != id) {
          await box.put(storageKey, log);
        }
      }
      return true;
    } catch (e, st) {
      log('[Migration] Flight log stable ID error: $e', stackTrace: st);
      return false;
    }
  }

  static Future<bool> _migrateAircraftTypesToStableIds(
    SharedPreferences prefs,
  ) async {
    try {
      if (prefs.containsKey(AircraftTypesStorage.v2Key)) {
        final existing = AircraftTypesStorage.decodeV2Json(
          prefs.getString(AircraftTypesStorage.v2Key),
        );
        if (existing.isNotEmpty &&
            existing.every((r) => r.id.isNotEmpty && r.name.isNotEmpty)) {
          return true;
        }
      }

      final legacy =
          prefs.getStringList(AircraftTypesStorage.legacyKey) ?? <String>[];
      final records = <AircraftTypeRecord>[];
      final seenNames = <String>{};

      for (final name in legacy) {
        final trimmed = name.trim();
        if (trimmed.isEmpty) continue;
        final normalized = trimmed.toLowerCase();
        if (seenNames.contains(normalized)) continue;
        seenNames.add(normalized);
        records.add(AircraftTypeRecord.fromName(trimmed));
      }

      if (records.isEmpty &&
          !prefs.containsKey(AircraftTypesStorage.legacyKey)) {
        return true;
      }

      await prefs.setString(
        AircraftTypesStorage.v2Key,
        AircraftTypesStorage.encodeV2Json(records),
      );

      final names = records.map((r) => r.name).toList()..sort();
      await prefs.setStringList(AircraftTypesStorage.legacyKey, names);
      return true;
    } catch (e, st) {
      log('[Migration] Aircraft type migration error: $e', stackTrace: st);
      return false;
    }
  }

  static Future<bool> _verifyMigration() async {
    try {
      if (Hive.isBoxOpen('flightLogsBox')) {
        final box = Hive.box<FlightLog>('flightLogsBox');
        for (final key in box.keys) {
          final log = box.get(key);
          if (log == null) continue;
          if (log.id.isEmpty || key.toString() != log.id) {
            return false;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final v2 = prefs.getString(AircraftTypesStorage.v2Key);
      if (v2 != null && v2.isNotEmpty) {
        final records = AircraftTypesStorage.decodeV2Json(v2);
        for (final record in records) {
          if (record.id.isEmpty || record.name.isEmpty) {
            return false;
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Test helper: decode migration state without running migrations.
  static int readMigrationVersion(SharedPreferences prefs) {
    return prefs.getInt(migrationVersionKey) ?? 0;
  }

  /// Test helper: run aircraft migration only.
  static Future<bool> migrateAircraftTypesForTest(SharedPreferences prefs) {
    return _migrateAircraftTypesToStableIds(prefs);
  }

  /// Test helper: run flight ID migration only.
  static Future<bool> migrateFlightLogIdsForTest() {
    return _migrateFlightLogStableIds();
  }
}

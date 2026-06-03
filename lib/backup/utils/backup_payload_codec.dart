import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/flight_log.dart';
import '../models/aircraft_type_record.dart';
import '../models/backup_payload_manifest.dart';
import '../models/backup_provider_enum.dart';
import '../models/restore_mode.dart';
import 'app_settings_backup.dart';
import 'backup_provider_preferences.dart';
import 'backup_restore_logic.dart';

/// Build, validate, and apply backup payloads (unit-testable).
class BackupPayloadCodec {
  BackupPayloadCodec._();

  static const String flightLogsKey = 'flight_logs';
  static const String aircraftTypesKey = 'aircraft_types';
  static const String appSettingsKey = 'app_settings';
  static const String manifestKey = 'manifest';

  /// Collections included in a full-app backup (audit SSOT).
  static const List<String> includedCollections = [
    manifestKey,
    appSettingsKey,
    aircraftTypesKey,
    flightLogsKey,
  ];

  static Future<Map<String, dynamic>?> buildPayload({
    required String backupId,
    BackupProvider? providerOverride,
    String? accountEmail,
    String? deviceId,
  }) async {
    try {
      final flightLogsBox = await Hive.openBox<FlightLog>('flightLogsBox');
      final prefs = await SharedPreferences.getInstance();
      final provider = providerOverride ??
          await BackupProviderPreferences.getSelectedProvider();

      final appSettings = await AppSettingsBackup.exportFromPrefs(prefs);
      final aircraftRecords = await _loadAircraftRecords(prefs);
      final aircraftTypesData = AircraftTypesStorage.toBackupMap(aircraftRecords);

      final logs = flightLogsBox.values.toList()
        ..sort(_compareFlightsForExport);

      final flightLogsData = <String, dynamic>{};
      var flightProcessed = 0;
      var flightSkipped = 0;

      for (final log in logs) {
        try {
          flightLogsData[BackupRestoreLogic.storageKeyForFlight(log.id)] =
              log.toJson();
          flightProcessed++;
        } catch (e) {
          flightSkipped++;
          if (kDebugMode) {
            debugPrint('⚠️ Error exporting flight ${log.id}: $e');
          }
        }
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final location = provider == BackupProvider.local ? 'local' : 'cloud';

      final payloadBody = <String, dynamic>{
        appSettingsKey: appSettings,
        aircraftTypesKey: aircraftTypesData,
        flightLogsKey: flightLogsData,
      };

      final flightLogsHash =
          BackupPayloadManifest.computeCollectionHash(flightLogsData);
      final aircraftHash =
          BackupPayloadManifest.computeCollectionHash(aircraftTypesData);
      final settingsHash =
          BackupPayloadManifest.computeCollectionHash(appSettings);
      final fullHash = BackupPayloadManifest.computeFullPayloadHash(payloadBody);

      final manifest = BackupPayloadManifest(
        backupId: backupId,
        schemaVersion: BackupPayloadManifest.currentSchemaVersion,
        backupFormatVersion: BackupPayloadManifest.currentBackupFormatVersion,
        appVersion: packageInfo.version,
        createdAt: DateTime.now().toUtc(),
        provider: provider.name,
        location: location,
        accountEmail: accountEmail,
        deviceId: deviceId ?? accountEmail ?? 'local-device',
        payloadSha256: fullHash,
        flightLogsSha256: flightLogsHash,
        aircraftTypesSha256: aircraftHash,
        appSettingsSha256: settingsHash,
        flightLogCount: flightProcessed,
        skippedLogCount: flightSkipped,
        aircraftTypeCount: aircraftRecords.length,
        appSettingsCount: AppSettingsBackup.countSettings(appSettings),
      );

      return {
        manifestKey: manifest.toJson(),
        ...payloadBody,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('💥 Error building backup payload: $e');
      }
      return null;
    }
  }

  static int _compareFlightsForExport(FlightLog a, FlightLog b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byCreated = a.createdAt.compareTo(b.createdAt);
    if (byCreated != 0) return byCreated;
    return a.id.compareTo(b.id);
  }

  static Future<List<AircraftTypeRecord>> _loadAircraftRecords(
    SharedPreferences prefs,
  ) async {
    final v2 = prefs.getString(AircraftTypesStorage.v2Key);
    if (v2 != null && v2.isNotEmpty) {
      return AircraftTypesStorage.decodeV2Json(v2);
    }
    final legacy = prefs.getStringList(AircraftTypesStorage.legacyKey) ?? [];
    return legacy
        .where((name) => name.trim().isNotEmpty)
        .map((name) => AircraftTypeRecord.fromName(name))
        .toList();
  }

  /// Validates decrypted JSON before any local data is modified.
  static String? validatePayload(Map<String, dynamic> backupData) {
    try {
      if (!backupData.containsKey(flightLogsKey)) {
        return 'Backup payload is missing flight log data.';
      }

      final flightLogsRaw = backupData[flightLogsKey];
      if (flightLogsRaw is! Map) {
        return 'Backup flight log data is invalid.';
      }
      final flightLogs = Map<String, dynamic>.from(flightLogsRaw);

      final manifestJson = backupData[manifestKey];
      if (manifestJson is! Map) {
        return null;
      }
      final manifestMap = Map<String, dynamic>.from(manifestJson);

      final formatError =
          BackupPayloadManifest.validateBackupFormatVersion(manifestMap);
      if (formatError != null) {
        return formatError;
      }

      final schemaError =
          BackupPayloadManifest.validateSchemaVersion(manifestMap);
      if (schemaError != null) {
        return schemaError;
      }

      final entityError = _validateEntitiesForRestore(
        flightLogsData: flightLogs,
        aircraftData: backupData[aircraftTypesKey] is Map<String, dynamic>
            ? backupData[aircraftTypesKey] as Map<String, dynamic>
            : null,
        appSettingsData: backupData[appSettingsKey] is Map<String, dynamic>
            ? backupData[appSettingsKey] as Map<String, dynamic>
            : null,
      );
      if (entityError != null) {
        return entityError;
      }

      if (flightLogs.isEmpty) {
        return null;
      }

      final isLegacy = BackupPayloadManifest.isLegacyManifest(manifestMap);
      if (isLegacy) {
        return null;
      }

      final manifest = BackupPayloadManifest.fromJson(manifestMap);
      final aircraftTypes = backupData[aircraftTypesKey] is Map<String, dynamic>
          ? backupData[aircraftTypesKey] as Map<String, dynamic>
          : <String, dynamic>{};
      final appSettings = backupData[appSettingsKey] is Map<String, dynamic>
          ? backupData[appSettingsKey] as Map<String, dynamic>
          : <String, dynamic>{};

      if (!manifest.verifyPayload(
        flightLogs: flightLogs,
        aircraftTypes: aircraftTypes,
        appSettings: appSettings,
      )) {
        return 'Backup payload checksum does not match manifest. The file may be corrupted.';
      }

      return null;
    } catch (e) {
      return 'Invalid backup payload structure: $e';
    }
  }

  static String? validatePayloadBytes(List<int> databaseBytes) {
    if (databaseBytes.isEmpty) {
      return null;
    }
    try {
      final backupData =
          json.decode(utf8.decode(databaseBytes)) as Map<String, dynamic>;
      return validatePayload(backupData);
    } catch (e) {
      return 'Invalid backup payload structure: $e';
    }
  }

  /// Applies restore in safe order. Replace mode expects caller to snapshot first.
  static Future<BackupRestoreApplyResult> applyPayload({
    required Map<String, dynamic> backupData,
    required RestoreMode mode,
  }) async {
    final flightLogsData =
        backupData[flightLogsKey] as Map<String, dynamic>? ?? {};
    final aircraftData = backupData[aircraftTypesKey] as Map<String, dynamic>?;
    final appSettingsData =
        backupData[appSettingsKey] as Map<String, dynamic>?;

    final parseError = _validateEntitiesForRestore(
      flightLogsData: flightLogsData,
      aircraftData: aircraftData,
      appSettingsData: appSettingsData,
    );
    if (parseError != null) {
      return BackupRestoreApplyResult.failure(parseError);
    }

    final prefs = await SharedPreferences.getInstance();
    final flightLogsBox = await Hive.openBox<FlightLog>('flightLogsBox');

    var restoredFlights = 0;
    var restoredAircraft = 0;
    var restoredSettings = 0;

    final existingFlightIds = mode == RestoreMode.merge
        ? flightLogsBox.values.map((f) => f.id).toSet()
        : <String>{};

    if (mode == RestoreMode.replace) {
      await flightLogsBox.clear();
      await prefs.remove(AircraftTypesStorage.v2Key);
      await prefs.remove(AircraftTypesStorage.legacyKey);
    }

    if (appSettingsData != null) {
      restoredSettings = await AppSettingsBackup.applyToPrefs(
        prefs: prefs,
        bundle: appSettingsData,
        replace: mode == RestoreMode.replace,
      );
      await AppSettingsBackup.finalizeAutoBackupAfterRestore(prefs: prefs);
    }

    if (aircraftData != null && aircraftData.isNotEmpty) {
      restoredAircraft = await _restoreAircraftTypes(
        prefs: prefs,
        backupMap: aircraftData,
        merge: mode == RestoreMode.merge,
      );
    }

    restoredFlights = await _restoreFlightLogs(
      box: flightLogsBox,
      flightLogsData: flightLogsData,
      existingFlightIds: existingFlightIds,
      merge: mode == RestoreMode.merge,
      clearFirst: false,
    );

    final manifestJson = backupData[manifestKey];
    final countError = _verifyRestoredCounts(
      manifestJson:
          manifestJson is Map<String, dynamic> ? manifestJson : null,
      restoredFlights: restoredFlights,
      restoredAircraft: restoredAircraft,
      restoredSettings: restoredSettings,
      mode: mode,
      flightLogsData: flightLogsData,
      aircraftData: aircraftData,
    );

    if (countError != null) {
      return BackupRestoreApplyResult.failure(countError);
    }

    return BackupRestoreApplyResult.success(
      flightLogsRestored: restoredFlights,
      aircraftTypesRestored: restoredAircraft,
      settingsRestored: restoredSettings,
    );
  }

  static Future<int> _restoreAircraftTypes({
    required SharedPreferences prefs,
    required Map<String, dynamic> backupMap,
    required bool merge,
  }) async {
    final incoming = AircraftTypesStorage.fromBackupMap(backupMap);
    if (incoming.isEmpty) return 0;

    final existing = await _loadAircraftRecords(prefs);
    final existingIds = existing.map((r) => r.id).toSet();
    final existingNames =
        existing.map((r) => r.name.toLowerCase()).toSet();

    final merged = merge ? [...existing] : <AircraftTypeRecord>[];
    var added = 0;

    for (final record in incoming) {
      if (merge) {
        if (existingIds.contains(record.id) ||
            existingNames.contains(record.name.toLowerCase())) {
          continue;
        }
      }
      merged.add(record);
      existingIds.add(record.id);
      existingNames.add(record.name.toLowerCase());
      added++;
    }

    final names = merged.map((r) => r.name).toList()..sort();
    await prefs.setString(
      AircraftTypesStorage.v2Key,
      AircraftTypesStorage.encodeV2Json(merged),
    );
    await prefs.setStringList(AircraftTypesStorage.legacyKey, names);
    return added;
  }

  static Future<int> _restoreFlightLogs({
    required Box<FlightLog> box,
    required Map<String, dynamic> flightLogsData,
    required Set<String> existingFlightIds,
    required bool merge,
    required bool clearFirst,
  }) async {
    if (clearFirst) {
      await box.clear();
    }

    var restored = 0;
    final appliedIds = <String>{};

    final sortedEntries = flightLogsData.entries.toList()
      ..sort((a, b) {
        final idA = BackupRestoreLogic.flightIdFromEntryValue(a.value);
        final idB = BackupRestoreLogic.flightIdFromEntryValue(b.value);
        if (idA == null || idB == null) {
          return a.key.compareTo(b.key);
        }
        return idA.compareTo(idB);
      });

    for (final entry in sortedEntries) {
      try {
        final flightLog = entry.value is Map<String, dynamic>
            ? FlightLog.fromJson(
                Map<String, dynamic>.from(entry.value as Map),
              )
            : FlightLog.fromJson(entry.value as Map<String, dynamic>);

        if (flightLog.id.isEmpty) {
          continue;
        }

        if (merge) {
          if (existingFlightIds.contains(flightLog.id) ||
              appliedIds.contains(flightLog.id)) {
            continue;
          }
        }

        await box.put(
          BackupRestoreLogic.storageKeyForFlight(flightLog.id),
          flightLog,
        );
        appliedIds.add(flightLog.id);
        restored++;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error restoring flight ${entry.key}: $e');
        }
      }
    }

    return restored;
  }

  static String? _validateEntitiesForRestore({
    required Map<String, dynamic> flightLogsData,
    Map<String, dynamic>? aircraftData,
    Map<String, dynamic>? appSettingsData,
  }) {
    for (final entry in flightLogsData.entries) {
      try {
        final value = entry.value;
        if (value is! Map) {
          return 'Invalid flight log entry for key ${entry.key}.';
        }
        final flight = FlightLog.fromJson(Map<String, dynamic>.from(value));
        if (flight.id.isEmpty) {
          return 'Flight log is missing a stable id.';
        }
      } catch (e) {
        return 'Invalid flight log in backup: $e';
      }
    }

    if (aircraftData != null) {
      for (final entry in aircraftData.entries) {
        try {
          if (entry.value is! Map) {
            return 'Invalid aircraft type entry for key ${entry.key}.';
          }
          final record = AircraftTypeRecord.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (record.id.isEmpty || record.name.isEmpty) {
            return 'Aircraft type is missing id or name.';
          }
        } catch (e) {
          return 'Invalid aircraft type in backup: $e';
        }
      }
    }

    if (appSettingsData != null) {
      final values = appSettingsData['values'];
      if (values != null && values is! Map) {
        return 'Invalid app settings bundle in backup.';
      }
    }

    return null;
  }

  static String? _verifyRestoredCounts({
    required Map<String, dynamic>? manifestJson,
    required int restoredFlights,
    required int restoredAircraft,
    required int restoredSettings,
    required RestoreMode mode,
    required Map<String, dynamic> flightLogsData,
    Map<String, dynamic>? aircraftData,
  }) {
    if (manifestJson == null) {
      return null;
    }
    if (BackupPayloadManifest.isLegacyManifest(manifestJson)) {
      return null;
    }

    final manifest = BackupPayloadManifest.fromJson(manifestJson);
    if (!manifest.isFullAppFormat) {
      return null;
    }

    if (mode == RestoreMode.replace) {
      if (manifest.flightLogCount > 0 &&
          restoredFlights < manifest.flightLogCount) {
        return 'Restore incomplete: expected ${manifest.flightLogCount} flight logs, restored $restoredFlights.';
      }
    }

    return null;
  }
}

class BackupRestoreApplyResult {
  final bool success;
  final int flightLogsRestored;
  final int aircraftTypesRestored;
  final int settingsRestored;
  final String? error;

  const BackupRestoreApplyResult._({
    required this.success,
    required this.flightLogsRestored,
    required this.aircraftTypesRestored,
    required this.settingsRestored,
    this.error,
  });

  factory BackupRestoreApplyResult.success({
    required int flightLogsRestored,
    int aircraftTypesRestored = 0,
    int settingsRestored = 0,
  }) =>
      BackupRestoreApplyResult._(
        success: true,
        flightLogsRestored: flightLogsRestored,
        aircraftTypesRestored: aircraftTypesRestored,
        settingsRestored: settingsRestored,
      );

  factory BackupRestoreApplyResult.failure(String error) =>
      BackupRestoreApplyResult._(
        success: false,
        flightLogsRestored: 0,
        aircraftTypesRestored: 0,
        settingsRestored: 0,
        error: error,
      );
}

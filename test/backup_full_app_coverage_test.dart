import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falconlog/backup/models/backup_payload_manifest.dart';
import 'package:falconlog/backup/models/aircraft_type_record.dart';
import 'package:falconlog/backup/utils/app_settings_backup.dart';
import 'package:falconlog/backup/utils/backup_payload_codec.dart';
import 'package:falconlog/backup/utils/backup_restore_logic.dart';
import 'package:falconlog/core/services/app_data_migration_service.dart';

void main() {
  group('full app backup payload', () {
    test('included collections match audit', () {
      expect(
        BackupPayloadCodec.includedCollections,
        containsAll([
          'manifest',
          'app_settings',
          'aircraft_types',
          'flight_logs',
        ]),
      );
    });

    test('full payload manifest tracks per-collection counts and checksums',
        () {
      final appSettings = {
        'id': AppSettingsBackup.bundleId,
        'values': {'selected_language': 'en'},
      };
      final aircraftTypes = {
        'ac-1': {'id': 'ac-1', 'name': 'UH-60'},
      };
      final flightLogs = {
        'f-1': {
          'id': 'f-1',
          'date': '2025-01-01T00:00:00.000',
          'flightTypes': ['local'],
          'durationHours': 1,
          'durationMinutes': 0,
          'aircraftType': 'UH-60',
          'pilotRole': 'pic',
          'isDayFlight': true,
          'isSimulated': false,
          'createdAt': '2025-01-01T00:00:00.000',
        },
      };

      final body = {
        'app_settings': appSettings,
        'aircraft_types': aircraftTypes,
        'flight_logs': flightLogs,
      };

      final manifest = BackupPayloadManifest(
        backupId: 'b-1',
        schemaVersion: BackupPayloadManifest.currentSchemaVersion,
        backupFormatVersion: BackupPayloadManifest.currentBackupFormatVersion,
        appVersion: '2.0.0',
        createdAt: DateTime.utc(2025, 6, 1),
        provider: 'googleDrive',
        location: 'cloud',
        payloadSha256: BackupPayloadManifest.computeFullPayloadHash(body),
        flightLogsSha256:
            BackupPayloadManifest.computeCollectionHash(flightLogs),
        aircraftTypesSha256:
            BackupPayloadManifest.computeCollectionHash(aircraftTypes),
        appSettingsSha256:
            BackupPayloadManifest.computeCollectionHash(appSettings),
        flightLogCount: 1,
        aircraftTypeCount: 1,
        appSettingsCount: 1,
      );

      expect(
          manifest.verifyPayload(
            flightLogs: flightLogs,
            aircraftTypes: aircraftTypes,
            appSettings: appSettings,
          ),
          isTrue);

      final corrupted = Map<String, dynamic>.from(flightLogs);
      corrupted['f-1'] = Map<String, dynamic>.from(corrupted['f-1'] as Map)
        ..['durationHours'] = 99;
      expect(
          manifest.verifyPayload(
            flightLogs: corrupted,
            aircraftTypes: aircraftTypes,
            appSettings: appSettings,
          ),
          isFalse);
    });
  });

  group('legacy and format safety', () {
    test('legacy flight-only payload validates without format version', () {
      final payload = {
        'flight_logs': {
          'f-1': {
            'id': 'f-1',
            'date': '2025-01-01T00:00:00.000',
            'flightTypes': ['local'],
            'durationHours': 1,
            'durationMinutes': 0,
            'aircraftType': 'UH-60',
            'pilotRole': 'pic',
            'isDayFlight': true,
            'isSimulated': false,
            'createdAt': '2025-01-01T00:00:00.000',
          },
        },
      };
      expect(BackupPayloadCodec.validatePayload(payload), isNull);
    });

    test('newer backup format fails before restore', () {
      final payload = {
        'manifest': {
          'backup_format_version': '99.0',
          'schema_version': '4.0',
        },
        'flight_logs': {},
      };
      expect(
        BackupPayloadCodec.validatePayload(payload),
        BackupPayloadManifest.newerVersionErrorMessage,
      );
    });

    test('invalid flight id fails validation before data changes', () {
      final payload = {
        'manifest': {
          'backup_format_version': '2.0',
          'schema_version': '4.0',
        },
        'flight_logs': {
          'bad': {
            'id': '',
            'date': '2025-01-01T00:00:00.000',
            'flightTypes': ['local'],
            'durationHours': 1,
            'durationMinutes': 0,
            'aircraftType': 'UH-60',
            'pilotRole': 'pic',
            'isDayFlight': true,
            'isSimulated': false,
            'createdAt': '2025-01-01T00:00:00.000',
          },
        },
      };
      expect(
        BackupPayloadCodec.validatePayload(payload),
        'Flight log is missing a stable id.',
      );
    });
  });

  group('merge duplicate safety', () {
    test('restoring same backup twice adds zero flights in merge', () {
      final backup = {
        'f-1': {
          'id': 'f-1',
          'date': '2025-01-01T00:00:00.000',
          'flightTypes': ['local'],
          'durationHours': 1,
          'durationMinutes': 0,
          'aircraftType': 'UH-60',
          'pilotRole': 'pic',
          'isDayFlight': true,
          'isSimulated': false,
          'createdAt': '2025-01-01T00:00:00.000',
        },
      };
      expect(
        BackupRestoreLogic.isDuplicateSafeMerge(
          backupFlightLogs: backup,
          existingFlightIds: {'f-1'},
        ),
        isTrue,
      );
    });
  });

  group('app data migration', () {
    test('aircraft migration assigns stable ids and is idempotent', () async {
      SharedPreferences.setMockInitialValues({
        AircraftTypesStorage.legacyKey: ['UH-60', 'AH-64', 'UH-60'],
      });
      final prefs = await SharedPreferences.getInstance();

      expect(await AppDataMigrationService.migrateAircraftTypesForTest(prefs),
          isTrue);
      final first = prefs.getString(AircraftTypesStorage.v2Key);
      expect(first, isNotNull);

      final decoded = AircraftTypesStorage.decodeV2Json(first);
      expect(decoded.length, 2);
      expect(decoded.every((r) => r.id.isNotEmpty), isTrue);

      expect(await AppDataMigrationService.migrateAircraftTypesForTest(prefs),
          isTrue);
      expect(prefs.getString(AircraftTypesStorage.v2Key), first);
    });
  });
}

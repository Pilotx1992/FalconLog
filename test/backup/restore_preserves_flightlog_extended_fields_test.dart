import 'dart:convert';
import 'dart:io';

import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/models/restore_mode.dart';
import 'package:falconlog/backup/utils/backup_scheduler.dart';
import 'package:falconlog/backup/utils/backup_payload_codec.dart';
import 'package:falconlog/backup/utils/backup_restore_logic.dart';
import 'package:falconlog/models/flight_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp(
      'falconlog_restore_extended_',
    );
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FlightTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PilotRoleAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FlightLogAdapter());
    }
    SharedPreferences.setMockInitialValues({});
    BackupSchedulerWorkmanager.resetTestHooks();
    BackupSchedulerWorkmanager.cancelByUniqueName = (_) async {};
    BackupSchedulerWorkmanager.cancelByTag = (_) async {};
    BackupSchedulerWorkmanager.isScheduledByUniqueName = (_) async => false;
    BackupSchedulerWorkmanager.registerPeriodicTask =
        (uniqueName, taskName, {
      required frequency,
      required constraints,
      required initialDelay,
      required backoffPolicy,
      required backoffPolicyDelay,
      required existingWorkPolicy,
      String? tag,
    }) async {};
    BackupSchedulerWorkmanager.registerOneOffTask =
        (uniqueName, taskName, {
      required constraints,
      required initialDelay,
      required backoffPolicy,
      required backoffPolicyDelay,
      required existingWorkPolicy,
      String? tag,
    }) async {};
    PackageInfo.setMockInitialValues(
      appName: 'FalconLog',
      packageName: 'com.falconlog.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('restore_preserves_flightlog_extended_fields', () async {
    final original = _fullFlightLog();
    final box = await Hive.openBox<FlightLog>('flightLogsBox');
    await box.put(
      BackupRestoreLogic.storageKeyForFlight(original.id),
      original,
    );

    final payload = await BackupPayloadCodec.buildPayload(
      backupId: 'extended-fields-restore',
      providerOverride: BackupProvider.local,
    );
    expect(payload, isNotNull);
    expect(BackupPayloadCodec.validatePayload(payload!), isNull);

    await box.clear();

    final result = await BackupPayloadCodec.applyPayload(
      backupData: payload,
      mode: RestoreMode.replace,
    );

    expect(result.success, isTrue);
    expect(result.flightLogsRestored, 1);

    final restored = box.get(
      BackupRestoreLogic.storageKeyForFlight(original.id),
    );
    expect(restored, isNotNull);
    _expectSameFlightLog(restored!, original);
  });

  test('backup_payload_round_trip_preserves_extended_flight_log_fields',
      () async {
    final original = _fullFlightLog();
    final box = await Hive.openBox<FlightLog>('flightLogsBox');
    await box.put(
      BackupRestoreLogic.storageKeyForFlight(original.id),
      original,
    );

    final payload = await BackupPayloadCodec.buildPayload(
      backupId: 'extended-fields-backup',
      providerOverride: BackupProvider.local,
    );

    expect(payload, isNotNull);
    final decoded = json.decode(json.encode(payload)) as Map<String, dynamic>;
    expect(BackupPayloadCodec.validatePayload(decoded), isNull);

    final flightLogs =
        Map<String, dynamic>.from(decoded[BackupPayloadCodec.flightLogsKey]);
    final restored = FlightLog.fromJson(
      Map<String, dynamic>.from(flightLogs.values.single as Map),
    );

    _expectSameFlightLog(restored, original);
  });
}

FlightLog _fullFlightLog() {
  return FlightLog(
    id: 'flight-extended-1',
    date: DateTime.utc(2025, 6, 1, 8, 30),
    flightTypes: const [
      FlightType.local,
      FlightType.mission,
      FlightType.lowLevel,
    ],
    durationHours: 2,
    durationMinutes: 45,
    aircraftType: 'AH-64E',
    pilotRole: PilotRole.ip,
    isDayFlight: false,
    isSimulated: true,
    createdAt: DateTime.utc(2025, 5, 20, 10, 11, 12),
    dateUpdated: DateTime.utc(2025, 5, 21, 9, 8, 7),
    registration: 'EG-1234',
    departure: 'HECA',
    arrival: 'HEGN',
    flightTime: 2.75,
    picTime: 1.5,
    sicTime: 1.25,
    nightTime: 0.8,
    ifrTime: 0.4,
    crossCountry: 1.1,
    dayLandings: 2,
    nightLandings: 1,
    remarks: 'NVG currency check with tactical arrival.',
    updatedAt: DateTime.utc(2025, 5, 22, 12, 13, 14),
  );
}

void _expectSameFlightLog(FlightLog actual, FlightLog expected) {
  expect(actual.id, expected.id);
  expect(actual.date, expected.date);
  expect(actual.flightTypes, expected.flightTypes);
  expect(actual.durationHours, expected.durationHours);
  expect(actual.durationMinutes, expected.durationMinutes);
  expect(actual.aircraftType, expected.aircraftType);
  expect(actual.pilotRole, expected.pilotRole);
  expect(actual.isDayFlight, expected.isDayFlight);
  expect(actual.isSimulated, expected.isSimulated);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.dateUpdated, expected.dateUpdated);
  expect(actual.registration, expected.registration);
  expect(actual.departure, expected.departure);
  expect(actual.arrival, expected.arrival);
  expect(actual.flightTime, expected.flightTime);
  expect(actual.picTime, expected.picTime);
  expect(actual.sicTime, expected.sicTime);
  expect(actual.nightTime, expected.nightTime);
  expect(actual.ifrTime, expected.ifrTime);
  expect(actual.crossCountry, expected.crossCountry);
  expect(actual.dayLandings, expected.dayLandings);
  expect(actual.nightLandings, expected.nightLandings);
  expect(actual.remarks, expected.remarks);
  expect(actual.updatedAt, expected.updatedAt);
}

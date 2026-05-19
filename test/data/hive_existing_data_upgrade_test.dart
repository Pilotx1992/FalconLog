import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falconlog/core/services/app_data_migration_service.dart';
import 'package:falconlog/models/flight_log.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('falconlog_hive_upgrade_');
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
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('existing flight logs survive migration and re-open', () async {
    final box = await Hive.openBox<FlightLog>('flightLogsBox');
    final log = FlightLog(
      date: DateTime(2024, 6, 15),
      flightTypes: const [FlightType.local],
      durationHours: 1,
      durationMinutes: 30,
      aircraftType: 'T-6',
      pilotRole: PilotRole.pic,
      isDayFlight: true,
      isSimulated: false,
    );
    await box.put(log.id, log);
    expect(box.length, 1);
    await box.close();

    await AppDataMigrationService.runMigrationsIfNeeded();

    final reopened = await Hive.openBox<FlightLog>('flightLogsBox');
    expect(reopened.length, 1);
    expect(reopened.values.first.aircraftType, 'T-6');
    expect(reopened.values.first.id, log.id);
  });

  test('initialization does not clear a populated flightLogsBox', () async {
    final box = await Hive.openBox<FlightLog>('flightLogsBox');
    await box.put(
      'seed-id',
      FlightLog(
        id: 'seed-id',
        date: DateTime(2023, 1, 1),
        flightTypes: const [FlightType.mission],
        durationHours: 2,
        durationMinutes: 0,
        aircraftType: 'C-130',
        pilotRole: PilotRole.ip,
        isDayFlight: true,
        isSimulated: false,
      ),
    );
    expect(box.length, 1);
    await box.close();

    await AppDataMigrationService.runMigrationsIfNeeded();

    final after = await Hive.openBox<FlightLog>('flightLogsBox');
    expect(after.length, 1);
    expect(after.get('seed-id')?.aircraftType, 'C-130');
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:falconlog/core/services/hive_migration_service.dart';
import 'package:falconlog/models/flight_log.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('falconlog_quarantine_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FlightLogAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('quarantine copies flightLogsBox files without deleting originals',
      () async {
    final original = File('${tempDir.path}/flightLogsBox.hive');
    await original.writeAsBytes([1, 2, 3, 4]);

    final quarantinePath =
        await HiveMigrationService.quarantineCorruptedFlightLogFiles(
            basePathForTests: tempDir.path);

    expect(quarantinePath, isNotNull);
    expect(await original.exists(), isTrue);
    expect(await original.readAsBytes(), [1, 2, 3, 4]);

    final quarantineDir = Directory(quarantinePath!);
    expect(await quarantineDir.exists(), isTrue);
    final copies = quarantineDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('flightLogsBox'));
    expect(copies, isNotEmpty);
  });

  test('quarantine leaves multiple flightLogsBox-related files intact',
      () async {
    final lock = File('${tempDir.path}/flightLogsBox.lock');
    final hive = File('${tempDir.path}/flightLogsBox.hive');
    await lock.writeAsString('lock');
    await hive.writeAsBytes([9, 9, 9]);

    await HiveMigrationService.quarantineCorruptedFlightLogFiles(
      basePathForTests: tempDir.path,
    );

    expect(await lock.exists(), isTrue);
    expect(await hive.exists(), isTrue);
  });
}

import 'dart:io';

import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_provider_preferences.dart';
import 'package:falconlog/backup/utils/backup_scheduler.dart';
import 'package:falconlog/models/flight_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enabledKey = 'falconlog_auto_backup_enabled';
  const frequencyKey = 'falconlog_backup_frequency';
  const wifiKey = 'falconlog_wifi_only';
  const lastBackupKey = 'falconlog_last_backup_time';

  late Directory tempDir;

  setUp(() async {
    BackupSchedulerWorkmanager.resetTestHooks();
    BackupSchedulerWorkmanager.cancelByUniqueName = (_) async {};
    BackupSchedulerWorkmanager.cancelByTag = (_) async {};
    BackupService.startBackupForTesting = null;
    BackupScheduler.backgroundDependenciesInitializer = null;
    BackupScheduler.openFlightLogsBoxForTesting = null;
    SharedPreferences.setMockInitialValues({});

    tempDir = await Directory.systemTemp
        .createTemp('falconlog_scheduler_test_');
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

    final box = await Hive.openBox<FlightLog>('flightLogsBox');
    await box.put(
      'flight-1',
      FlightLog(
        date: DateTime(2025, 1, 1),
        flightTypes: const [FlightType.local],
        durationHours: 1,
        durationMinutes: 0,
        aircraftType: 'T-6',
        pilotRole: PilotRole.pic,
        isDayFlight: true,
        isSimulated: false,
      ),
    );

    BackupScheduler.backgroundDependenciesInitializer = (_) async {};
    BackupScheduler.openFlightLogsBoxForTesting =
        () async => Hive.box<FlightLog>('flightLogsBox');
  });

  tearDown(() async {
    BackupSchedulerWorkmanager.resetTestHooks();
    BackupService.startBackupForTesting = null;
    BackupScheduler.backgroundDependenciesInitializer = null;
    BackupScheduler.openFlightLogsBoxForTesting = null;
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupScheduler.scheduleBackup', () {
    test('enable registers unique periodic task with update policy', () async {
      ExistingPeriodicWorkPolicy? capturedPolicy;

      BackupSchedulerWorkmanager.registerPeriodicTask =
          (uniqueName, taskName,
              {required frequency,
              required constraints,
              required initialDelay,
              required backoffPolicy,
              required backoffPolicyDelay,
              required existingWorkPolicy,
              tag}) async {
        expect(uniqueName, 'falconlog_auto_backup_periodic');
        expect(taskName, 'falconlog_auto_backup');
        capturedPolicy = existingWorkPolicy;
      };

      final scheduler = BackupScheduler();
      final ok = await scheduler.scheduleBackup(
        frequency: 'daily',
        wifiOnly: true,
      );

      expect(ok, isTrue);
      expect(capturedPolicy, ExistingPeriodicWorkPolicy.update);
      expect(
        BackupSchedulerWorkmanager.registerLog,
        contains('falconlog_auto_backup_periodic'),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(enabledKey), isTrue);
      expect(prefs.getString(frequencyKey), 'daily');
    });

    test('disable cancels all known unique names and tag', () async {
      BackupSchedulerWorkmanager.cancelByUniqueName = (name) async {
        BackupSchedulerWorkmanager.cancelLog.add(name);
      };
      BackupSchedulerWorkmanager.cancelByTag = (tag) async {
        BackupSchedulerWorkmanager.cancelLog.add('tag:$tag');
      };

      final scheduler = BackupScheduler();
      await scheduler.scheduleBackup(frequency: 'daily');
      BackupSchedulerWorkmanager.cancelLog.clear();

      await scheduler.scheduleBackup(frequency: 'off');

      expect(
        BackupSchedulerWorkmanager.cancelLog,
        containsAll([
          'falconlog_auto_backup_periodic',
          'falconlog_auto_backup_immediate',
          'falconlog_backup_task',
          'encrypted_local_backup',
          'tag:falconlog_backup',
        ]),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(enabledKey), isFalse);
      expect(prefs.getString(frequencyKey), 'off');
    });

    test('re-enable replaces periodic work without duplicate register names',
        () async {
      final registerCounts = <String, int>{};

      BackupSchedulerWorkmanager.registerPeriodicTask =
          (uniqueName, taskName, {required frequency, required constraints, required initialDelay, required backoffPolicy, required backoffPolicyDelay, required existingWorkPolicy, tag}) async {
        registerCounts[uniqueName] = (registerCounts[uniqueName] ?? 0) + 1;
      };
      BackupSchedulerWorkmanager.cancelByUniqueName = (_) async {};
      BackupSchedulerWorkmanager.cancelByTag = (_) async {};

      final scheduler = BackupScheduler();
      await scheduler.scheduleBackup(frequency: 'weekly');
      await scheduler.scheduleBackup(frequency: 'daily');

      expect(registerCounts['falconlog_auto_backup_periodic'], 2);
      expect(registerCounts.length, 1);
    });
  });

  group('BackupScheduler.restoreSavedSchedule', () {
    test('startup re-registers when enabled but not scheduled', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'weekly',
        wifiKey: true,
      });

      var registerCalls = 0;
      BackupSchedulerWorkmanager.isScheduledByUniqueName = (_) async => false;
      BackupSchedulerWorkmanager.registerPeriodicTask =
          (uniqueName, taskName, {required frequency, required constraints, required initialDelay, required backoffPolicy, required backoffPolicyDelay, required existingWorkPolicy, tag}) async {
        registerCalls++;
      };
      BackupSchedulerWorkmanager.cancelByUniqueName = (_) async {};
      BackupSchedulerWorkmanager.cancelByTag = (_) async {};
      BackupSchedulerWorkmanager.registerOneOffTask =
          (uniqueName, taskName, {required constraints, required initialDelay, required backoffPolicy, required backoffPolicyDelay, required existingWorkPolicy, tag}) async {};

      await BackupScheduler.restoreSavedSchedule();

      expect(registerCalls, 1);
    });

    test('startup cancels work when auto backup disabled in prefs', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: false,
        frequencyKey: 'weekly',
      });

      var cancelCalls = 0;
      BackupSchedulerWorkmanager.cancelByUniqueName = (_) async {
        cancelCalls++;
      };
      BackupSchedulerWorkmanager.cancelByTag = (_) async {
        cancelCalls++;
      };

      await BackupScheduler.restoreSavedSchedule();

      expect(cancelCalls, greaterThan(0));
    });
  });

  group('constraintsForProvider', () {
    test('local backup does not require network', () {
      final constraints = BackupScheduler.constraintsForProvider(
        BackupProvider.local,
        wifiOnly: true,
      );
      expect(constraints.networkType, NetworkType.notRequired);
    });

    test('google drive wifi-only uses unmetered network', () {
      final constraints = BackupScheduler.constraintsForProvider(
        BackupProvider.googleDrive,
        wifiOnly: true,
      );
      expect(constraints.networkType, NetworkType.unmetered);
    });

    test('google drive all networks uses connected', () {
      final constraints = BackupScheduler.constraintsForProvider(
        BackupProvider.googleDrive,
        wifiOnly: false,
      );
      expect(constraints.networkType, NetworkType.connected);
    });
  });

  group('scheduled backup worker', () {
    test('worker calls backup with interactive false', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'daily',
        backupSelectedProviderKey: BackupProvider.local.name,
      });

      bool? interactiveUsed;
      BackupService.startBackupForTesting =
          ({bool interactive = true, BackupProvider? providerOverride}) async {
        interactiveUsed = interactive;
        return true;
      };

      await BackupScheduler().runScheduledBackupForTesting();

      expect(interactiveUsed, isFalse);
    });

    test('failed backup does not update last backup time', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'daily',
        backupSelectedProviderKey: BackupProvider.local.name,
      });

      BackupService.startBackupForTesting =
          ({bool interactive = true, BackupProvider? providerOverride}) async {
        return false;
      };

      await BackupScheduler().runScheduledBackupForTesting();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(lastBackupKey), isNull);
    });

    test('firebase provider exits without invoking backup', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'daily',
        backupSelectedProviderKey: BackupProvider.firebase.name,
      });

      var backupInvoked = false;
      BackupService.startBackupForTesting =
          ({bool interactive = true, BackupProvider? providerOverride}) async {
        backupInvoked = true;
        return true;
      };

      final result = await BackupScheduler().runScheduledBackupForTesting();

      expect(backupInvoked, isFalse);
      expect(result, isTrue);
    });
  });
}

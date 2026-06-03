import 'dart:io';

import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/auto_backup_worker.dart';
import 'package:falconlog/backup/utils/auto_backup_state_store.dart';
import 'package:falconlog/backup/utils/backup_operation_lock.dart';
import 'package:falconlog/backup/utils/auto_backup_work_names.dart';
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
  const lastBackupKey = 'falconlog_last_backup_time';

  late Directory tempDir;
  late Directory lockDir;

  Set<String> activePeriodicNames() {
    return BackupSchedulerWorkmanager.activeUniqueNames
        .where((n) =>
            n == AutoBackupWorkNames.dailyEvaluatorUnique ||
            n == AutoBackupWorkNames.intervalPeriodicUnique)
        .toSet();
  }

  setUp(() async {
    BackupSchedulerWorkmanager.resetTestHooks();
    BackupSchedulerWorkmanager.cancelByUniqueName = (name) async {
      BackupSchedulerWorkmanager.cancelLog.add(name);
      BackupSchedulerWorkmanager.activeUniqueNames.remove(name);
    };
    BackupSchedulerWorkmanager.cancelByTag = (_) async {};
    BackupService.startBackupForTesting = null;
    AutoBackupWorker.networkSatisfiedOverride = (_) async => true;
    BackupScheduler.backgroundDependenciesInitializer = null;
    BackupScheduler.openFlightLogsBoxForTesting = null;
    SharedPreferences.setMockInitialValues({});

    tempDir = await Directory.systemTemp
        .createTemp('falconlog_scheduler_test_');
    lockDir = await Directory.systemTemp
        .createTemp('falconlog_scheduler_lock_');
    BackupOperationLock.baseDirectoryForTesting = lockDir;
    await BackupOperationLock.clearForTesting();
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

    BackupSchedulerWorkmanager.registerPeriodicTask =
        (uniqueName, taskName,
            {required frequency,
            required constraints,
            required initialDelay,
            required backoffPolicy,
            required backoffPolicyDelay,
            required existingWorkPolicy,
            tag}) async {
      BackupSchedulerWorkmanager.registerLog.add(uniqueName);
      BackupSchedulerWorkmanager.activeUniqueNames.add(uniqueName);
    };
    BackupSchedulerWorkmanager.registerOneOffTask =
        (uniqueName, taskName,
            {required constraints,
            required initialDelay,
            required backoffPolicy,
            required backoffPolicyDelay,
            required existingWorkPolicy,
            tag}) async {
      BackupSchedulerWorkmanager.registerLog.add(uniqueName);
    };
  });

  tearDown(() async {
    BackupSchedulerWorkmanager.resetTestHooks();
    BackupService.startBackupForTesting = null;
    AutoBackupWorker.networkSatisfiedOverride = null;
    BackupScheduler.backgroundDependenciesInitializer = null;
    BackupScheduler.openFlightLogsBoxForTesting = null;
    await BackupOperationLock.clearForTesting();
    BackupOperationLock.resetTestOverrides();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await lockDir.exists()) {
      await lockDir.delete(recursive: true);
    }
  });

  group('BackupScheduler.scheduleBackup', () {
    test('daily registers evaluator not interval periodic', () async {
      final scheduler = BackupScheduler();
      final ok = await scheduler.scheduleBackup(
        frequency: 'daily',
        wifiOnly: true,
      );

      expect(ok, isTrue);
      expect(
        BackupSchedulerWorkmanager.registerLog,
        contains(AutoBackupWorkNames.dailyEvaluatorUnique),
      );
      expect(
        BackupSchedulerWorkmanager.registerLog,
        isNot(contains(AutoBackupWorkNames.intervalPeriodicUnique)),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(enabledKey), isTrue);
      expect(prefs.getString(frequencyKey), 'daily');
    });

    test('weekly registers interval periodic not daily evaluator', () async {
      final scheduler = BackupScheduler();
      final ok = await scheduler.scheduleBackup(
        frequency: 'weekly',
        wifiOnly: true,
      );

      expect(ok, isTrue);
      expect(
        BackupSchedulerWorkmanager.registerLog,
        contains(AutoBackupWorkNames.intervalPeriodicUnique),
      );
      expect(
        BackupSchedulerWorkmanager.registerLog,
        isNot(contains(AutoBackupWorkNames.dailyEvaluatorUnique)),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(frequencyKey), 'weekly');
    });

    test('mutual exclusion: never daily and interval periodic together', () async {
      final scheduler = BackupScheduler();
      await scheduler.scheduleBackup(frequency: 'daily');
      expect(activePeriodicNames(), {AutoBackupWorkNames.dailyEvaluatorUnique});

      await scheduler.scheduleBackup(frequency: 'weekly');
      expect(
        activePeriodicNames(),
        {AutoBackupWorkNames.intervalPeriodicUnique},
      );

      await scheduler.scheduleBackup(frequency: 'daily');
      expect(activePeriodicNames(), {AutoBackupWorkNames.dailyEvaluatorUnique});
    });

    test('weekly does not remap frequency to daily', () async {
      SharedPreferences.setMockInitialValues({frequencyKey: 'weekly'});
      final scheduler = BackupScheduler();
      await scheduler.scheduleBackup(frequency: 'weekly');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(frequencyKey), 'weekly');
    });

    test('disable cancels daily and interval unique names', () async {
      final scheduler = BackupScheduler();
      await scheduler.scheduleBackup(frequency: 'daily');
      BackupSchedulerWorkmanager.cancelLog.clear();

      await scheduler.scheduleBackup(frequency: 'off');

      expect(
        BackupSchedulerWorkmanager.cancelLog,
        containsAll([
          AutoBackupWorkNames.dailyEvaluatorUnique,
          AutoBackupWorkNames.catchupUnique,
          AutoBackupWorkNames.intervalPeriodicUnique,
        ]),
      );
    });
  });

  group('daily evaluator worker', () {
    test('evaluator does not invoke startBackup', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'daily',
        backupSelectedProviderKey: BackupProvider.local.name,
      });

      var backupInvoked = false;
      BackupService.startBackupForTesting =
          ({bool interactive = true, BackupProvider? providerOverride}) async {
        backupInvoked = true;
        return true;
      };

      await BackupScheduler().runDailyEvaluatorForTesting();

      expect(backupInvoked, isFalse);
    });

    test('evaluator enqueues catch-up when pending already set', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'daily',
        AutoBackupStateStore.pendingDueDayKey: '2020-01-01',
        backupSelectedProviderKey: BackupProvider.local.name,
      });

      await BackupScheduler().runDailyEvaluatorForTesting();

      expect(
        BackupSchedulerWorkmanager.registerLog,
        contains(AutoBackupWorkNames.catchupUnique),
      );
    });
  });

  group('catch-up worker', () {
    test('commitSuccess uses runDueDay and updates daily success fields', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'daily',
        AutoBackupStateStore.pendingDueDayKey: '2026-06-03',
        backupSelectedProviderKey: BackupProvider.local.name,
      });

      BackupService.startBackupForTesting =
          ({bool interactive = true, BackupProvider? providerOverride}) async {
        expect(interactive, isFalse);
        return true;
      };

      await BackupScheduler().runScheduledBackupForTesting();

      final store = AutoBackupStateStore();
      expect(await store.getLastSuccessDueDay(), '2026-06-03');
      expect(await store.getLastSuccessAt(), isNotNull);
      expect(await store.getPendingDueDay(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getInt(lastBackupKey),
        isNull,
      );
    });

    test('failed backup does not update daily success or last_backup_time', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'daily',
        AutoBackupStateStore.pendingDueDayKey: '2026-06-03',
        backupSelectedProviderKey: BackupProvider.local.name,
      });

      BackupService.startBackupForTesting =
          ({bool interactive = true, BackupProvider? providerOverride}) async {
        return false;
      };

      await BackupScheduler().runScheduledBackupForTesting();

      final store = AutoBackupStateStore();
      expect(await store.getLastSuccessDueDay(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(lastBackupKey), isNull);
    });
  });

  group('interval scheduled backup worker', () {
    test('weekly path invokes backup with interactive false', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'weekly',
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

    test('interval success does not use scheduler updateLastBackupTime', () async {
      SharedPreferences.setMockInitialValues({
        enabledKey: true,
        frequencyKey: 'weekly',
        backupSelectedProviderKey: BackupProvider.local.name,
      });

      BackupService.startBackupForTesting =
          ({bool interactive = true, BackupProvider? providerOverride}) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(lastBackupKey, DateTime.now().millisecondsSinceEpoch);
        return true;
      };

      await BackupScheduler().runScheduledBackupForTesting();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(lastBackupKey), isNotNull);
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
  });
}

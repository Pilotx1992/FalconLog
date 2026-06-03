import 'dart:io';

import 'package:falconlog/backup/models/backup_metadata.dart';
import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/ui/backup_settings_page.dart';
import 'package:falconlog/backup/utils/auto_backup_state_store.dart';
import 'package:falconlog/backup/utils/auto_backup_work_names.dart';
import 'package:falconlog/backup/utils/backup_constants.dart';
import 'package:falconlog/backup/utils/backup_operation_lock.dart';
import 'package:falconlog/backup/utils/backup_provider_preferences.dart';
import 'package:falconlog/backup/utils/backup_scheduler.dart';
import 'package:falconlog/models/flight_log.dart';
import 'package:falconlog/providers/backup_service_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FastBackupHistoryNotifier extends BackupHistoryNotifier {
  _FastBackupHistoryNotifier(super.service);

  @override
  Future<void> refresh() async {
    state = const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory lockDir;

  const dailyStatusLine =
      'Backups are due after 11:59 PM when conditions are met — not at an exact time.';

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_sign_in'),
      (call) async => null,
    );

    tempDir = await Directory.systemTemp.createTemp(
      'falconlog_backup_settings_ui_',
    );
    lockDir = await Directory.systemTemp.createTemp(
      'falconlog_backup_settings_ui_lock_',
    );
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
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(BackupMetadataAdapter());
    }
    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(BackupLocationAdapter());
    }
    if (!Hive.isAdapterRegistered(102)) {
      Hive.registerAdapter(BackupHealthAdapter());
    }
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_sign_in'),
      null,
    );
    BackupOperationLock.resetTestOverrides();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await lockDir.exists()) {
      try {
        await lockDir.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold the lock file briefly after async tests.
      }
    }
  });

  setUp(() async {
    await BackupOperationLock.clearForTesting();

    BackupSchedulerWorkmanager.resetTestHooks();
    BackupSchedulerWorkmanager.cancelByUniqueName = (name) async {
      BackupSchedulerWorkmanager.cancelLog.add(name);
      BackupSchedulerWorkmanager.activeUniqueNames.remove(name);
    };
    BackupSchedulerWorkmanager.cancelByTag = (_) async {};
    BackupSchedulerWorkmanager.isScheduledByUniqueName = (name) async {
      return BackupSchedulerWorkmanager.activeUniqueNames.contains(name);
    };
    BackupSchedulerWorkmanager.registerPeriodicTask =
        (uniqueName, taskName, {
      required frequency,
      required constraints,
      required initialDelay,
      required backoffPolicy,
      required backoffPolicyDelay,
      required existingWorkPolicy,
      String? tag,
    }) async {
      BackupSchedulerWorkmanager.registerLog.add(uniqueName);
      BackupSchedulerWorkmanager.activeUniqueNames.add(uniqueName);
    };
    BackupSchedulerWorkmanager.registerOneOffTask =
        (uniqueName, taskName, {
      required constraints,
      required initialDelay,
      required backoffPolicy,
      required backoffPolicyDelay,
      required existingWorkPolicy,
      String? tag,
    }) async {
      BackupSchedulerWorkmanager.registerLog.add(uniqueName);
    };
    BackupScheduler.backgroundDependenciesInitializer = (_) async {};

    SharedPreferences.setMockInitialValues({
      backupSelectedProviderKey: BackupProvider.local.name,
      BackupConstants.settingsKeys['auto_backup_enabled']!: true,
      BackupConstants.settingsKeys['backup_frequency']!: 'daily',
      BackupConstants.settingsKeys['wifi_only']!: true,
      AutoBackupStateStore.lastSuccessAtKey:
          DateTime(2026, 1, 15, 12, 0).millisecondsSinceEpoch,
    });
    BackupSchedulerWorkmanager.activeUniqueNames.add(
      AutoBackupWorkNames.dailyEvaluatorUnique,
    );
  });

  tearDown(() async {
    BackupSchedulerWorkmanager.resetTestHooks();
    BackupScheduler.backgroundDependenciesInitializer = null;
    if (Hive.isBoxOpen('backupMetadata')) {
      await Hive.box<BackupMetadata>('backupMetadata').clear();
      await Hive.box<BackupMetadata>('backupMetadata').close();
    }
  });

  Future<void> pumpBackupSettingsPage(
    WidgetTester tester, {
    DateTime? lastGoogleDriveBackupTime,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isBackupInProgressProvider.overrideWith((ref) => false),
          isRestoreInProgressProvider.overrideWith((ref) => false),
          backupHistoryProvider.overrideWith(
            (ref) => _FastBackupHistoryNotifier(BackupService()),
          ),
        ],
        child: MaterialApp(
          home: BackupSettingsPage(
            skipInitializeForTesting: true,
            initialBackupFrequencyForTesting: 'daily',
            initialWifiOnlyForTesting: true,
            initialAutoBackupStatusLineForTesting: dailyStatusLine,
            initialLastGoogleDriveBackupTimeForTesting:
                lastGoogleDriveBackupTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auto Backup'), findsOneWidget);
  }

  Finder cellularBackupRow() {
    return find.ancestor(
      of: find.text('Cellular backup'),
      matching: find.byType(InkWell),
    );
  }

  test('backup settings init sequence completes under test hooks', () async {
    final service = BackupService();
    await service.initialize();
    await service.findExistingBackup(provider: BackupProvider.googleDrive);
    final scheduler = BackupScheduler();
    expect(await scheduler.getBackupFrequency(), 'daily');
    expect(await scheduler.isWifiOnly(), isTrue);
    await scheduler.reconcileAndGetBackupStatus();
    await _FastBackupHistoryNotifier(service).refresh();
  });

  testWidgets(
    'daily auto backup shows Cellular backup Switch and no Last backup status',
    (tester) async {
      await pumpBackupSettingsPage(tester);

      expect(find.text('Cellular backup'), findsOneWidget);
      expect(
        find.descendant(
          of: cellularBackupRow(),
          matching: find.byType(Switch),
        ),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNWidgets(2));

      expect(find.textContaining('Last successful backup'), findsNothing);
      expect(find.text('Off — backups run on Wi-Fi only.'), findsNothing);
      expect(find.byKey(const Key('cellular_backup_off')), findsNothing);
      expect(find.byKey(const Key('cellular_backup_on')), findsNothing);
      expect(find.byType(Radio<bool>), findsNothing);

      final statusLine = find.text(dailyStatusLine);
      expect(statusLine, findsOneWidget);
      expect(
        tester.widget<Text>(statusLine).data,
        isNot(contains('Last backup:')),
      );
      expect(find.textContaining('Last backup:'), findsNothing);
    },
  );

  testWidgets(
    'account card still shows Last backup when Google backup metadata exists',
    (tester) async {
      await pumpBackupSettingsPage(
        tester,
        lastGoogleDriveBackupTime: DateTime(2026, 1, 10, 9, 30),
      );

      expect(find.textContaining('Last backup:'), findsOneWidget);
      expect(find.text(dailyStatusLine), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(dailyStatusLine)).data,
        isNot(contains('Last backup:')),
      );
    },
  );
}

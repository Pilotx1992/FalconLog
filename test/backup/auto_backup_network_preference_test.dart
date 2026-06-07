import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/utils/auto_backup_network_preference.dart';
import 'package:falconlog/backup/utils/auto_backup_scheduler.dart';
import 'package:falconlog/backup/utils/backup_constants.dart';
import 'package:falconlog/backup/utils/backup_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoBackupNetworkPreference', () {
    test('default is Cellular backup Off / Wi-Fi only', () {
      expect(AutoBackupNetworkPreference.defaultWifiOnly, isTrue);
      expect(
        AutoBackupNetworkPreference.allowCellularBackup(
          wifiOnly: AutoBackupNetworkPreference.defaultWifiOnly,
        ),
        isFalse,
      );
      expect(BackupConstants.defaultSettings['wifi_only'], isTrue);
    });

    test('wifiOnly true maps to Cellular Off', () {
      expect(
        AutoBackupNetworkPreference.allowCellularBackup(wifiOnly: true),
        isFalse,
      );
      expect(
        AutoBackupNetworkPreference.subtitleFor(allowCellularBackup: false),
        'Off — backups run on Wi-Fi only.',
      );
    });

    test('wifiOnly false maps to Cellular On', () {
      expect(
        AutoBackupNetworkPreference.allowCellularBackup(wifiOnly: false),
        isTrue,
      );
      expect(
        AutoBackupNetworkPreference.subtitleFor(allowCellularBackup: true),
        'On — backups may use Wi-Fi or cellular data.',
      );
    });

    test('round-trip allowCellular <-> wifiOnly', () {
      expect(
        AutoBackupNetworkPreference.wifiOnlyFromAllowCellular(false),
        isTrue,
      );
      expect(
        AutoBackupNetworkPreference.wifiOnlyFromAllowCellular(true),
        isFalse,
      );
    });
  });

  group('WorkManager network constraints', () {
    test('Cellular Off uses unmetered for Google Drive', () {
      final constraints = BackupScheduler.constraintsForProvider(
        BackupProvider.googleDrive,
        wifiOnly: true,
      );
      expect(constraints.networkType, NetworkType.unmetered);
    });

    test('Cellular On uses connected for Google Drive', () {
      final constraints = BackupScheduler.constraintsForProvider(
        BackupProvider.googleDrive,
        wifiOnly: false,
      );
      expect(constraints.networkType, NetworkType.connected);
    });

    test('daily evaluator stays network-free', () {
      final constraints = AutoBackupScheduler.evaluatorConstraints();
      expect(constraints.networkType, NetworkType.notRequired);
    });
  });

  group('catch-up and interval workers', () {
    Constraints? lastOneOffConstraints;
    Constraints? lastPeriodicConstraints;

    setUp(() {
      lastOneOffConstraints = null;
      lastPeriodicConstraints = null;
      BackupSchedulerWorkmanager.resetTestHooks();
      BackupSchedulerWorkmanager.cancelByUniqueName = (_) async {};
      BackupSchedulerWorkmanager.cancelByTag = (_) async {};
      BackupSchedulerWorkmanager.registerPeriodicTask = (
        uniqueName,
        taskName, {
        required frequency,
        required constraints,
        required initialDelay,
        required backoffPolicy,
        required backoffPolicyDelay,
        required existingWorkPolicy,
        String? tag,
      }) async {
        lastPeriodicConstraints = constraints;
        BackupSchedulerWorkmanager.registerLog.add(uniqueName);
      };
      BackupSchedulerWorkmanager.registerOneOffTask = (
        uniqueName,
        taskName, {
        required constraints,
        required initialDelay,
        required backoffPolicy,
        required backoffPolicyDelay,
        required existingWorkPolicy,
        String? tag,
      }) async {
        lastOneOffConstraints = constraints;
        BackupSchedulerWorkmanager.registerLog.add(uniqueName);
      };
      SharedPreferences.setMockInitialValues({
        'falconlog_selected_backup_provider': BackupProvider.googleDrive.name,
      });
    });

    tearDown(BackupSchedulerWorkmanager.resetTestHooks);

    test('daily catch-up respects Cellular Off', () async {
      await AutoBackupScheduler().registerCatchup(
        provider: BackupProvider.googleDrive,
        wifiOnly: true,
      );
      expect(lastOneOffConstraints?.networkType, NetworkType.unmetered);
    });

    test('daily catch-up respects Cellular On', () async {
      await AutoBackupScheduler().registerCatchup(
        provider: BackupProvider.googleDrive,
        wifiOnly: false,
      );
      expect(lastOneOffConstraints?.networkType, NetworkType.connected);
    });

    test('weekly interval respects Cellular Off', () async {
      final scheduler = BackupScheduler();
      await scheduler.scheduleBackup(frequency: 'weekly', wifiOnly: true);
      expect(lastPeriodicConstraints?.networkType, NetworkType.unmetered);
    });

    test('monthly interval respects Cellular On', () async {
      final scheduler = BackupScheduler();
      await scheduler.scheduleBackup(frequency: 'monthly', wifiOnly: false);
      expect(lastPeriodicConstraints?.networkType, NetworkType.connected);
    });
  });

  group('BackupScheduler.isWifiOnly', () {
    test('missing pref defaults to Cellular Off', () async {
      SharedPreferences.setMockInitialValues({});
      final scheduler = BackupScheduler();
      expect(await scheduler.isWifiOnly(), isTrue);
    });

    test('persisted wifiOnly false reads Cellular On', () async {
      SharedPreferences.setMockInitialValues({
        BackupConstants.settingsKeys['wifi_only']!: false,
      });
      final scheduler = BackupScheduler();
      expect(await scheduler.isWifiOnly(), isFalse);
    });
  });
}

import 'package:falconlog/backup/utils/auto_backup_reconciler.dart';
import 'package:falconlog/backup/utils/auto_backup_state_store.dart';
import 'package:falconlog/backup/utils/auto_backup_work_names.dart';
import 'package:falconlog/backup/utils/backup_constants.dart';
import 'package:falconlog/backup/utils/backup_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BackupSchedulerWorkmanager.resetTestHooks();
    BackupSchedulerWorkmanager.cancelByUniqueName = (name) async {
      BackupSchedulerWorkmanager.cancelLog.add(name);
    };
    BackupSchedulerWorkmanager.cancelByTag = (_) async {};
    BackupSchedulerWorkmanager.isScheduledByUniqueName = (_) async => false;
    BackupSchedulerWorkmanager.cancelByTag = (_) async {};
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
      BackupSchedulerWorkmanager.registerLog.add(uniqueName);
    };
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
      BackupSchedulerWorkmanager.registerLog.add(uniqueName);
    };
  });

  tearDown(BackupSchedulerWorkmanager.resetTestHooks);

  test(
      'pending with stale waiting_for_wifi clears failure and enqueues catch-up',
      () async {
    SharedPreferences.setMockInitialValues({
      BackupConstants.settingsKeys['auto_backup_enabled']!: true,
      BackupConstants.settingsKeys['backup_frequency']!: 'daily',
      BackupConstants.settingsKeys['wifi_only']!: true,
      AutoBackupStateStore.pendingDueDayKey: '2026-06-03',
      AutoBackupStateStore.lastFailureReasonKey: 'waiting_for_wifi',
    });

    await AutoBackupReconciler(
      conditionsSatisfiableForTesting: ({required bool wifiOnly}) async => true,
    ).reconcile();

    expect(
      BackupSchedulerWorkmanager.registerLog,
      contains(AutoBackupWorkNames.catchupUnique),
    );
    final store = AutoBackupStateStore();
    expect(await store.getLastFailureReason(), isNull);
    expect(await store.getPendingDueDay(), isNotNull);
  });
}

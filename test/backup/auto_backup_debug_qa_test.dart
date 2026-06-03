import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/utils/auto_backup_debug_qa.dart';
import 'package:falconlog/backup/utils/auto_backup_due_engine.dart';
import 'package:falconlog/backup/utils/auto_backup_state_store.dart';
import 'package:falconlog/backup/utils/backup_provider_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      backupSelectedProviderKey: BackupProvider.local.name,
    });
  });

  test('setDueTimeToNowPlusMinutes sets due minute from clock', () async {
    final before = DateTime.now().add(const Duration(minutes: 2));
    await AutoBackupDebugQa.setDueTimeToNowPlusMinutes(2);
    final minute = await AutoBackupStateStore().getDueMinuteOfDay();
    final expectedMinute = before.hour * 60 + before.minute;
    expect((minute - expectedMinute).abs(), lessThanOrEqualTo(1));
  });

  test('snapshotState includes required QA fields', () async {
    SharedPreferences.setMockInitialValues({
      'falconlog_auto_backup_enabled': true,
      'falconlog_backup_frequency': 'daily',
      'falconlog_wifi_only': true,
      backupSelectedProviderKey: BackupProvider.googleDrive.name,
    });
    final snapshot = await AutoBackupDebugQa.snapshotState();
    expect(snapshot['auto_backup_enabled'], 'true');
    expect(snapshot['frequency'], 'daily');
    expect(snapshot['wifi_only'], 'true');
    expect(snapshot['selected_provider'], 'googleDrive');
    expect(snapshot.containsKey('pending_due_day'), isTrue);
    expect(snapshot.containsKey('last_attempt_at'), isTrue);
  });

  test('clearDailyAutoBackupState removes daily tracking keys', () async {
    SharedPreferences.setMockInitialValues({
      AutoBackupStateStore.pendingDueDayKey: '2026-06-03',
      AutoBackupStateStore.lastSuccessDueDayKey: '2026-06-02',
      AutoBackupStateStore.lastSuccessAtKey: 1,
      AutoBackupStateStore.lastAttemptAtKey: 2,
      AutoBackupStateStore.lastFailureReasonKey: 'wifi',
    });
    await AutoBackupDebugQa.clearDailyAutoBackupState();
    final store = AutoBackupStateStore();
    expect(await store.getPendingDueDay(), isNull);
    expect(await store.getLastSuccessDueDay(), isNull);
    expect(await store.getLastSuccessAt(), isNull);
    expect(await store.getLastAttemptAt(), isNull);
    expect(await store.getLastFailureReason(), isNull);
  });

  test('resetDueToProductionDefault restores 23:59', () async {
    await AutoBackupStateStore().setDueMinuteOfDay(120);
    await AutoBackupDebugQa.resetDueToProductionDefault();
    final minute = await AutoBackupStateStore().getDueMinuteOfDay();
    expect(minute, AutoBackupDueEngine.defaultDueMinuteOfDay);
  });
}

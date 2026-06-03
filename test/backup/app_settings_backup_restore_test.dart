import 'package:falconlog/backup/utils/app_settings_backup.dart';
import 'package:falconlog/backup/utils/auto_backup_due_engine.dart';
import 'package:falconlog/backup/utils/auto_backup_state_store.dart';
import 'package:falconlog/backup/utils/backup_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsBackup restore sanitization', () {
    test('export does not include auto-backup runtime state', () async {
      SharedPreferences.setMockInitialValues({
        'falconlog_auto_backup_enabled': true,
        'falconlog_backup_frequency': 'daily',
        AutoBackupStateStore.pendingDueDayKey: '2026-06-03',
        AutoBackupStateStore.lastFailureReasonKey: 'waiting_for_wifi',
        AutoBackupStateStore.lastAttemptAtKey: 1,
      });
      final prefs = await SharedPreferences.getInstance();
      final bundle = await AppSettingsBackup.exportFromPrefs(prefs);
      final values = bundle['values'] as Map<String, dynamic>;
      expect(values.containsKey(AutoBackupStateStore.pendingDueDayKey), isFalse);
      expect(
        values.containsKey(AutoBackupStateStore.lastFailureReasonKey),
        isFalse,
      );
      expect(values.containsKey(AutoBackupStateStore.lastAttemptAtKey), isFalse);
      expect(values['falconlog_auto_backup_enabled'], isTrue);
      expect(values['falconlog_backup_frequency'], 'daily');
    });

    test('applyToPrefs ignores pending and failure from bundle', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await AppSettingsBackup.applyToPrefs(
        prefs: prefs,
        bundle: {
          'values': {
            'falconlog_auto_backup_enabled': true,
            'falconlog_backup_frequency': 'daily',
            AutoBackupStateStore.pendingDueDayKey: '2026-06-03',
            AutoBackupStateStore.lastFailureReasonKey: 'waiting_for_wifi',
          },
        },
        replace: true,
      );
      expect(prefs.getString(AutoBackupStateStore.pendingDueDayKey), isNull);
      expect(
        prefs.getString(AutoBackupStateStore.lastFailureReasonKey),
        isNull,
      );
      expect(prefs.getBool('falconlog_auto_backup_enabled'), isTrue);
      expect(prefs.getString('falconlog_backup_frequency'), 'daily');
    });

    test('sanitizeRestoredDueMinute keeps 1439 only', () {
      expect(
        AppSettingsBackup.sanitizeRestoredDueMinute(1439),
        AutoBackupDueEngine.defaultDueMinuteOfDay,
      );
      expect(
        AppSettingsBackup.sanitizeRestoredDueMinute(160),
        AutoBackupDueEngine.defaultDueMinuteOfDay,
      );
    });

    test('applyToPrefs sanitizes debug due_minute to 1439', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await AppSettingsBackup.applyToPrefs(
        prefs: prefs,
        bundle: {
          'values': {
            AutoBackupStateStore.dueMinuteKey: 160,
          },
        },
        replace: true,
      );
      expect(
        prefs.getInt(AutoBackupStateStore.dueMinuteKey),
        AutoBackupDueEngine.defaultDueMinuteOfDay,
      );
    });

    test('clearAutoBackupRuntimeAfterRestore clears runtime state', () async {
      SharedPreferences.setMockInitialValues({
        'falconlog_auto_backup_enabled': true,
        'falconlog_backup_frequency': 'daily',
        AutoBackupStateStore.pendingDueDayKey: '2026-06-03',
        AutoBackupStateStore.lastFailureReasonKey: 'waiting_for_wifi',
        AutoBackupStateStore.lastSuccessDueDayKey: '2026-06-02',
        AutoBackupStateStore.lastSuccessAtKey: 100,
        AutoBackupStateStore.qaSimulateWifiUnavailableKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await AppSettingsBackup.clearAutoBackupRuntimeAfterRestore(prefs: prefs);
      expect(prefs.getString(AutoBackupStateStore.pendingDueDayKey), isNull);
      expect(
        prefs.getString(AutoBackupStateStore.lastFailureReasonKey),
        isNull,
      );
      expect(prefs.getString(AutoBackupStateStore.lastSuccessDueDayKey), isNull);
      expect(prefs.getBool('falconlog_auto_backup_enabled'), isTrue);
    });

    test('manual last_backup_time does not imply auto last_success_at', () async {
      SharedPreferences.setMockInitialValues({
        BackupConstants.settingsKeys['last_backup_time']!: 999,
      });
      final store = AutoBackupStateStore();
      expect(await store.getLastSuccessAt(), isNull);
      expect(await store.getLastSuccessDueDay(), isNull);
    });

    test('restore preserves cellular backup preference', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await AppSettingsBackup.applyToPrefs(
        prefs: prefs,
        bundle: {
          'values': {
            'falconlog_wifi_only': false,
          },
        },
        replace: true,
      );
      expect(prefs.getBool('falconlog_wifi_only'), isFalse);
    });

    test('restore defaults to Cellular Off when wifi_only absent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await AppSettingsBackup.applyToPrefs(
        prefs: prefs,
        bundle: {
          'values': {
            'falconlog_auto_backup_enabled': true,
          },
        },
        replace: true,
      );
      expect(prefs.containsKey('falconlog_wifi_only'), isFalse);
    });
  });
}

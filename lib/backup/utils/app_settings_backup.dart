import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/legacy_auth_credential_cleanup.dart';
import '../../notifications/domain/notification_preferences.dart';
import '../../notifications/schedulers/currency_expiry_scheduler.dart';
import '../../settings/currency_alert_settings.dart';
import 'auto_backup_due_engine.dart';
import 'auto_backup_reconciler.dart';
import 'auto_backup_state_store.dart';
import 'backup_provider_preferences.dart' show backupSelectedProviderKey;

/// Non-secret app preferences included in full-app backups.
class AppSettingsBackup {
  AppSettingsBackup._();

  static const String bundleId = 'falconlog-app-settings-v1';

  /// Keys never included in backups (credentials / secrets).
  static const Set<String> excludedFromBackupKeys = {
    ...LegacyAuthCredentialKeys.unsafePlaintextCredentialKeys,
    'remember_me',
  };

  /// User preferences safe to restore on a new device.
  static const List<String> preferenceKeys = [
    'selected_language',
    'falconlog_auto_backup_enabled',
    'falconlog_backup_frequency',
    'falconlog_wifi_only',
    AutoBackupStateStore.dueMinuteKey,
    'falconlog_auto_verification_enabled',
    'falconlog_verification_frequency',
    'falconlog_verification_wifi_only',
    backupSelectedProviderKey,
    'prefer_google_signin',
    'falconlog_max_backups',
    CurrencyAlertSettings.prefKeyDayAlertDays,
    CurrencyAlertSettings.prefKeyNightAlertDays,
    CurrencyAlertSettings.prefKeySetupCompleted,
    ...NotificationPreferences.backupablePreferenceKeys,
  ];

  /// Legacy export list kept for tests — preferences only, no runtime state.
  static const List<String> backupableKeys = preferenceKeys;

  static Future<Map<String, dynamic>> exportFromPrefs(
    SharedPreferences prefs,
  ) async {
    final values = <String, dynamic>{};
    for (final key in preferenceKeys) {
      if (excludedFromBackupKeys.contains(key)) continue;
      final value = _readValue(prefs, key);
      if (value != null) {
        values[key] = value;
      }
    }
    return {
      'id': bundleId,
      'values': values,
    };
  }

  static dynamic _readValue(SharedPreferences prefs, String key) {
    if (!prefs.containsKey(key)) return null;
    final value = prefs.get(key);
    if (value is bool || value is int || value is double || value is String) {
      return value;
    }
    if (value is List<String>) {
      return value;
    }
    return value?.toString();
  }

  static Future<int> applyToPrefs({
    required SharedPreferences prefs,
    required Map<String, dynamic> bundle,
    required bool replace,
  }) async {
    final values = bundle['values'];
    if (values is! Map) return 0;

    var applied = 0;
    for (final entry in values.entries) {
      final key = entry.key.toString();
      if (!preferenceKeys.contains(key) ||
          excludedFromBackupKeys.contains(key) ||
          AutoBackupStateStore.deviceLocalRuntimeKeys.contains(key)) {
        continue;
      }

      if (!replace && prefs.containsKey(key)) {
        continue;
      }

      final value = entry.value;
      if (key == AutoBackupStateStore.dueMinuteKey && value is int) {
        await prefs.setInt(key, sanitizeRestoredDueMinute(value));
        applied++;
        continue;
      }

      if (value is bool) {
        await prefs.setBool(key, value);
        applied++;
      } else if (value is int) {
        await prefs.setInt(key, value);
        applied++;
      } else if (value is double) {
        await prefs.setDouble(key, value);
        applied++;
      } else if (value is String) {
        await prefs.setString(key, value);
        applied++;
      } else if (value is List) {
        await prefs.setStringList(
          key,
          value.map((e) => e.toString()).toList(),
        );
        applied++;
      }
    }
    return applied;
  }

  /// Only production default due minute is portable across devices.
  static int sanitizeRestoredDueMinute(int minute) {
    if (minute == AutoBackupDueEngine.defaultDueMinuteOfDay) {
      return minute;
    }
    return AutoBackupDueEngine.defaultDueMinuteOfDay;
  }

  /// After restore: drop transient auto-backup runtime state and re-align WM.
  static Future<void> clearAutoBackupRuntimeAfterRestore({
    SharedPreferences? prefs,
  }) async {
    final resolved = prefs ?? await SharedPreferences.getInstance();
    for (final key in AutoBackupStateStore.deviceLocalRuntimeKeys) {
      await resolved.remove(key);
    }
    await AutoBackupStateStore(prefs: resolved).clearDailyAutoBackupState();
    if (resolved.containsKey(AutoBackupStateStore.dueMinuteKey)) {
      final minute = resolved.getInt(AutoBackupStateStore.dueMinuteKey)!;
      await resolved.setInt(
        AutoBackupStateStore.dueMinuteKey,
        sanitizeRestoredDueMinute(minute),
      );
    }
  }

  static Future<void> finalizeAutoBackupAfterRestore({
    SharedPreferences? prefs,
  }) async {
    await clearAutoBackupRuntimeAfterRestore(prefs: prefs);
    await AutoBackupReconciler().reconcile();
    await CurrencyExpiryScheduler.rescheduleFromHive(allowShowNow: false);
  }

  static int countSettings(Map<String, dynamic>? bundle) {
    if (bundle == null) return 0;
    final values = bundle['values'];
    if (values is Map) return values.length;
    return 0;
  }
}

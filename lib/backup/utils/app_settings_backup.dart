import 'package:shared_preferences/shared_preferences.dart';

import 'backup_provider_preferences.dart' show backupSelectedProviderKey;

/// Non-secret app preferences included in full-app backups.
class AppSettingsBackup {
  AppSettingsBackup._();

  static const String bundleId = 'falconlog-app-settings-v1';

  /// Keys safe to restore on a new device (no credentials).
  static const List<String> backupableKeys = [
    'selected_language',
    'falconlog_auto_backup_enabled',
    'falconlog_backup_frequency',
    'falconlog_wifi_only',
    'falconlog_auto_verification_enabled',
    'falconlog_verification_frequency',
    'falconlog_verification_wifi_only',
    backupSelectedProviderKey,
    'prefer_google_signin',
    'falconlog_max_backups',
  ];

  static Future<Map<String, dynamic>> exportFromPrefs(
    SharedPreferences prefs,
  ) async {
    final values = <String, dynamic>{};
    for (final key in backupableKeys) {
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
      if (!backupableKeys.contains(key)) continue;

      if (!replace && prefs.containsKey(key)) {
        continue;
      }

      final value = entry.value;
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

  static int countSettings(Map<String, dynamic>? bundle) {
    if (bundle == null) return 0;
    final values = bundle['values'];
    if (values is Map) return values.length;
    return 0;
  }
}

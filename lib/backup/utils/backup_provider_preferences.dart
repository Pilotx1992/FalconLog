import 'package:shared_preferences/shared_preferences.dart';

import '../models/backup_provider_enum.dart';
import 'backup_constants.dart';
import 'backup_scheduler.dart';

/// Persisted key for the active backup destination.
const String backupSelectedProviderKey = 'falconlog_selected_backup_provider';

/// Reads/writes the selected backup provider from SharedPreferences.
class BackupProviderPreferences {
  BackupProviderPreferences._();

  static Future<BackupProvider> getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(backupSelectedProviderKey);
    return BackupProvider.values.firstWhere(
      (provider) => provider.name == saved,
      orElse: () => BackupProvider.googleDrive,
    );
  }

  static Future<void> setSelectedProvider(BackupProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(backupSelectedProviderKey, provider.name);
  }

  /// Re-registers WorkManager when auto backup is on and schedule settings exist.
  static Future<void> rescheduleIfAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
            false;
    final frequency =
        prefs.getString(BackupConstants.settingsKeys['backup_frequency']!) ??
            'off';

    if (!enabled || frequency == 'off') {
      return;
    }

    final wifiOnly =
        prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ?? true;

    await BackupScheduler().scheduleBackup(
      frequency: frequency,
      wifiOnly: wifiOnly,
    );
  }
}

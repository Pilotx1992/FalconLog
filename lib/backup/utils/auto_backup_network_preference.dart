/// Maps persisted [wifiOnly] storage to the Cellular backup user setting.
///
/// Wi-Fi is always allowed. Cellular backup controls whether mobile data may
/// be used for automatic backups.
class AutoBackupNetworkPreference {
  AutoBackupNetworkPreference._();

  /// Default for new installs: Cellular backup Off (Wi-Fi only).
  static const bool defaultWifiOnly = true;

  /// Cellular backup Off => Wi-Fi/unmetered only.
  static bool allowCellularBackup({required bool wifiOnly}) => !wifiOnly;

  /// Persisted value for Cellular backup Off/On.
  static bool wifiOnlyFromAllowCellular(bool allowCellularBackup) =>
      !allowCellularBackup;

  static String subtitleFor({required bool allowCellularBackup}) {
    if (allowCellularBackup) {
      return 'On — backups may use Wi-Fi or cellular data.';
    }
    return 'Off — backups run on Wi-Fi only.';
  }
}

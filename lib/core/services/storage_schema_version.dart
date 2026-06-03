/// Tracks on-disk storage layout for backward-compatible upgrades.
///
/// Hive boxes remain plaintext in v1. App lock protects the UI only.
/// Future encrypted-Hive migration must bump [currentVersion] only after
/// a verified, resumable migration path is implemented and tested.
class StorageSchemaVersion {
  StorageSchemaVersion._();

  static const String prefsKey = 'falconlog_storage_schema_version';

  /// Plaintext Hive + existing backup formats (current production layout).
  static const int currentVersion = 1;
}

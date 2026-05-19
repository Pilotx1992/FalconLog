import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import 'storage_schema_version.dart';

/// Records storage layout version for future encrypted-Hive migration.
///
/// v1 (current): plaintext Hive boxes, existing backup formats unchanged.
/// App lock protects UI only; see docs/SECURITY_AND_STORAGE.md when present.
class StorageMigrationService {
  StorageMigrationService._();

  /// Idempotent: marks current install as schema v1 if unset.
  static Future<void> ensureCurrentSchemaRecorded() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(StorageSchemaVersion.prefsKey);
    if (stored == null) {
      await prefs.setInt(
        StorageSchemaVersion.prefsKey,
        StorageSchemaVersion.currentVersion,
      );
      log(
        '[StorageMigration] Recorded schema v${StorageSchemaVersion.currentVersion}',
      );
    }
  }
}

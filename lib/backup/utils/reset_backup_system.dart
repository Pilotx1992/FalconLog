import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import '../services/google_drive_service.dart';
import '../models/backup_metadata.dart';

/// Utility to completely reset the backup system
/// Use this when you want to start fresh with a new backup system
class ResetBackupSystem {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// Reset everything - backups, keys, metadata
  /// WARNING: This will delete ALL backups from Google Drive!
  static Future<bool> resetEverything(GoogleDriveService driveService) async {
    try {
      if (kDebugMode) {
        print('🗑️ Starting complete backup system reset...');
      }

      // Step 1: Delete all backups from Google Drive
      if (kDebugMode) {
        print('☁️ Deleting backups from Google Drive...');
      }

      final backups = await driveService.listFiles(query: "name contains 'falconlog_backup_'");
      int deletedCount = 0;

      for (final backup in backups) {
        if (backup.id != null) {
          try {
            final success = await driveService.deleteFile(backup.id!);
            if (success) {
              deletedCount++;
              if (kDebugMode) {
                print('  ✅ Deleted: ${backup.name}');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('  ⚠️ Failed to delete ${backup.name}: $e');
            }
          }
        }
      }

      if (kDebugMode) {
        print('☁️ Deleted $deletedCount backups from Google Drive');
      }

      // Step 2: Clear all encryption keys from secure storage
      if (kDebugMode) {
        print('🔑 Clearing encryption keys...');
      }

      await _clearAllKeys();

      // Step 3: Clear backup metadata from Hive
      if (kDebugMode) {
        print('📦 Clearing backup metadata...');
      }

      await _clearBackupMetadata();

      if (kDebugMode) {
        print('✅ Backup system reset complete!');
        print('   You can now create new backups with the new system.');
      }

      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('💥 Error resetting backup system: $e');
        print('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Clear all encryption keys from secure storage
  static Future<void> _clearAllKeys() async {
    final keysToDelete = [
      // New system keys
      'falconlog_master_key_v3',

      // Old system keys
      'falconlog_backup_master_key',
      'falconlog_backup_salt',
      'falconlog_backup_key_version',
      'falconlog_backup_key_file_id',

      // Very old system keys
      'backup_master_key_v2',
      'backup_salt_v2',
      'key_rotation_counter',
    ];

    for (final key in keysToDelete) {
      try {
        await _secureStorage.delete(key: key);
        if (kDebugMode) {
          print('  🔑 Deleted key: $key');
        }
      } catch (e) {
        if (kDebugMode) {
          print('  ⚠️ Failed to delete key $key: $e');
        }
      }
    }
  }

  /// Clear backup metadata from Hive
  static Future<void> _clearBackupMetadata() async {
    try {
      final box = await Hive.openBox<BackupMetadata>('backupMetadata');
      final count = box.length;
      await box.clear();
      if (kDebugMode) {
        print('  📦 Cleared $count backup metadata entries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('  ⚠️ Failed to clear backup metadata: $e');
      }
    }
  }

  /// Check current backup system status
  static Future<Map<String, dynamic>> getStatus(GoogleDriveService driveService) async {
    try {
      // Count cloud backups
      final cloudBackups = await driveService.listFiles(query: "name contains 'falconlog_backup_'");

      // Count local metadata
      final metadataBox = await Hive.openBox<BackupMetadata>('backupMetadata');
      final localMetadata = metadataBox.length;

      // Check for stored keys
      final hasOldKey = await _secureStorage.read(key: 'falconlog_backup_master_key') != null;
      final hasNewKey = await _secureStorage.read(key: 'falconlog_master_key_v3') != null;
      final hasVeryOldKey = await _secureStorage.read(key: 'backup_master_key_v2') != null;

      return {
        'cloud_backups': cloudBackups.length,
        'local_metadata': localMetadata,
        'has_old_key': hasOldKey,
        'has_new_key': hasNewKey,
        'has_very_old_key': hasVeryOldKey,
        'total_cloud_size': cloudBackups.fold<int>(
          0,
          (sum, backup) => sum + (int.tryParse(backup.size.toString()) ?? 0),
        ),
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting status: $e');
      }
      return {};
    }
  }
}

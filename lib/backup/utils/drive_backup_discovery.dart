import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;

import '../models/backup_metadata.dart';
import 'backup_filename.dart';

/// Drive-side backup discovery for normal operation and reinstall recovery.
class DriveBackupDiscovery {
  DriveBackupDiscovery._();

  static const int minimumBackupFileBytes = 64;

  /// Whether [file] looks like a FalconLog encrypted backup in AppData.
  static bool isRecognizedDriveFile(drive.File file) {
    final id = file.id;
    final name = file.name;
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return false;
    }
    return BackupFilename.isRecognizedBackupFileName(name);
  }

  /// Validates encrypted backup JSON envelope shape (not decryption).
  static bool validateBackupEnvelope(Map<String, dynamic> encryptedBackup) {
    if (encryptedBackup['encrypted'] != true) {
      return false;
    }
    final version = encryptedBackup['version'];
    if (version is! String || version.isEmpty) {
      return false;
    }
    final backupId = encryptedBackup['backup_id'];
    if (backupId is! String || backupId.isEmpty) {
      return false;
    }
    for (final field in ['data', 'iv', 'tag']) {
      final value = encryptedBackup[field];
      if (value is! String || value.isEmpty) {
        return false;
      }
    }
    return true;
  }

  static bool validateBackupFileBytes(List<int> bytes) {
    if (bytes.length < minimumBackupFileBytes) {
      return false;
    }
    try {
      final decoded = json.decode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      return validateBackupEnvelope(decoded);
    } catch (_) {
      return false;
    }
  }

  /// Builds in-memory [BackupMetadata] for restore UI (not persisted).
  static BackupMetadata metadataFromDriveFile(
    drive.File file, {
    BackupMetadata? stored,
    int? sizeBytesOverride,
  }) {
    final fileSize = sizeBytesOverride ?? int.tryParse(file.size ?? '0') ?? 0;
    return BackupMetadata(
      id: stored?.id ?? file.id!,
      fileName: file.name!,
      location: BackupLocation.cloud,
      createdAt: stored?.createdAt ??
          file.modifiedTime ??
          file.createdTime ??
          DateTime.now(),
      sizeBytes: fileSize,
      flightLogsCount: stored?.flightLogsCount ?? 0,
      checksum: stored?.checksum ?? 'unknown',
      driveFileId: file.id!,
      isEncrypted: true,
      encryptionAlgorithm: 'AES-256-GCM',
      health: stored?.health ?? BackupHealth.unverified,
      deviceId: stored?.deviceId ?? 'Google Drive',
    );
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:falconlog/backup/utils/backup_filename.dart';
import 'package:falconlog/backup/utils/drive_backup_discovery.dart';

/// Source for a safety export — local file path and/or in-memory encrypted bytes.
class BackupSafetyExportCandidate {
  const BackupSafetyExportCandidate({
    required this.fileName,
    this.localSourcePath,
    this.encryptedBytes,
  }) : assert(
          localSourcePath != null || encryptedBytes != null,
          'Export candidate needs a local path or encrypted bytes',
        );

  final String fileName;
  final String? localSourcePath;
  final Uint8List? encryptedBytes;
}

/// Result of copying an encrypted backup to a user-selected location.
class BackupSafetyExportOutcome {
  const BackupSafetyExportOutcome._({
    required this.status,
    this.savedPath,
    this.errorMessage,
  });

  const BackupSafetyExportOutcome.success([String? savedPath])
      : this._(status: BackupSafetyExportStatus.success, savedPath: savedPath);

  const BackupSafetyExportOutcome.cancelled()
      : this._(status: BackupSafetyExportStatus.cancelled);

  const BackupSafetyExportOutcome.failure(String message)
      : this._(
          status: BackupSafetyExportStatus.failure,
          errorMessage: message,
        );

  final BackupSafetyExportStatus status;
  final String? savedPath;
  final String? errorMessage;

  bool get isSuccess => status == BackupSafetyExportStatus.success;
  bool get isCancelled => status == BackupSafetyExportStatus.cancelled;
  bool get isFailure => status == BackupSafetyExportStatus.failure;
}

enum BackupSafetyExportStatus { success, cancelled, failure }

typedef BackupSafetyExportSaveFile = Future<String?> Function({
  required String fileName,
  required Uint8List bytes,
});

/// Read-only helper: copies an existing encrypted `.crypt14` backup for testing.
///
/// Does not create backup metadata, update [last_backup_time], or modify the
/// source backup file.
class BackupSafetyExportHelper {
  BackupSafetyExportHelper._();

  static Future<Uint8List?> readEncryptedBytes(
    BackupSafetyExportCandidate candidate,
  ) async {
    if (candidate.encryptedBytes != null) {
      return Uint8List.fromList(candidate.encryptedBytes!);
    }

    final path = candidate.localSourcePath;
    if (path == null || path.isEmpty) {
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  static Future<BackupSafetyExportOutcome> export({
    required BackupSafetyExportCandidate candidate,
    required BackupSafetyExportSaveFile saveFile,
  }) async {
    if (!BackupFilename.isRecognizedBackupFileName(candidate.fileName)) {
      return const BackupSafetyExportOutcome.failure(
        'Backup file name is not recognized.',
      );
    }

    if (!candidate.fileName.endsWith(BackupFilename.extension)) {
      return const BackupSafetyExportOutcome.failure(
        'Backup file must use the .crypt14 extension.',
      );
    }

    final bytes = await readEncryptedBytes(candidate);
    if (bytes == null || bytes.isEmpty) {
      return const BackupSafetyExportOutcome.failure(
        'Backup file could not be read.',
      );
    }

    if (!DriveBackupDiscovery.validateBackupFileBytes(bytes)) {
      return const BackupSafetyExportOutcome.failure(
        'Backup file is not a valid encrypted backup.',
      );
    }

    try {
      final savedPath = await saveFile(
        fileName: candidate.fileName,
        bytes: bytes,
      );
      if (savedPath == null) {
        return const BackupSafetyExportOutcome.cancelled();
      }
      return BackupSafetyExportOutcome.success(savedPath);
    } catch (e) {
      return BackupSafetyExportOutcome.failure('Export failed: $e');
    }
  }
}

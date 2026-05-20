import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'backup_filename.dart';
import 'drive_backup_discovery.dart';

/// Picked `.crypt14` file ready for safety restore.
class BackupSafetyImportCandidate {
  const BackupSafetyImportCandidate({
    required this.fileName,
    required this.encryptedBytes,
  });

  final String fileName;
  final Uint8List encryptedBytes;
}

/// Result of loading a user-selected backup file for import.
class BackupSafetyImportOutcome {
  const BackupSafetyImportOutcome._({
    required this.status,
    this.candidate,
    this.errorMessage,
  });

  const BackupSafetyImportOutcome.success(BackupSafetyImportCandidate candidate)
      : this._(
          status: BackupSafetyImportStatus.success,
          candidate: candidate,
        );

  const BackupSafetyImportOutcome.cancelled()
      : this._(status: BackupSafetyImportStatus.cancelled);

  const BackupSafetyImportOutcome.failure(String message)
      : this._(
          status: BackupSafetyImportStatus.failure,
          errorMessage: message,
        );

  final BackupSafetyImportStatus status;
  final BackupSafetyImportCandidate? candidate;
  final String? errorMessage;

  bool get isSuccess => status == BackupSafetyImportStatus.success;
  bool get isCancelled => status == BackupSafetyImportStatus.cancelled;
  bool get isFailure => status == BackupSafetyImportStatus.failure;
}

enum BackupSafetyImportStatus { success, cancelled, failure }

/// Read-only helper: validates a user-picked `.crypt14` for safety restore.
///
/// Does not write metadata, change preferences, or mutate app backup storage.
class BackupSafetyImportHelper {
  BackupSafetyImportHelper._();

  static Future<BackupSafetyImportOutcome> loadFromPickerResult(
    FilePickerResult? result,
  ) async {
    if (result == null || result.files.isEmpty) {
      return const BackupSafetyImportOutcome.cancelled();
    }

    final file = result.files.first;
    final fileName = _resolveFileName(file);
    if (fileName == null) {
      return const BackupSafetyImportOutcome.failure(
        'Could not determine backup file name.',
      );
    }

    final bytes = await _readPickedBytes(file);
    return validate(fileName: fileName, encryptedBytes: bytes);
  }

  static String? _resolveFileName(PlatformFile file) {
    final name = file.name;
    if (name.isNotEmpty) {
      return name;
    }
    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    final segments = path.split(RegExp(r'[/\\]'));
    return segments.isEmpty ? null : segments.last;
  }

  static Future<Uint8List?> _readPickedBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return Uint8List.fromList(file.bytes!);
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    final ioFile = File(path);
    if (!await ioFile.exists()) {
      return null;
    }

    return ioFile.readAsBytes();
  }

  static BackupSafetyImportOutcome validate({
    required String fileName,
    required Uint8List? encryptedBytes,
  }) {
    if (!BackupFilename.isRecognizedBackupFileName(fileName)) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file name is not recognized.',
      );
    }

    if (!fileName.endsWith(BackupFilename.extension)) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file must use the .crypt14 extension.',
      );
    }

    if (!BackupFilename.hasOnlySafeCharacters(fileName)) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file name contains invalid characters.',
      );
    }

    if (encryptedBytes == null || encryptedBytes.isEmpty) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file could not be read.',
      );
    }

    if (!DriveBackupDiscovery.validateBackupFileBytes(encryptedBytes)) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file is not a valid encrypted backup.',
      );
    }

    return BackupSafetyImportOutcome.success(
      BackupSafetyImportCandidate(
        fileName: fileName,
        encryptedBytes: encryptedBytes,
      ),
    );
  }
}

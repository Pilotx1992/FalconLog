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
    final candidates = <String>[
      if (file.name.isNotEmpty) file.name,
      if (file.path != null && file.path!.isNotEmpty)
        file.path!.split(RegExp(r'[/\\]')).last,
    ];

    for (final name in candidates) {
      if (BackupFilename.isRecognizedBackupFileName(_normalizeFileName(name))) {
        return _normalizeFileName(name);
      }
    }

    return candidates.isEmpty ? null : _normalizeFileName(candidates.first);
  }

  static String _normalizeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (!trimmed.toLowerCase().endsWith(BackupFilename.extension)) {
      return trimmed;
    }
    final base =
        trimmed.substring(0, trimmed.length - BackupFilename.extension.length);
    return '$base${BackupFilename.extension}';
  }

  static Future<Uint8List?> _readPickedBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return Uint8List.fromList(file.bytes!);
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    try {
      final ioFile = File(path);
      if (!await ioFile.exists()) {
        return null;
      }
      return ioFile.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static BackupSafetyImportOutcome validate({
    required String fileName,
    required Uint8List? encryptedBytes,
  }) {
    final normalizedName = _normalizeFileName(fileName);

    if (!BackupFilename.isRecognizedBackupFileName(normalizedName)) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file name is not recognized. Choose a FLBKUP_*.crypt14 file.',
      );
    }

    if (!BackupFilename.hasOnlySafeCharacters(normalizedName)) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file name contains invalid characters.',
      );
    }

    if (encryptedBytes == null || encryptedBytes.isEmpty) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file could not be read. Try moving it to Downloads and pick it again.',
      );
    }

    if (!DriveBackupDiscovery.validateBackupFileBytes(encryptedBytes)) {
      return const BackupSafetyImportOutcome.failure(
        'Backup file is not a valid encrypted backup.',
      );
    }

    return BackupSafetyImportOutcome.success(
      BackupSafetyImportCandidate(
        fileName: normalizedName,
        encryptedBytes: encryptedBytes,
      ),
    );
  }
}

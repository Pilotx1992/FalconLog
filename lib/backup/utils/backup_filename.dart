import 'backup_constants.dart';

/// Backup file naming and discovery helpers.
///
/// New backups use [newPrefix] + local timestamp; legacy [legacyPrefix] files
/// remain discoverable and restorable.
class BackupFilename {
  BackupFilename._();

  static const String legacyPrefix = 'falconlog_backup_';
  static const String newPrefix = 'FLBKUP_';
  static const String extension = BackupConstants.backupExtension;

  /// Successful backups to retain (cloud and local).
  static const int keepLatestSuccessfulCount = 1;

  /// Google Drive query matching legacy and new encrypted backup files.
  static const String driveDiscoveryQuery =
      "(name contains '$legacyPrefix' or name contains '$newPrefix') "
      "and name contains '$extension'";

  /// Generates `FLBKUP_yyyyMMdd_HHmmss.crypt14` using [at] or local [DateTime.now].
  static String generate({DateTime? at}) {
    final timestamp = at ?? DateTime.now();
    final ymd = _formatYmd(timestamp);
    final hms = _formatHms(timestamp);
    return '$newPrefix${ymd}_$hms$extension';
  }

  /// Whether [fileName] is a known backup artifact (legacy or new naming).
  static bool isRecognizedBackupFileName(String fileName) {
    if (!fileName.endsWith(extension)) return false;
    return fileName.startsWith(newPrefix) || fileName.startsWith(legacyPrefix);
  }

  /// Parses backup timestamp from [fileName], or null if unknown.
  static DateTime? parseTimestampFromFileName(String fileName) {
    if (!isRecognizedBackupFileName(fileName)) {
      return null;
    }

    final withoutExt =
        fileName.substring(0, fileName.length - extension.length);

    if (withoutExt.startsWith(newPrefix)) {
      final stamp = withoutExt.substring(newPrefix.length);
      final parts = stamp.split('_');
      if (parts.length != 2) return null;
      final ymd = parts[0];
      final hms = parts[1];
      if (ymd.length != 8 || hms.length != 6) return null;
      try {
        return DateTime(
          int.parse(ymd.substring(0, 4)),
          int.parse(ymd.substring(4, 6)),
          int.parse(ymd.substring(6, 8)),
          int.parse(hms.substring(0, 2)),
          int.parse(hms.substring(2, 4)),
          int.parse(hms.substring(4, 6)),
        );
      } catch (_) {
        return null;
      }
    }

    if (withoutExt.startsWith(legacyPrefix)) {
      final epochSeconds = int.tryParse(
        withoutExt.substring(legacyPrefix.length),
      );
      if (epochSeconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    }

    return null;
  }

  /// Filenames use only letters, digits, underscore, dash, and dot.
  static bool hasOnlySafeCharacters(String fileName) {
    return RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(fileName);
  }

  static String _formatYmd(DateTime dt) {
    return '${dt.year}${_two(dt.month)}${_two(dt.day)}';
  }

  static String _formatHms(DateTime dt) {
    return '${_two(dt.hour)}${_two(dt.minute)}${_two(dt.second)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

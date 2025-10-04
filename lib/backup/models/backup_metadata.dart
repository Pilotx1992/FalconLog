import 'package:hive/hive.dart';

part 'backup_metadata.g.dart';

/// Enhanced backup metadata with location tracking and health status
@HiveType(typeId: 100)
class BackupMetadata extends HiveObject {
  @HiveField(0)
  final String id; // Unique backup ID (timestamp)

  @HiveField(1)
  final String fileName; // falconlog_backup_1727654400.crypt14

  @HiveField(2)
  final BackupLocation location; // cloud, local, or both

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final int sizeBytes;

  @HiveField(5)
  final int flightLogsCount; // NEW: Show in history

  @HiveField(6)
  final String checksum; // SHA-256

  @HiveField(7)
  final String? driveFileId; // Google Drive file ID (if cloud)

  @HiveField(8)
  final String? localPath; // Local file path (if local)

  @HiveField(9)
  final bool isEncrypted; // Always true

  @HiveField(10)
  final String encryptionAlgorithm; // "AES-256-GCM"

  @HiveField(11)
  final BackupHealth health; // healthy, unverified, corrupted

  @HiveField(12)
  final DateTime? lastVerified; // Last integrity check

  @HiveField(13)
  final String deviceId; // Device that created the backup

  BackupMetadata({
    required this.id,
    required this.fileName,
    required this.location,
    required this.createdAt,
    required this.sizeBytes,
    required this.flightLogsCount,
    required this.checksum,
    this.driveFileId,
    this.localPath,
    this.isEncrypted = true,
    this.encryptionAlgorithm = 'AES-256-GCM',
    this.health = BackupHealth.healthy,
    this.lastVerified,
    required this.deviceId,
  });

  /// Helper method to format file size
  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Helper method to format age description
  String get ageDescription {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if backup is available for restore
  bool get isAvailable => location != BackupLocation.none;

  /// Get display name for location
  String get locationDisplayName {
    switch (location) {
      case BackupLocation.none:
        return 'Not Available';
      case BackupLocation.cloud:
        return 'Cloud Only';
      case BackupLocation.local:
        return 'Local Only';
      case BackupLocation.both:
        return 'Cloud & Local';
    }
  }

  /// Get health status display
  String get healthDisplayName {
    switch (health) {
      case BackupHealth.healthy:
        return 'Verified';
      case BackupHealth.unverified:
        return 'Not verified';
      case BackupHealth.corrupted:
        return 'Corrupted';
    }
  }

  /// Create a copy with updated fields
  BackupMetadata copyWith({
    String? id,
    String? fileName,
    BackupLocation? location,
    DateTime? createdAt,
    int? sizeBytes,
    int? flightLogsCount,
    String? checksum,
    String? driveFileId,
    String? localPath,
    bool? isEncrypted,
    String? encryptionAlgorithm,
    BackupHealth? health,
    DateTime? lastVerified,
    String? deviceId,
  }) {
    return BackupMetadata(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      flightLogsCount: flightLogsCount ?? this.flightLogsCount,
      checksum: checksum ?? this.checksum,
      driveFileId: driveFileId ?? this.driveFileId,
      localPath: localPath ?? this.localPath,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptionAlgorithm: encryptionAlgorithm ?? this.encryptionAlgorithm,
      health: health ?? this.health,
      lastVerified: lastVerified ?? this.lastVerified,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  String toString() {
    return 'BackupMetadata(id: $id, fileName: $fileName, location: $location, '
        'createdAt: $createdAt, sizeBytes: $sizeBytes, flightLogsCount: $flightLogsCount, '
        'health: $health, deviceId: $deviceId)';
  }
}

/// Backup location enumeration
@HiveType(typeId: 101)
enum BackupLocation {
  @HiveField(0)
  none, // Deleted

  @HiveField(1)
  cloud, // Only in Drive

  @HiveField(2)
  local, // Only on device

  @HiveField(3)
  both, // Both locations
}

/// Backup health status enumeration
@HiveType(typeId: 102)
enum BackupHealth {
  @HiveField(0)
  healthy, // Verified OK

  @HiveField(1)
  unverified, // Not checked yet

  @HiveField(2)
  corrupted, // Failed verification
}

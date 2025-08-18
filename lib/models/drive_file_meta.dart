/// Metadata for a backup file stored in Google Drive
class DriveFileMeta {
  final String id;
  final String name;
  final DateTime createdTime;
  final DateTime modifiedTime;
  final int size;
  final String? sha256;
  final Map<String, String>? appProperties;

  DriveFileMeta({
    required this.id,
    required this.name,
    required this.createdTime,
    required this.modifiedTime,
    required this.size,
    this.sha256,
    this.appProperties,
  });

  /// Creates a DriveFileMeta from Google Drive API File object
  factory DriveFileMeta.fromDriveFile(dynamic driveFile) {
    return DriveFileMeta(
      id: driveFile.id ?? '',
      name: driveFile.name ?? '',
      createdTime: DateTime.tryParse(driveFile.createdTime ?? '') ?? DateTime.now(),
      modifiedTime: DateTime.tryParse(driveFile.modifiedTime ?? '') ?? DateTime.now(),
      size: int.tryParse(driveFile.size ?? '0') ?? 0,
      sha256: driveFile.sha256Checksum,
      appProperties: driveFile.appProperties?.cast<String, String>(),
    );
  }

  /// Formats file size in human readable format
  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Returns relative time string (e.g., "2 hours ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(modifiedTime);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo ago';
    return '${(difference.inDays / 365).floor()}y ago';
  }

  @override
  String toString() {
    return 'DriveFileMeta(id: $id, name: $name, size: $formattedSize, created: $relativeTime)';
  }
}

/// Backup operation status with progress tracking
enum BackupStatus {
  idle,
  checkingConnectivity,
  initializingDrive,
  gettingKey,
  creatingBackup,
  encrypting,
  uploading,
  savingLocal,
  pruning,
  completed,
  failed,
  cancelled,
}

/// Restore operation status with progress tracking
enum RestoreStatus {
  idle,
  checkingConnectivity,
  initializingDrive,
  findingBackup,
  downloading,
  retrievingKey,
  decrypting,
  filtering,
  applying,
  completed,
  failed,
  cancelled,
}

/// Extension methods for status enums
extension BackupStatusExtension on BackupStatus {
  /// Get user-friendly display name
  String get displayName {
    switch (this) {
      case BackupStatus.idle:
        return 'Ready';
      case BackupStatus.checkingConnectivity:
        return 'Checking connection...';
      case BackupStatus.initializingDrive:
        return 'Connecting to Google Drive...';
      case BackupStatus.gettingKey:
        return 'Getting encryption key...';
      case BackupStatus.creatingBackup:
        return 'Creating backup...';
      case BackupStatus.encrypting:
        return 'Encrypting data...';
      case BackupStatus.uploading:
        return 'Uploading to cloud...';
      case BackupStatus.savingLocal:
        return 'Saving local copy...';
      case BackupStatus.pruning:
        return 'Cleaning up old backups...';
      case BackupStatus.completed:
        return 'Backup completed!';
      case BackupStatus.failed:
        return 'Backup failed';
      case BackupStatus.cancelled:
        return 'Backup cancelled';
    }
  }

  /// Get progress percentage (0-100)
  int get progressPercentage {
    switch (this) {
      case BackupStatus.idle:
        return 0;
      case BackupStatus.checkingConnectivity:
        return 12;
      case BackupStatus.initializingDrive:
        return 25;
      case BackupStatus.gettingKey:
        return 37;
      case BackupStatus.creatingBackup:
        return 50;
      case BackupStatus.encrypting:
        return 62;
      case BackupStatus.uploading:
        return 75;
      case BackupStatus.savingLocal:
        return 87;
      case BackupStatus.pruning:
        return 95;
      case BackupStatus.completed:
        return 100;
      case BackupStatus.failed:
        return 0;
      case BackupStatus.cancelled:
        return 0;
    }
  }

  /// Check if operation is in progress
  bool get isInProgress {
    return this != BackupStatus.idle &&
        this != BackupStatus.completed &&
        this != BackupStatus.failed &&
        this != BackupStatus.cancelled;
  }

  /// Check if operation is completed (success or failure)
  bool get isCompleted {
    return this == BackupStatus.completed ||
        this == BackupStatus.failed ||
        this == BackupStatus.cancelled;
  }
}

extension RestoreStatusExtension on RestoreStatus {
  /// Get user-friendly display name
  String get displayName {
    switch (this) {
      case RestoreStatus.idle:
        return 'Ready';
      case RestoreStatus.checkingConnectivity:
        return 'Checking connection...';
      case RestoreStatus.initializingDrive:
        return 'Connecting to Google Drive...';
      case RestoreStatus.findingBackup:
        return 'Finding backup...';
      case RestoreStatus.downloading:
        return 'Downloading backup...';
      case RestoreStatus.retrievingKey:
        return 'Getting encryption key...';
      case RestoreStatus.decrypting:
        return 'Decrypting data...';
      case RestoreStatus.filtering:
        return 'Filtering logs...';
      case RestoreStatus.applying:
        return 'Restoring flight logs...';
      case RestoreStatus.completed:
        return 'Restore completed!';
      case RestoreStatus.failed:
        return 'Restore failed';
      case RestoreStatus.cancelled:
        return 'Restore cancelled';
    }
  }

  /// Get progress percentage (0-100)
  int get progressPercentage {
    switch (this) {
      case RestoreStatus.idle:
        return 0;
      case RestoreStatus.checkingConnectivity:
        return 12;
      case RestoreStatus.initializingDrive:
        return 25;
      case RestoreStatus.findingBackup:
        return 37;
      case RestoreStatus.downloading:
        return 50;
      case RestoreStatus.retrievingKey:
        return 62;
      case RestoreStatus.decrypting:
        return 75;
      case RestoreStatus.filtering:
        return 87;
      case RestoreStatus.applying:
        return 95;
      case RestoreStatus.completed:
        return 100;
      case RestoreStatus.failed:
        return 0;
      case RestoreStatus.cancelled:
        return 0;
    }
  }

  /// Check if operation is in progress
  bool get isInProgress {
    return this != RestoreStatus.idle &&
        this != RestoreStatus.completed &&
        this != RestoreStatus.failed &&
        this != RestoreStatus.cancelled;
  }

  /// Check if operation is completed (success or failure)
  bool get isCompleted {
    return this == RestoreStatus.completed ||
        this == RestoreStatus.failed ||
        this == RestoreStatus.cancelled;
  }
}

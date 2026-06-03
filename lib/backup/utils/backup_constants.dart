/// Enhanced backup system constants
class BackupConstants {
  // File and directory constants
  static const String backupDirectory = 'falconlog_backups';
  static const String localBackupsFolder = 'local_backups';
  static const String tempDirectory = 'temp';
  static const String metadataFileName = 'backup_metadata.json';
  static const String keyFileName = 'falconlog_backup_keys.encrypted';

  // Backup file extensions
  static const String backupExtension = '.crypt14'; // WhatsApp-style encrypted format
  static const String metadataExtension = '.json';

  // Encryption constants
  static const String encryptionAlgorithm = 'AES-256-GCM';
  static const int keyDerivationIterations = 100000;
  static const int saltLength = 32;
  static const int ivLength = 12; // 96-bit nonce for GCM
  static const int tagLength = 16; // 128-bit authentication tag

  // Backup limits and thresholds
  static const int maxBackupSize = 100 * 1024 * 1024; // 100MB
  static const int maxBackupCount = 10;
  static const int defaultKeepCount = 5;
  static const int minKeepCount = 1;
  static const int maxKeepCount = 10;
  static const int warningBackupAge = 30; // days
  static const int criticalBackupAge = 90; // days

  // Cloud sync constants
  static const String googleDriveFolder = 'FalconLog_Backups';
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 5;
  static const int uploadChunkSize = 1024 * 1024; // 1MB chunks
  static const int maxConcurrentUploads = 2;

  // Progress and monitoring
  static const int progressUpdateInterval = 100; // Update every 100ms
  static const int healthCheckInterval = 3600; // Check every hour (seconds)
  static const int syncInterval = 900; // Sync every 15 minutes (seconds)

  // Security constants
  static const String keyStorageKey = 'falconlog_backup_key';
  static const String biometricReason = 'Authenticate to access backup encryption keys';
  static const int sessionTimeout = 300; // 5 minutes (seconds)

  // Performance constants
  static const int batchSize = 1000; // Records per batch
  static const int maxMemoryUsage = 100 * 1024 * 1024; // 100MB
  static const int ioBufferSize = 64 * 1024; // 64KB

  // Validation constants
  static const List<String> supportedHashAlgorithms = ['SHA-256', 'SHA-512'];
  static const String defaultHashAlgorithm = 'SHA-256';
  static const int maxFilenameLength = 255;
  static const int minPasswordLength = 8;

  // Backup scheduling
  static const Map<String, int> scheduleIntervals = {
    'off': 0,
    'daily': 86400,
    'weekly': 604800,
    'monthly': 2592000,
  };

  // Verification scheduling
  static const Map<String, int> verificationIntervals = {
    'off': 0,
    'daily': 86400,      // 1 day
    'weekly': 604800,    // 1 week
    'monthly': 2592000,  // 1 month
  };

  // File patterns and filters
  static const List<String> excludePatterns = [
    '*.tmp',
    '*.log',
    '*.cache',
    '.DS_Store',
    'Thumbs.db',
  ];

  // Error codes
  static const Map<String, int> errorCodes = {
    'BACKUP_FAILED': 1001,
    'RESTORE_FAILED': 1002,
    'SYNC_FAILED': 1003,
    'ENCRYPTION_FAILED': 1004,
    'VALIDATION_FAILED': 1005,
    'NETWORK_ERROR': 1006,
    'PERMISSION_DENIED': 1007,
    'DISK_FULL': 1008,
    'CORRUPTED_DATA': 1009,
    'AUTHENTICATION_FAILED': 1010,
  };

  // Notification messages
  static const Map<String, String> notifications = {
    'BACKUP_STARTED': 'Backup operation started',
    'BACKUP_COMPLETED': 'Backup completed successfully',
    'BACKUP_FAILED': 'Backup operation failed',
    'RESTORE_COMPLETED': 'Restore completed successfully',
    'SYNC_COMPLETED': 'Cloud sync completed',
    'CONFLICT_DETECTED': 'Sync conflicts detected',
    'LOW_STORAGE': 'Low storage space warning',
    'BACKUP_OVERDUE': 'Backup is overdue',
  };

  // UI Messages
  static const Map<String, String> uiMessages = {
    'backup_now': 'Backup Now',
    'restore_from_backup': 'Restore from Backup',
    'backup_settings': 'Backup Settings',
    'backup_history': 'Backup History',
    'storage_info': 'Storage Info',
    'advanced_options': 'Advanced Options',
    'local_backups': 'Also keep local backups',
    'keep_last_backups': 'Keep last backups',
    'auto_backup': 'Auto Backup',
    'wifi_only': 'Wi-Fi only',
    'backup_frequency': 'Backup Frequency',
    'last_backup': 'Last backup',
    'no_backups': 'No backups available',
    'backup_in_progress': 'Backup in progress...',
    'restore_in_progress': 'Restore in progress...',
    'backup_success': 'Backup completed successfully!',
    'restore_success': 'Restore completed successfully!',
    'backup_failed': 'Backup failed',
    'restore_failed': 'Restore failed',
    'no_internet': 'No internet connection',
    'drive_auth_failed': 'Google Drive authentication failed',
    'encryption_failed': 'Encryption failed',
    'decryption_failed': 'Decryption failed',
    'storage_full': 'Storage is full',
    'backup_corrupted': 'Backup is corrupted',
    'backup_not_found': 'Backup not found',
    'invalid_backup': 'Invalid backup format',
    'restore_warning': 'This will replace your current flight logs',
    'delete_backup_warning': 'Are you sure you want to delete this backup?',
    'enable_local_backups': 'Enable local backups for offline access',
    'local_backups_warning': 'Local backups use device storage',
    'backup_verification': 'Verify backup integrity',
    'backup_verified': 'Backup verified successfully',
    'backup_corrupted_warning': 'Backup verification failed',
  };

  // Progress messages for each step
  static const Map<String, String> progressMessages = {
    'checking_connectivity': 'Checking connection...',
    'initializing_drive': 'Connecting to Google Drive...',
    'getting_key': 'Getting encryption key...',
    'creating_backup': 'Creating backup...',
    'encrypting': 'Encrypting data...',
    'uploading': 'Uploading to cloud...',
    'saving_local': 'Saving local copy...',
    'pruning': 'Cleaning up old backups...',
    'finding_backup': 'Finding backup...',
    'downloading': 'Downloading backup...',
    'retrieving_key': 'Getting encryption key...',
    'decrypting': 'Decrypting data...',
    'filtering': 'Filtering logs...',
    'applying': 'Restoring flight logs...',
    'completed': 'Operation completed!',
    'failed': 'Operation failed',
    'cancelled': 'Operation cancelled',
  };

  // Settings keys
  static const Map<String, String> settingsKeys = {
    'auto_backup_enabled': 'falconlog_auto_backup_enabled',
    'backup_frequency': 'falconlog_backup_frequency',
    'wifi_only': 'falconlog_wifi_only',
    'keep_count': 'falconlog_backup_keep_count',
    'local_backups_enabled': 'falconlog_local_backups_enabled',
    'last_backup_time': 'falconlog_last_backup_time',
    'backup_folder_id': 'falconlog_drive_backup_folder_id',
    'key_file_id': 'falconlog_backup_key_file_id',
    'key_version': 'falconlog_backup_key_version',
    'auto_verification_enabled': 'falconlog_auto_verification_enabled',
    'verification_frequency': 'falconlog_verification_frequency',
    'verification_wifi_only': 'falconlog_verification_wifi_only',
  };

  // Default settings
  static const Map<String, dynamic> defaultSettings = {
    'auto_backup_enabled': false,
    'backup_frequency': 'weekly',
    'wifi_only': true,
    'keep_count': 5,
    'local_backups_enabled': false,
    'auto_verification_enabled': true,  // Always enabled
    'verification_frequency': 'weekly',
    'verification_wifi_only': true,
  };
}

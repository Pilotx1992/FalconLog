import 'backup_metadata.dart';

/// Backup provider options
enum BackupProvider {
  firebase,
  local,
  googleDrive;

  String get displayName {
    switch (this) {
      case BackupProvider.firebase:
        return 'Cloud (Firebase)';
      case BackupProvider.local:
        return 'Local Device';
      case BackupProvider.googleDrive:
        return 'Google Drive';
    }
  }
}

/// Auto backup interval options
enum AutoBackupInterval {
  daily,
  weekly,
  monthly,
  afterEachFlight,
  manual;

  String get displayName {
    switch (this) {
      case AutoBackupInterval.daily:
        return 'Daily';
      case AutoBackupInterval.weekly:
        return 'Weekly';
      case AutoBackupInterval.monthly:
        return 'Monthly';
      case AutoBackupInterval.afterEachFlight:
        return 'After Each Flight';
      case AutoBackupInterval.manual:
        return 'Manual Only';
    }
  }

  Duration? get duration {
    switch (this) {
      case AutoBackupInterval.daily:
        return const Duration(days: 1);
      case AutoBackupInterval.weekly:
        return const Duration(days: 7);
      case AutoBackupInterval.monthly:
        return const Duration(days: 30);
      case AutoBackupInterval.afterEachFlight:
      case AutoBackupInterval.manual:
        return null;
    }
  }
}

/// Auto backup trigger options
enum AutoBackupTrigger {
  timeInterval,
  flightAdded,
  appClose,
  combined;

  String get displayName {
    switch (this) {
      case AutoBackupTrigger.timeInterval:
        return 'Time Interval';
      case AutoBackupTrigger.flightAdded:
        return 'When Flight Added';
      case AutoBackupTrigger.appClose:
        return 'When App Closes';
      case AutoBackupTrigger.combined:
        return 'Multiple Triggers';
    }
  }
}

/// Auto backup configuration
class AutoBackupConfig {
  final bool enabled;
  final AutoBackupInterval interval;
  final AutoBackupTrigger trigger;
  final bool requiresWifi;
  final int maxBackups;
  final BackupProvider preferredProvider;
  final DateTime? lastAutoBackup;

  const AutoBackupConfig({
    this.enabled = true,
    this.interval = AutoBackupInterval.weekly,
    this.trigger = AutoBackupTrigger.combined,
    this.requiresWifi = false,
    this.maxBackups = 10,
    this.preferredProvider = BackupProvider.firebase,
    this.lastAutoBackup,
  });

  AutoBackupConfig copyWith({
    bool? enabled,
    AutoBackupInterval? interval,
    AutoBackupTrigger? trigger,
    bool? requiresWifi,
    int? maxBackups,
    BackupProvider? preferredProvider,
    DateTime? lastAutoBackup,
  }) {
    return AutoBackupConfig(
      enabled: enabled ?? this.enabled,
      interval: interval ?? this.interval,
      trigger: trigger ?? this.trigger,
      requiresWifi: requiresWifi ?? this.requiresWifi,
      maxBackups: maxBackups ?? this.maxBackups,
      preferredProvider: preferredProvider ?? this.preferredProvider,
      lastAutoBackup: lastAutoBackup ?? this.lastAutoBackup,
    );
  }
}

/// Backup information for UI display and targeted restore.
class BackupInfo {
  /// Display / lookup id (Drive file id or Hive metadata id).
  final String id;

  /// Hive metadata record id.
  final String metadataId;
  final String? driveFileId;
  final String? localPath;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
  final int logsCount;
  final BackupProvider provider;

  const BackupInfo({
    required this.id,
    required this.metadataId,
    this.driveFileId,
    this.localPath,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
    required this.logsCount,
    required this.provider,
  });

  factory BackupInfo.fromMetadata(BackupMetadata metadata) {
    return BackupInfo(
      id: metadata.driveFileId ?? metadata.id,
      metadataId: metadata.id,
      driveFileId: metadata.driveFileId,
      localPath: metadata.localPath,
      fileName: metadata.fileName,
      createdAt: metadata.createdAt,
      sizeBytes: metadata.sizeBytes,
      logsCount: metadata.flightLogsCount,
      provider: metadata.location == BackupLocation.local
          ? BackupProvider.local
          : BackupProvider.googleDrive,
    );
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    return '$day/$month/$year';
  }
}

/// Backup status information
class BackupStatus {
  final BackupStatusType type;
  final String message;
  final DateTime timestamp;
  final bool isSuccess;

  const BackupStatus({
    this.type = BackupStatusType.idle,
    required this.message,
    required this.timestamp,
    required this.isSuccess,
  });

  bool get isError => type == BackupStatusType.error || !isSuccess;
  bool get isInProgress => type == BackupStatusType.inProgress;
  bool get hasSucceeded => type == BackupStatusType.success || isSuccess;
}

/// Backup recommendation
class BackupRecommendation {
  final BackupRecommendationType type;
  final String message;
  final bool isUrgent;

  const BackupRecommendation({
    this.type = BackupRecommendationType.none,
    required this.message,
    this.isUrgent = false,
  });
}

enum BackupStatusType {
  idle,
  inProgress,
  success,
  error,
}

enum BackupRecommendationType {
  none,
  firstBackup,
  overdue,
  recommended,
}

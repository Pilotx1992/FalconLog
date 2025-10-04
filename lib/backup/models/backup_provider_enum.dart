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
  afterEachFlight,
  manual;

  String get displayName {
    switch (this) {
      case AutoBackupInterval.daily:
        return 'Daily';
      case AutoBackupInterval.weekly:
        return 'Weekly';
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

/// Backup information for UI display
class BackupInfo {
  final String id;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
  final int logsCount;
  final BackupProvider provider;

  const BackupInfo({
    required this.id,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
    required this.logsCount,
    required this.provider,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
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
  final String message;
  final DateTime timestamp;
  final bool isSuccess;

  const BackupStatus({
    required this.message,
    required this.timestamp,
    required this.isSuccess,
  });
}

/// Backup recommendation
class BackupRecommendation {
  final String message;
  final bool isUrgent;

  const BackupRecommendation({
    required this.message,
    this.isUrgent = false,
  });
}

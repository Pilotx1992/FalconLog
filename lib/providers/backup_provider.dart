import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/backup_service.dart';
import '../models/flight_log.dart';
import 'flight_logs_provider.dart';

// Backup provider setting
final backupProviderProvider = StateNotifierProvider<BackupProviderNotifier, BackupProvider>((ref) {
  return BackupProviderNotifier();
});

class BackupProviderNotifier extends StateNotifier<BackupProvider> {
  BackupProviderNotifier() : super(BackupProvider.firebase) {
    _loadBackupProvider();
  }
  
  Future<void> _loadBackupProvider() async {
    state = await BackupService.getBackupProvider();
  }
  
  Future<void> setBackupProvider(BackupProvider provider) async {
    await BackupService.setBackupProvider(provider);
    state = provider;
  }
}

// Auto backup configuration classes
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
  
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'interval': interval.name,
      'trigger': trigger.name,
      'requiresWifi': requiresWifi,
      'maxBackups': maxBackups,
      'preferredProvider': preferredProvider.name,
      'lastAutoBackup': lastAutoBackup?.toIso8601String(),
    };
  }
  
  factory AutoBackupConfig.fromJson(Map<String, dynamic> json) {
    return AutoBackupConfig(
      enabled: json['enabled'] ?? true,
      interval: AutoBackupInterval.values.firstWhere(
        (e) => e.name == json['interval'],
        orElse: () => AutoBackupInterval.weekly,
      ),
      trigger: AutoBackupTrigger.values.firstWhere(
        (e) => e.name == json['trigger'],
        orElse: () => AutoBackupTrigger.combined,
      ),
      requiresWifi: json['requiresWifi'] ?? false,
      maxBackups: json['maxBackups'] ?? 10,
      preferredProvider: BackupProvider.values.firstWhere(
        (e) => e.name == json['preferredProvider'],
        orElse: () => BackupProvider.firebase,
      ),
      lastAutoBackup: json['lastAutoBackup'] != null 
          ? DateTime.parse(json['lastAutoBackup'])
          : null,
    );
  }
  
  bool get shouldBackupNow {
    if (!enabled) return false;
    if (lastAutoBackup == null) return true;
    
    final duration = interval.duration;
    if (duration == null) return false;
    
    return DateTime.now().difference(lastAutoBackup!).compareTo(duration) >= 0;
  }
}

// Auto backup enabled setting
final autoBackupEnabledProvider = StateNotifierProvider<AutoBackupNotifier, bool>((ref) {
  return AutoBackupNotifier();
});

class AutoBackupNotifier extends StateNotifier<bool> {
  AutoBackupNotifier() : super(true) {
    _loadAutoBackupSetting();
  }
  
  Future<void> _loadAutoBackupSetting() async {
    state = await BackupService.isAutoBackupEnabled();
  }
  
  Future<void> setAutoBackupEnabled(bool enabled) async {
    await BackupService.setAutoBackupEnabled(enabled);
    state = enabled;
  }
}

// Auto backup configuration
final autoBackupConfigProvider = StateNotifierProvider<AutoBackupConfigNotifier, AutoBackupConfig>((ref) {
  return AutoBackupConfigNotifier();
});

class AutoBackupConfigNotifier extends StateNotifier<AutoBackupConfig> {
  AutoBackupConfigNotifier() : super(const AutoBackupConfig()) {
    _loadConfig();
  }
  
  Future<void> _loadConfig() async {
    final configJson = await BackupService.getAutoBackupConfig();
    state = AutoBackupConfig.fromJson(configJson);
  }
  
  Future<void> updateConfig(AutoBackupConfig config) async {
    await BackupService.setAutoBackupConfig(config);
    state = config;
  }
  
  Future<void> setInterval(AutoBackupInterval interval) async {
    final newConfig = state.copyWith(interval: interval);
    await updateConfig(newConfig);
  }
  
  Future<void> setTrigger(AutoBackupTrigger trigger) async {
    final newConfig = state.copyWith(trigger: trigger);
    await updateConfig(newConfig);
  }
  
  Future<void> setRequiresWifi(bool requiresWifi) async {
    final newConfig = state.copyWith(requiresWifi: requiresWifi);
    await updateConfig(newConfig);
  }
  
  Future<void> setMaxBackups(int maxBackups) async {
    final newConfig = state.copyWith(maxBackups: maxBackups);
    await updateConfig(newConfig);
  }
}

// Last backup time
final lastBackupTimeProvider = FutureProvider<DateTime?>((ref) {
  return BackupService.getLastBackupTime();
});

// Backup history
final backupHistoryProvider = FutureProvider<List<BackupInfo>>((ref) async {
  final connectivityResults = await Connectivity().checkConnectivity();
  final isConnected = connectivityResults.isNotEmpty && 
                     !connectivityResults.contains(ConnectivityResult.none);
  
  if (isConnected) {
    try {
      // Try to get Firebase backup history first
      final firebaseBackups = await BackupService.getBackupHistory();
      final localBackups = await BackupService.getLocalBackups();
      
      // Combine and sort by timestamp
      final allBackups = [...firebaseBackups, ...localBackups];
      allBackups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return allBackups;
    } catch (e) {
      // If Firebase fails (API not enabled, etc.), fallback to local only
      print('Firebase backup history failed, using local only: $e');
      return await BackupService.getLocalBackups();
    }
  } else {
    // Only local backups when offline
    return await BackupService.getLocalBackups();
  }
});

// Backup status and operations
final backupStatusProvider = StateNotifierProvider<BackupStatusNotifier, BackupStatus>((ref) {
  return BackupStatusNotifier(ref);
});

class BackupStatusNotifier extends StateNotifier<BackupStatus> {
  final Ref ref;
  
  BackupStatusNotifier(this.ref) : super(const BackupStatus.idle());
  
  Future<void> performBackup(List<FlightLog> logs, BackupProvider provider) async {
    state = const BackupStatus.backingUp();
    
    BackupResult result;
    switch (provider) {
      case BackupProvider.firebase:
        result = await BackupService.backupToFirebase(logs);
        break;
      case BackupProvider.local:
        result = await BackupService.backupToLocal(logs);
        break;
      case BackupProvider.googleDrive:
        result = await BackupService.backupToGoogleDrive(logs);
        break;
    }
    
    if (result.success) {
      state = BackupStatus.success(
        message: result.message,
        logsCount: result.logsCount ?? 0,
        backupSize: result.backupSize ?? 0,
      );
      
      // Refresh related providers
      ref.invalidate(lastBackupTimeProvider);
      ref.invalidate(backupHistoryProvider);
    } else {
      state = BackupStatus.error(result.message);
    }
    
    // Reset to idle after 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) state = const BackupStatus.idle();
  }
  
  Future<void> performRestore(BackupInfo backupInfo) async {
    state = const BackupStatus.restoring();
    
    RestoreResult result;
    if (backupInfo.provider == BackupProvider.firebase) {
      result = await BackupService.restoreFromFirebase(backupId: backupInfo.id);
    } else if (backupInfo.provider == BackupProvider.local) {
      result = await BackupService.restoreFromLocal(backupInfo.id);
    } else if (backupInfo.provider == BackupProvider.googleDrive) {
      result = await BackupService.restoreFromGoogleDrive(backupId: backupInfo.id);
    } else {
      result = RestoreResult.error('Unknown backup provider');
    }
    
    if (result.success && result.logs != null) {
      // Actually restore the flight logs to the app
      await ref.read(flightLogsProvider.notifier).restoreFlightLogs(result.logs!);
      
      state = BackupStatus.restoreSuccess(
        logs: result.logs!,
        timestamp: result.timestamp,
        version: result.version,
      );
    } else {
      state = BackupStatus.error(result.message ?? 'Restore failed');
    }
    
    // Reset to idle after 5 seconds (longer for user to see success)
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) state = const BackupStatus.idle();
  }
  
  Future<void> performAutoBackup(List<FlightLog> logs) async {
    final result = await BackupService.performAutoBackup(logs);
    
    if (result.success) {
      // Refresh providers silently
      ref.invalidate(lastBackupTimeProvider);
      ref.invalidate(backupHistoryProvider);
    }
  }
  
  Future<void> deleteBackup(BackupInfo backupInfo) async {
    state = const BackupStatus.deleting();
    
    final success = await BackupService.deleteBackup(backupInfo);
    
    if (success) {
      state = const BackupStatus.deleteSuccess();
      ref.invalidate(backupHistoryProvider);
    } else {
      state = const BackupStatus.error('Failed to delete backup');
    }
    
    // Reset to idle after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) state = const BackupStatus.idle();
  }
  
  void resetStatus() {
    state = const BackupStatus.idle();
  }
  
  /// Performs backup maintenance tasks like cleaning old backups
  Future<void> performMaintenance() async {
    try {
      // Get backup history to check for old backups
      final history = await ref.read(backupHistoryProvider.future);
      
      // Keep only the most recent 10 backups of each type
      final firebaseBackups = history.where((b) => b.provider == BackupProvider.firebase).toList();
      final localBackups = history.where((b) => b.provider == BackupProvider.local).toList();
      
      // Sort by timestamp, newest first
      firebaseBackups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      localBackups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Delete old Firebase backups (keep 10 most recent)
      if (firebaseBackups.length > 10) {
        for (int i = 10; i < firebaseBackups.length; i++) {
          await BackupService.deleteBackup(firebaseBackups[i]);
        }
      }
      
      // Delete old local backups (keep 5 most recent)
      if (localBackups.length > 5) {
        for (int i = 5; i < localBackups.length; i++) {
          await BackupService.deleteBackup(localBackups[i]);
        }
      }
      
      // Refresh backup history after cleanup
      ref.invalidate(backupHistoryProvider);
    } catch (e) {
      // Silently handle maintenance errors
      print('Backup maintenance error: $e');
    }
  }
  
  /// Gets backup verification status
  Future<BackupVerificationResult> verifyBackups() async {
    try {
      final history = await ref.read(backupHistoryProvider.future);
      final now = DateTime.now();
      
      int corruptBackups = 0;
      int validBackups = 0;
      DateTime? lastValidBackup;
      
      for (final backup in history) {
        // For now, consider all backups valid unless proven otherwise
        // In a real implementation, you'd verify checksums
        if (backup.checksum.isNotEmpty) {
          validBackups++;
          if (lastValidBackup == null || backup.timestamp.isAfter(lastValidBackup)) {
            lastValidBackup = backup.timestamp;
          }
        } else {
          corruptBackups++;
        }
      }
      
      final daysSinceLastValid = lastValidBackup != null 
          ? now.difference(lastValidBackup).inDays 
          : 999;
      
      return BackupVerificationResult(
        totalBackups: history.length,
        validBackups: validBackups,
        corruptBackups: corruptBackups,
        lastValidBackup: lastValidBackup,
        daysSinceLastValid: daysSinceLastValid,
        isHealthy: corruptBackups == 0 && daysSinceLastValid < 7,
      );
    } catch (e) {
      return BackupVerificationResult.error(e.toString());
    }
  }
}

// Backup status sealed class
sealed class BackupStatus {
  const BackupStatus();
  
  const factory BackupStatus.idle() = _Idle;
  const factory BackupStatus.backingUp() = _BackingUp;
  const factory BackupStatus.restoring() = _Restoring;
  const factory BackupStatus.deleting() = _Deleting;
  const factory BackupStatus.success({
    required String message,
    required int logsCount,
    required int backupSize,
  }) = _Success;
  const factory BackupStatus.restoreSuccess({
    required List<FlightLog> logs,
    DateTime? timestamp,
    String? version,
  }) = _RestoreSuccess;
  const factory BackupStatus.deleteSuccess() = _DeleteSuccess;
  const factory BackupStatus.error(String message) = _Error;
}

class _Idle extends BackupStatus {
  const _Idle();
}

class _BackingUp extends BackupStatus {
  const _BackingUp();
}

class _Restoring extends BackupStatus {
  const _Restoring();
}

class _Deleting extends BackupStatus {
  const _Deleting();
}

class _Success extends BackupStatus {
  final String message;
  final int logsCount;
  final int backupSize;
  
  const _Success({
    required this.message,
    required this.logsCount,
    required this.backupSize,
  });
}

class _RestoreSuccess extends BackupStatus {
  final List<FlightLog> logs;
  final DateTime? timestamp;
  final String? version;
  
  const _RestoreSuccess({
    required this.logs,
    this.timestamp,
    this.version,
  });
}

class _DeleteSuccess extends BackupStatus {
  const _DeleteSuccess();
}

class _Error extends BackupStatus {
  final String message;
  
  const _Error(this.message);
}

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

// Network status helper
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.isNotEmpty && results.first != ConnectivityResult.none,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Smart backup recommendation
final backupRecommendationProvider = Provider<BackupRecommendation>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  final lastBackup = ref.watch(lastBackupTimeProvider);
  final autoBackupEnabled = ref.watch(autoBackupEnabledProvider);
  
  return lastBackup.when(
    data: (lastBackupTime) {
      if (!autoBackupEnabled) {
        return const BackupRecommendation.disabled();
      }
      
      if (lastBackupTime == null) {
        return const BackupRecommendation.firstBackup();
      }
      
      final daysSinceLastBackup = DateTime.now().difference(lastBackupTime).inDays;
      
      if (daysSinceLastBackup >= 7) {
        return BackupRecommendation.overdue(daysSinceLastBackup);
      } else if (daysSinceLastBackup >= 3) {
        return BackupRecommendation.recommended(daysSinceLastBackup);
      } else if (!isOnline) {
        return const BackupRecommendation.offline();
      } else {
        return const BackupRecommendation.upToDate();
      }
    },
    loading: () => const BackupRecommendation.loading(),
    error: (_, __) => const BackupRecommendation.error(),
  );
});

// Backup recommendation sealed class
sealed class BackupRecommendation {
  const BackupRecommendation();
  
  const factory BackupRecommendation.disabled() = _RecommendationDisabled;
  const factory BackupRecommendation.firstBackup() = _RecommendationFirstBackup;
  const factory BackupRecommendation.overdue(int days) = _RecommendationOverdue;
  const factory BackupRecommendation.recommended(int days) = _RecommendationRecommended;
  const factory BackupRecommendation.offline() = _RecommendationOffline;
  const factory BackupRecommendation.upToDate() = _RecommendationUpToDate;
  const factory BackupRecommendation.loading() = _RecommendationLoading;
  const factory BackupRecommendation.error() = _RecommendationError;
}

class _RecommendationDisabled extends BackupRecommendation {
  const _RecommendationDisabled();
}

class _RecommendationFirstBackup extends BackupRecommendation {
  const _RecommendationFirstBackup();
}

class _RecommendationOverdue extends BackupRecommendation {
  final int days;
  const _RecommendationOverdue(this.days);
}

class _RecommendationRecommended extends BackupRecommendation {
  final int days;
  const _RecommendationRecommended(this.days);
}

class _RecommendationOffline extends BackupRecommendation {
  const _RecommendationOffline();
}

class _RecommendationUpToDate extends BackupRecommendation {
  const _RecommendationUpToDate();
}

class _RecommendationLoading extends BackupRecommendation {
  const _RecommendationLoading();
}

class _RecommendationError extends BackupRecommendation {
  const _RecommendationError();
}

// Auto backup scheduler for triggering backups when needed
final autoBackupSchedulerProvider = Provider<AutoBackupScheduler>((ref) {
  return AutoBackupScheduler(ref);
});

class AutoBackupScheduler {
  final Ref ref;
  
  AutoBackupScheduler(this.ref);
  
  /// Triggers auto-backup if conditions are met
  Future<void> checkAndPerformAutoBackup() async {
    final config = ref.read(autoBackupConfigProvider);
    if (!config.enabled) return;
    
    // Check if backup should run based on configuration
    if (!_shouldRunBackup(config)) return;
    
    // Check connectivity requirements
    if (config.requiresWifi) {
      final isOnline = ref.read(isOnlineProvider);
      if (!isOnline) return;
    }
    
    // Get flight logs and perform backup
    final flightLogsAsync = ref.read(flightLogsProvider);
    final logs = flightLogsAsync.valueOrNull ?? [];
    
    if (logs.isNotEmpty) {
      final provider = config.preferredProvider;
      await ref.read(backupStatusProvider.notifier).performBackup(logs, provider);
      
      // Update last auto backup time
      final updatedConfig = config.copyWith(lastAutoBackup: DateTime.now());
      await ref.read(autoBackupConfigProvider.notifier).updateConfig(updatedConfig);
    }
  }
  
  bool _shouldRunBackup(AutoBackupConfig config) {
    // Always backup if never backed up
    if (config.lastAutoBackup == null) return true;
    
    switch (config.trigger) {
      case AutoBackupTrigger.timeInterval:
        return config.shouldBackupNow;
      case AutoBackupTrigger.flightAdded:
        // This should be called when a flight is added
        return true;
      case AutoBackupTrigger.appClose:
        // This would be called on app close
        return true;
      case AutoBackupTrigger.combined:
        // Check time interval first
        return config.shouldBackupNow;
    }
  }
  
  /// Called when a new flight is added
  Future<void> onFlightAdded() async {
    final config = ref.read(autoBackupConfigProvider);
    if (!config.enabled) return;
    
    if (config.trigger == AutoBackupTrigger.flightAdded || 
        config.trigger == AutoBackupTrigger.combined) {
      await checkAndPerformAutoBackup();
    }
  }
  
  /// Called when app is about to close
  Future<void> onAppClose() async {
    final config = ref.read(autoBackupConfigProvider);
    if (!config.enabled) return;
    
    if (config.trigger == AutoBackupTrigger.appClose || 
        config.trigger == AutoBackupTrigger.combined) {
      await checkAndPerformAutoBackup();
    }
  }
  
  /// Schedules a delayed auto-backup (useful after adding new flights)
  Future<void> scheduleDelayedBackup({Duration delay = const Duration(minutes: 5)}) async {
    await Future.delayed(delay);
    await checkAndPerformAutoBackup();
  }
  
  /// Gets the next scheduled backup time
  DateTime? getNextBackupTime() {
    final config = ref.read(autoBackupConfigProvider);
    if (!config.enabled || config.lastAutoBackup == null) return null;
    
    final duration = config.interval.duration;
    if (duration == null) return null;
    
    return config.lastAutoBackup!.add(duration);
  }
}

// Auto backup status provider
final autoBackupStatusProvider = Provider<AutoBackupStatus>((ref) {
  final config = ref.watch(autoBackupConfigProvider);
  final scheduler = ref.read(autoBackupSchedulerProvider);
  
  if (!config.enabled) {
    return const AutoBackupStatus.disabled();
  }
  
  final nextBackupTime = scheduler.getNextBackupTime();
  
  if (nextBackupTime == null) {
    switch (config.interval) {
      case AutoBackupInterval.manual:
        return const AutoBackupStatus.manual();
      case AutoBackupInterval.afterEachFlight:
        return const AutoBackupStatus.waitingForFlight();
      default:
        return const AutoBackupStatus.pending();
    }
  }
  
  final now = DateTime.now();
  if (nextBackupTime.isBefore(now)) {
    return AutoBackupStatus.overdue(
      Duration(milliseconds: now.difference(nextBackupTime).inMilliseconds.abs())
    );
  } else {
    return AutoBackupStatus.scheduled(nextBackupTime);
  }
});

sealed class AutoBackupStatus {
  const AutoBackupStatus();
  
  const factory AutoBackupStatus.disabled() = _AutoBackupDisabled;
  const factory AutoBackupStatus.manual() = _AutoBackupManual;
  const factory AutoBackupStatus.pending() = _AutoBackupPending;
  const factory AutoBackupStatus.waitingForFlight() = _AutoBackupWaitingForFlight;
  const factory AutoBackupStatus.scheduled(DateTime nextBackup) = _AutoBackupScheduled;
  const factory AutoBackupStatus.overdue(Duration overdueBy) = _AutoBackupOverdue;
}

class _AutoBackupDisabled extends AutoBackupStatus {
  const _AutoBackupDisabled();
}

class _AutoBackupManual extends AutoBackupStatus {
  const _AutoBackupManual();
}

class _AutoBackupPending extends AutoBackupStatus {
  const _AutoBackupPending();
}

class _AutoBackupWaitingForFlight extends AutoBackupStatus {
  const _AutoBackupWaitingForFlight();
}

class _AutoBackupScheduled extends AutoBackupStatus {
  final DateTime nextBackup;
  const _AutoBackupScheduled(this.nextBackup);
}

class _AutoBackupOverdue extends AutoBackupStatus {
  final Duration overdueBy;
  const _AutoBackupOverdue(this.overdueBy);
}

// Provider to monitor backup health and statistics
final backupStatsProvider = Provider<BackupStats>((ref) {
  final history = ref.watch(backupHistoryProvider);
  final lastBackup = ref.watch(lastBackupTimeProvider);
  final autoEnabled = ref.watch(autoBackupEnabledProvider);
  final isOnline = ref.watch(isOnlineProvider);
  
  return history.when(
    data: (backups) {
      final totalBackups = backups.length;
      final firebaseBackups = backups.where((b) => b.provider == BackupProvider.firebase).length;
      final localBackups = backups.where((b) => b.provider == BackupProvider.local).length;
      final totalSize = backups.fold<int>(0, (sum, backup) => sum + backup.backupSize);
      
      return BackupStats(
        totalBackups: totalBackups,
        firebaseBackups: firebaseBackups,
        localBackups: localBackups,
        totalSizeBytes: totalSize,
        lastBackupTime: lastBackup.valueOrNull,
        autoBackupEnabled: autoEnabled,
        isOnline: isOnline,
      );
    },
    loading: () => BackupStats.loading(),
    error: (_, __) => BackupStats.error(),
  );
});

class BackupStats {
  final int totalBackups;
  final int firebaseBackups;
  final int localBackups;
  final int totalSizeBytes;
  final DateTime? lastBackupTime;
  final bool autoBackupEnabled;
  final bool isOnline;
  final bool isLoading;
  final bool hasError;
  
  const BackupStats({
    required this.totalBackups,
    required this.firebaseBackups,
    required this.localBackups,
    required this.totalSizeBytes,
    required this.lastBackupTime,
    required this.autoBackupEnabled,
    required this.isOnline,
    this.isLoading = false,
    this.hasError = false,
  });
  
  const BackupStats.loading()
      : totalBackups = 0,
        firebaseBackups = 0,
        localBackups = 0,
        totalSizeBytes = 0,
        lastBackupTime = null,
        autoBackupEnabled = false,
        isOnline = false,
        isLoading = true,
        hasError = false;
  
  const BackupStats.error()
      : totalBackups = 0,
        firebaseBackups = 0,
        localBackups = 0,
        totalSizeBytes = 0,
        lastBackupTime = null,
        autoBackupEnabled = false,
        isOnline = false,
        isLoading = false,
        hasError = true;
  
  String get formattedTotalSize {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  String get lastBackupFormatted {
    if (lastBackupTime == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(lastBackupTime!);
    
    if (difference.inDays > 7) {
      return '${lastBackupTime!.day}/${lastBackupTime!.month}/${lastBackupTime!.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

class BackupVerificationResult {
  final int totalBackups;
  final int validBackups;
  final int corruptBackups;
  final DateTime? lastValidBackup;
  final int daysSinceLastValid;
  final bool isHealthy;
  final String? errorMessage;
  
  const BackupVerificationResult({
    required this.totalBackups,
    required this.validBackups,
    required this.corruptBackups,
    required this.lastValidBackup,
    required this.daysSinceLastValid,
    required this.isHealthy,
    this.errorMessage,
  });
  
  const BackupVerificationResult.error(this.errorMessage)
      : totalBackups = 0,
        validBackups = 0,
        corruptBackups = 0,
        lastValidBackup = null,
        daysSinceLastValid = 999,
        isHealthy = false;
  
  double get healthPercentage {
    if (totalBackups == 0) return 0.0;
    return (validBackups / totalBackups) * 100;
  }
  
  String get healthStatus {
    if (errorMessage != null) return 'Error';
    if (isHealthy) return 'Healthy';
    if (corruptBackups > 0) return 'Corrupted backups detected';
    if (daysSinceLastValid > 7) return 'Outdated backups';
    return 'Warning';
  }
}

// Backup alerts and notifications provider
final backupAlertsProvider = StateNotifierProvider<BackupAlertsNotifier, List<BackupAlert>>((ref) {
  return BackupAlertsNotifier(ref);
});

class BackupAlertsNotifier extends StateNotifier<List<BackupAlert>> {
  final Ref ref;
  
  BackupAlertsNotifier(this.ref) : super([]) {
    _checkForAlerts();
  }
  
  Future<void> _checkForAlerts() async {
    final alerts = <BackupAlert>[];
    
    // Check backup recommendation
    final recommendation = ref.read(backupRecommendationProvider);
    switch (recommendation) {
      case _RecommendationOverdue(days: final days):
        alerts.add(BackupAlert.overdue(days));
        break;
      case _RecommendationFirstBackup():
        alerts.add(const BackupAlert.firstBackup());
        break;
      case _RecommendationOffline():
        alerts.add(const BackupAlert.offline());
        break;
      default:
        break;
    }
    
    // Check backup status for errors
    final backupStatus = ref.read(backupStatusProvider);
    if (backupStatus is _Error) {
      alerts.add(BackupAlert.error(backupStatus.message));
    }
    
    // Check storage space (simplified - in real app you'd check actual device storage)
    final stats = ref.read(backupStatsProvider);
    if (stats.totalSizeBytes > 100 * 1024 * 1024) { // >100MB
      alerts.add(const BackupAlert.storageWarning());
    }
    
    state = alerts;
  }
  
  void dismissAlert(BackupAlert alert) {
    state = state.where((a) => a != alert).toList();
  }
  
  void addCustomAlert(BackupAlert alert) {
    state = [...state, alert];
  }
  
  void refreshAlerts() {
    _checkForAlerts();
  }
}

sealed class BackupAlert {
  const BackupAlert();
  
  const factory BackupAlert.overdue(int days) = _AlertOverdue;
  const factory BackupAlert.firstBackup() = _AlertFirstBackup;
  const factory BackupAlert.offline() = _AlertOffline;
  const factory BackupAlert.error(String message) = _AlertError;
  const factory BackupAlert.storageWarning() = _AlertStorageWarning;
  const factory BackupAlert.success(String message) = _AlertSuccess;
}

class _AlertOverdue extends BackupAlert {
  final int days;
  const _AlertOverdue(this.days);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AlertOverdue && runtimeType == other.runtimeType && days == other.days;
  
  @override
  int get hashCode => days.hashCode;
}

class _AlertFirstBackup extends BackupAlert {
  const _AlertFirstBackup();
}

class _AlertOffline extends BackupAlert {
  const _AlertOffline();
}

class _AlertError extends BackupAlert {
  final String message;
  const _AlertError(this.message);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AlertError && runtimeType == other.runtimeType && message == other.message;
  
  @override
  int get hashCode => message.hashCode;
}

class _AlertStorageWarning extends BackupAlert {
  const _AlertStorageWarning();
}

class _AlertSuccess extends BackupAlert {
  final String message;
  const _AlertSuccess(this.message);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AlertSuccess && runtimeType == other.runtimeType && message == other.message;
  
  @override
  int get hashCode => message.hashCode;
}

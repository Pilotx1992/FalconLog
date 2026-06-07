import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backup/models/backup_metadata.dart';
import '../backup/models/backup_provider_enum.dart';
import '../backup/models/backup_status.dart' as operation_status;
import '../backup/services/backup_service.dart';
import '../backup/utils/backup_constants.dart';
import '../backup/utils/backup_provider_preferences.dart';
import '../backup/utils/backup_scheduler.dart';

const _autoBackupTriggerKey = 'falconlog_auto_backup_trigger';
const _maxBackupsKey = 'falconlog_max_backups';

/// Provider for BackupService singleton instance.
final backupServiceProvider = ChangeNotifierProvider<BackupService>((ref) {
  return BackupService();
});

/// Provider for current backup/restore progress.
final currentProgressProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.currentProgress;
});

/// Provider to check if backup is in progress.
final isBackupInProgressProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.isBackupInProgress;
});

/// Provider to check if restore is in progress.
final isRestoreInProgressProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.isRestoreInProgress;
});

/// Provider to check if user is signed in.
final isSignedInProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.isSignedIn;
});

/// Provider for current Google user.
final currentUserProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.currentUser;
});

/// Provider for backup status.
final backupStatusProvider = Provider<BackupStatus>((ref) {
  final progress = ref.watch(currentProgressProvider);
  final status = progress.backupStatus;
  final isSuccess = status == operation_status.BackupStatus.completed;
  final isError = status == operation_status.BackupStatus.failed;
  final isInProgress = status != null &&
      status != operation_status.BackupStatus.idle &&
      !isSuccess &&
      !isError;

  return BackupStatus(
    type: isError
        ? BackupStatusType.error
        : isSuccess
            ? BackupStatusType.success
            : isInProgress
                ? BackupStatusType.inProgress
                : BackupStatusType.idle,
    message: progress.currentAction,
    timestamp: DateTime.now(),
    isSuccess: isSuccess,
  );
});

/// Provider for backup recommendation.
final backupRecommendationProvider = Provider<BackupRecommendation>((ref) {
  final config = ref.watch(autoBackupConfigProvider);
  final history = ref.watch(backupHistoryProvider);

  if (history.isEmpty) {
    return const BackupRecommendation(
      type: BackupRecommendationType.firstBackup,
      message: 'Create your first backup to secure your flight data.',
      isUrgent: true,
    );
  }

  if (config.lastAutoBackup != null) {
    final interval = config.interval.duration;
    if (interval != null &&
        DateTime.now().isAfter(config.lastAutoBackup!.add(interval))) {
      return const BackupRecommendation(
        type: BackupRecommendationType.overdue,
        message: 'Your backup is overdue.',
        isUrgent: true,
      );
    }
  }

  return const BackupRecommendation(
    type: BackupRecommendationType.recommended,
    message: 'Regular backups recommended',
  );
});

/// Provider for online status.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((result) {
    return result.isNotEmpty && result.first != ConnectivityResult.none;
  });
});

/// Provider for selected backup provider.
final backupProviderProvider =
    StateNotifierProvider<BackupProviderNotifier, BackupProvider>((ref) {
  return BackupProviderNotifier();
});

class BackupProviderNotifier extends StateNotifier<BackupProvider> {
  BackupProviderNotifier() : super(BackupProvider.googleDrive) {
    _load();
  }

  Future<void> reload() async {
    state = await BackupProviderPreferences.getSelectedProvider();
  }

  Future<void> _load() => reload();

  Future<void> setProvider(BackupProvider provider) async {
    await BackupProviderPreferences.setSelectedProvider(provider);
    state = provider;
    await BackupProviderPreferences.rescheduleIfAutoBackupEnabled();
  }
}

/// Provider for backup history from the active backup storage.
final backupHistoryProvider =
    StateNotifierProvider<BackupHistoryNotifier, List<BackupInfo>>((ref) {
  final service = ref.watch(backupServiceProvider);
  return BackupHistoryNotifier(service);
});

class BackupHistoryNotifier extends StateNotifier<List<BackupInfo>> {
  BackupHistoryNotifier(this._backupService) : super(const []) {
    refresh();
  }

  final BackupService _backupService;

  Future<void> refresh() async {
    final cloudBackups = await _backupService.listBackups(interactive: false);
    final localBackups = await _loadLocalMetadata();

    final merged = <String, BackupInfo>{};
    for (final backup in [...localBackups, ...cloudBackups]) {
      merged[backup.driveFileId ?? backup.id] = _toBackupInfo(backup);
    }

    final backups = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = backups;
  }

  Future<List<BackupMetadata>> _loadLocalMetadata() async {
    try {
      final box = await Hive.openBox<BackupMetadata>('backupMetadata');
      return box.values.toList();
    } catch (_) {
      return const [];
    }
  }

  BackupInfo _toBackupInfo(BackupMetadata metadata) =>
      BackupInfo.fromMetadata(metadata);
}

/// Provider for auto backup config persisted through BackupScheduler settings.
final autoBackupConfigProvider =
    StateNotifierProvider<AutoBackupConfigNotifier, AutoBackupConfig>((ref) {
  return AutoBackupConfigNotifier();
});

class AutoBackupConfigNotifier extends StateNotifier<AutoBackupConfig> {
  AutoBackupConfigNotifier()
      : super(
          const AutoBackupConfig(
            enabled: false,
            interval: AutoBackupInterval.manual,
            trigger: AutoBackupTrigger.timeInterval,
            requiresWifi: true,
            preferredProvider: BackupProvider.googleDrive,
          ),
        ) {
    _load();
  }

  final BackupScheduler _scheduler = BackupScheduler();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(BackupConstants.settingsKeys['auto_backup_enabled']!) ??
            false;
    final frequency =
        prefs.getString(BackupConstants.settingsKeys['backup_frequency']!) ??
            'off';
    final wifiOnly =
        prefs.getBool(BackupConstants.settingsKeys['wifi_only']!) ?? true;
    final triggerName = prefs.getString(_autoBackupTriggerKey);
    final providerName = prefs.getString(backupSelectedProviderKey);
    final lastBackupMs =
        prefs.getInt(BackupConstants.settingsKeys['last_backup_time']!);

    state = state.copyWith(
      enabled: enabled,
      interval: _intervalFromFrequency(frequency),
      requiresWifi: wifiOnly,
      trigger: AutoBackupTrigger.values.firstWhere(
        (trigger) => trigger.name == triggerName,
        orElse: () => AutoBackupTrigger.timeInterval,
      ),
      maxBackups: prefs.getInt(_maxBackupsKey) ?? state.maxBackups,
      preferredProvider: BackupProvider.values.firstWhere(
        (provider) => provider.name == providerName,
        orElse: () => BackupProvider.googleDrive,
      ),
      lastAutoBackup: lastBackupMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastBackupMs),
    );
  }

  Future<bool> setEnabled(bool enabled) {
    return updateConfig(
      state.copyWith(
        enabled: enabled,
        interval: enabled && state.interval == AutoBackupInterval.manual
            ? AutoBackupInterval.daily
            : state.interval,
      ),
    );
  }

  Future<bool> updateConfig(AutoBackupConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = _frequencyFromInterval(config.interval);
    final scheduled = await _scheduler.scheduleBackup(
      frequency: config.enabled ? frequency : 'off',
      wifiOnly: config.requiresWifi,
    );

    if (!scheduled) {
      return false;
    }

    await prefs.setString(_autoBackupTriggerKey, config.trigger.name);
    await prefs.setInt(_maxBackupsKey, config.maxBackups);
    await prefs.setString(
      backupSelectedProviderKey,
      config.preferredProvider.name,
    );
    state = config;
    return true;
  }

  AutoBackupInterval _intervalFromFrequency(String frequency) {
    switch (frequency) {
      case 'daily':
        return AutoBackupInterval.daily;
      case 'weekly':
        return AutoBackupInterval.weekly;
      case 'monthly':
        return AutoBackupInterval.monthly;
      default:
        return AutoBackupInterval.manual;
    }
  }

  String _frequencyFromInterval(AutoBackupInterval interval) {
    switch (interval) {
      case AutoBackupInterval.daily:
        return 'daily';
      case AutoBackupInterval.weekly:
        return 'weekly';
      case AutoBackupInterval.monthly:
        return 'monthly';
      case AutoBackupInterval.afterEachFlight:
        return 'daily';
      case AutoBackupInterval.manual:
        return 'off';
    }
  }
}

/// Provider for auto backup status.
final autoBackupStatusProvider = Provider<String>((ref) {
  final config = ref.watch(autoBackupConfigProvider);
  return config.enabled ? 'Auto backup enabled' : 'Auto backup disabled';
});

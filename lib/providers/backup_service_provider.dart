import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../backup/services/backup_service.dart';
import '../backup/models/backup_provider_enum.dart';

/// Provider for BackupService singleton instance
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

/// Provider for current backup/restore progress
final currentProgressProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.currentProgress;
});

/// Provider to check if backup is in progress
final isBackupInProgressProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.isBackupInProgress;
});

/// Provider to check if restore is in progress
final isRestoreInProgressProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.isRestoreInProgress;
});

/// Provider to check if user is signed in
final isSignedInProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.isSignedIn;
});

/// Provider for current Google user
final currentUserProvider = Provider((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.currentUser;
});

/// Provider for backup status
final backupStatusProvider = Provider<BackupStatus>((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return BackupStatus(
    message: backupService.currentProgress.currentAction,
    timestamp: DateTime.now(),
    isSuccess: true,
  );
});

/// Provider for backup recommendation
final backupRecommendationProvider = Provider<BackupRecommendation>((ref) {
  return const BackupRecommendation(
    message: 'Regular backups recommended',
    isUrgent: false,
  );
});

/// Provider for online status
final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((result) {
    return result.isNotEmpty && result.first != ConnectivityResult.none;
  });
});

/// Provider for backup provider (cloud/local)
final backupProviderProvider = Provider<BackupProvider>((ref) {
  return BackupProvider.firebase;
});

/// Provider for backup history
final backupHistoryProvider = Provider<List<BackupInfo>>((ref) {
  // Implement backup history retrieval
  return [];
});

/// Provider for auto backup config
final autoBackupConfigProvider = Provider<AutoBackupConfig>((ref) {
  return const AutoBackupConfig();
});

/// Provider for auto backup status
final autoBackupStatusProvider = Provider<String>((ref) {
  final config = ref.watch(autoBackupConfigProvider);
  return config.enabled ? 'Auto backup enabled' : 'Auto backup disabled';
});

import '../models/backup_provider_enum.dart';

/// Restore routing for a backup provider.
enum RestoreRoute {
  googleDrive,
  local,
  unsupported,
}

/// Pure dispatch helpers for provider-based restore (unit-testable).
class RestoreDispatch {
  RestoreDispatch._();

  static RestoreRoute routeForProvider(BackupProvider provider) {
    switch (provider) {
      case BackupProvider.googleDrive:
        return RestoreRoute.googleDrive;
      case BackupProvider.local:
        return RestoreRoute.local;
      case BackupProvider.firebase:
        return RestoreRoute.unsupported;
    }
  }

  static String? unsupportedMessage(BackupProvider provider) {
    if (provider == BackupProvider.firebase) {
      return 'Cloud (Firebase) restore is not supported. '
          'Choose Google Drive or Local Device.';
    }
    return null;
  }

  static bool isLocalBackup(BackupInfo target) =>
      target.provider == BackupProvider.local;

  static bool isCloudBackup(BackupInfo target) =>
      target.provider == BackupProvider.googleDrive;
}

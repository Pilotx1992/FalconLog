/// Identity snapshot for cloud backup/restore safety checks.
class BackupAccountIdentitySnapshot {
  const BackupAccountIdentitySnapshot({
    this.firebaseEmail,
    this.firebaseProviderIds = const [],
    this.googleDriveEmail,
    this.keyOwnerEmail,
  });

  final String? firebaseEmail;
  final List<String> firebaseProviderIds;
  final String? googleDriveEmail;
  final String? keyOwnerEmail;
}

/// Result of a backup identity consistency check.
class BackupIdentityCheckResult {
  const BackupIdentityCheckResult._({
    required this.allowed,
    this.message,
  });

  final bool allowed;
  final String? message;

  factory BackupIdentityCheckResult.allowed() =>
      const BackupIdentityCheckResult._(allowed: true);

  factory BackupIdentityCheckResult.blocked(String message) =>
      BackupIdentityCheckResult._(allowed: false, message: message);
}

/// Prevents cloud backup/restore when Google Drive, Firebase, and key owner disagree.
class BackupAccountIdentityGuard {
  static const String accountMismatchMessage =
      'Backup account mismatch. Please sign in with the same Google account '
      'used for your backups.';

  static const String googleDriveRequiredMessage =
      'Google Drive sign-in is required for cloud backup. '
      'Select the Google account that owns your backups.';

  /// Cloud backup (Google Drive) may proceed only when identities align.
  static BackupIdentityCheckResult checkCloudBackup(
    BackupAccountIdentitySnapshot snapshot,
  ) {
    final driveEmail = _normalize(snapshot.googleDriveEmail);
    if (driveEmail == null) {
      return BackupIdentityCheckResult.blocked(googleDriveRequiredMessage);
    }

    final firebaseEmail = _normalize(snapshot.firebaseEmail);
    if (firebaseEmail != null && firebaseEmail != driveEmail) {
      return BackupIdentityCheckResult.blocked(accountMismatchMessage);
    }

    final ownerEmail = _normalize(snapshot.keyOwnerEmail);
    if (ownerEmail != null && ownerEmail != driveEmail) {
      return BackupIdentityCheckResult.blocked(accountMismatchMessage);
    }

    return BackupIdentityCheckResult.allowed();
  }

  /// Cloud restore requires the active Google account to match the key owner.
  static BackupIdentityCheckResult checkCloudRestore(
    BackupAccountIdentitySnapshot snapshot, {
    String? backupManifestAccountEmail,
  }) {
    final driveEmail = _normalize(snapshot.googleDriveEmail);
    if (driveEmail == null) {
      return BackupIdentityCheckResult.blocked(
        'Google Drive sign-in is required to restore cloud backups.',
      );
    }

    final firebaseEmail = _normalize(snapshot.firebaseEmail);
    if (firebaseEmail != null && firebaseEmail != driveEmail) {
      return BackupIdentityCheckResult.blocked(accountMismatchMessage);
    }

    final ownerEmail = _normalize(snapshot.keyOwnerEmail);
    if (ownerEmail != null && ownerEmail != driveEmail) {
      return BackupIdentityCheckResult.blocked(accountMismatchMessage);
    }

    final manifestEmail = _normalize(backupManifestAccountEmail);
    if (manifestEmail != null && manifestEmail != driveEmail) {
      return BackupIdentityCheckResult.blocked(accountMismatchMessage);
    }

    return BackupIdentityCheckResult.allowed();
  }

  static String? _normalize(String? email) {
    if (email == null) {
      return null;
    }
    final trimmed = email.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }
}

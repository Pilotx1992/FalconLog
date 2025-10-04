/// Base exception class for all backup system errors
class BackupException implements Exception {
  final String message;
  final int? errorCode;
  final dynamic originalError;

  const BackupException(this.message, {this.errorCode, this.originalError});

  @override
  String toString() => 'BackupException: $message';
}

/// Thrown when backup creation fails
class BackupCreationException extends BackupException {
  const BackupCreationException(super.message, {super.errorCode, super.originalError});
}

/// Thrown when backup verification fails
class BackupVerificationException extends BackupException {
  const BackupVerificationException(super.message, {super.errorCode, super.originalError});
}

/// Thrown when backup is not found
class BackupNotFoundException extends BackupException {
  final String backupId;

  const BackupNotFoundException(this.backupId)
      : super('Backup not found: $backupId', errorCode: 1001);
}

/// Thrown when backup is corrupted
class BackupCorruptedException extends BackupException {
  final String backupId;

  const BackupCorruptedException(this.backupId)
      : super('Backup is corrupted: $backupId', errorCode: 1009);
}

/// Thrown when restore operation fails
class RestoreException extends BackupException {
  const RestoreException(super.message, {super.errorCode, super.originalError});
}

/// Thrown when sync operation fails
class SyncException extends BackupException {
  const SyncException(super.message, {super.errorCode, super.originalError});
}

/// Thrown when cloud authentication fails
class CloudAuthenticationException extends SyncException {
  const CloudAuthenticationException(String message)
      : super('Cloud authentication failed: $message', errorCode: 1010);
}

class SilentSignInRequiredException extends CloudAuthenticationException {
  const SilentSignInRequiredException()
      : super('Silent sign-in required for Google Drive');
}

/// Thrown when cloud upload fails
class CloudUploadException extends SyncException {
  const CloudUploadException(String message)
      : super('Cloud upload failed: $message', errorCode: 1003);
}

/// Thrown when cloud download fails
class CloudDownloadException extends SyncException {
  const CloudDownloadException(String message)
      : super('Cloud download failed: $message', errorCode: 1003);
}

/// Thrown when cloud backup is not found
class CloudBackupNotFoundException extends SyncException {
  final String backupId;

  const CloudBackupNotFoundException(this.backupId)
      : super('Cloud backup not found: $backupId', errorCode: 1006);
}

/// Thrown when cloud list operation fails
class CloudListException extends SyncException {
  const CloudListException(String message)
      : super('Cloud list failed: $message', errorCode: 1006);
}

/// Thrown when encryption operation fails
class EncryptionException extends BackupException {
  const EncryptionException(super.message, {super.errorCode, super.originalError});
}

/// Thrown when validation fails
class ValidationException extends BackupException {
  final List<String> errors;
  final List<String> warnings;

  ValidationException(this.errors, {this.warnings = const []})
      : super('Validation failed: ${errors.join(', ')}', errorCode: 1005);
}

/// Thrown when storage operations fail
class StorageException extends BackupException {
  const StorageException(super.message, {super.errorCode, super.originalError});
}

/// Thrown when compression operations fail
class CompressionException extends BackupException {
  const CompressionException(super.message, {int? errorCode, super.originalError})
      : super(errorCode: errorCode ?? 1006);
}

/// Thrown when key derivation operations fail
class KeyDerivationException extends BackupException {
  const KeyDerivationException(super.message, {int? errorCode, super.originalError})
      : super(errorCode: errorCode ?? 1009);
}

/// Thrown when decryption operations fail
class DecryptionException extends BackupException {
  const DecryptionException(super.message, {int? errorCode, super.originalError})
      : super(errorCode: errorCode ?? 1010);
}

/// Thrown when disk is full
class DiskFullException extends StorageException {
  const DiskFullException()
      : super('Insufficient disk space for backup operation', errorCode: 1008);
}

/// Thrown when permission is denied
class PermissionDeniedException extends BackupException {
  const PermissionDeniedException(String resource)
      : super('Permission denied for: $resource', errorCode: 1007);
}

/// Thrown when operation is cancelled by user
class OperationCancelledException extends BackupException {
  const OperationCancelledException()
      : super('Operation was cancelled by user');
}



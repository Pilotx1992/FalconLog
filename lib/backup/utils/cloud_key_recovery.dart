/// Documents how Google Drive backup encryption keys are recovered on a new device.
///
/// "Google key" = the AES-256 master key from [KeyManagerNew.getOrCreatePersistentMasterKey].
///
/// Generation: cryptographically random 256-bit key ([AesGcm] via cryptography package).
///
/// Storage:
/// - Cloud: `falconlog_backup_keys.json` on Google Drive (per Google account email + id).
/// - Local cache: FlutterSecureStorage key `falconlog_master_key_v3` (performance only).
///
/// New-device portability: YES — when the user signs into the **same Google account**,
/// the app downloads the key file from Drive and decrypts backups. Local secure storage
/// on the old phone is not required.
///
/// Failure modes (restore blocked, no silent new key):
/// - Key file exists in Drive but download/parse fails.
/// - Signed-in account does not match key file owner.
/// - Key checksum validation fails.
class CloudKeyRecovery {
  CloudKeyRecovery._();

  static const String keyFileName = 'falconlog_backup_keys.json';
  static const String localCacheKey = 'falconlog_master_key_v3';

  static const String portableRecoverySummary =
      'Google Drive backups are portable across devices for the same Google account. '
      'The master encryption key is stored in Google Drive as falconlog_backup_keys.json.';
}

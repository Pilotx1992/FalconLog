import 'dart:convert';
import 'dart:typed_data';

import '../../services/encryption_service.dart';

/// Encrypts pre-restore safety snapshots with the device-local key.
class PreRestoreSnapshotCrypto {
  PreRestoreSnapshotCrypto._();

  static const String fileSuffix = '.pre_restore.crypt14';

  /// Returns encrypted file bytes, or an error message if encryption cannot proceed.
  static Future<({Uint8List? bytes, String? error})> encryptPayload({
    required Map<String, dynamic> payload,
    required String snapshotId,
    required EncryptionService encryptionService,
    required Future<Uint8List?> Function() getDeviceKey,
  }) async {
    final masterKey = await getDeviceKey();
    if (masterKey == null) {
      return (
        bytes: null,
        error:
            'Could not create safety snapshot. Device encryption key is unavailable.',
      );
    }

    final databaseBytes = Uint8List.fromList(utf8.encode(json.encode(payload)));
    final encryptedBackup = await encryptionService.encryptDatabase(
      databaseBytes: databaseBytes,
      masterKey: masterKey,
      backupId: snapshotId,
    );

    if (encryptedBackup == null) {
      return (
        bytes: null,
        error: 'Could not create safety snapshot. Encryption failed.',
      );
    }

    final bytes = Uint8List.fromList(utf8.encode(json.encode(encryptedBackup)));
    return (bytes: bytes, error: null);
  }
}

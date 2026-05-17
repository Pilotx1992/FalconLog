import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../services/encryption_service.dart';
import '../utils/backup_constants.dart';
import 'pre_restore_snapshot_crypto.dart';

/// Creates and reads encrypted pre-restore safety snapshots.
class PreRestoreSnapshotService {
  PreRestoreSnapshotService({
    required EncryptionService encryptionService,
    required Future<Uint8List?> Function() getDeviceKey,
  })  : _encryptionService = encryptionService,
        _getDeviceKey = getDeviceKey;

  final EncryptionService _encryptionService;
  final Future<Uint8List?> Function() _getDeviceKey;

  Future<({String? path, String? error})> savePayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      final snapshotId = const Uuid().v4();
      final encrypted = await PreRestoreSnapshotCrypto.encryptPayload(
        payload: payload,
        snapshotId: snapshotId,
        encryptionService: _encryptionService,
        getDeviceKey: _getDeviceKey,
      );
      if (encrypted.error != null) {
        return (path: null, error: encrypted.error);
      }

      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
        p.join(appDir.path, BackupConstants.localBackupsFolder, 'pre_restore'),
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(
        p.join(
          dir.path,
          'pre_restore_${DateTime.now().millisecondsSinceEpoch}${PreRestoreSnapshotCrypto.fileSuffix}',
        ),
      );
      await file.writeAsBytes(encrypted.bytes!, flush: true);

      if (kDebugMode) {
        debugPrint('💾 Pre-restore snapshot: ${file.path}');
      }
      return (path: file.path, error: null);
    } catch (e) {
      return (
        path: null,
        error: 'Could not create safety snapshot before replace restore: $e',
      );
    }
  }

  Future<({Map<String, dynamic>? payload, String? error})> readPayload(
    String snapshotPath,
  ) async {
    try {
      final file = File(snapshotPath);
      if (!await file.exists()) {
        return (payload: null, error: 'Pre-restore snapshot file is missing.');
      }

      final encryptedBytes = await file.readAsBytes();
      if (encryptedBytes.isEmpty) {
        return (payload: null, error: 'Pre-restore snapshot file is empty.');
      }

      final encryptedBackup = json.decode(utf8.decode(encryptedBytes));
      if (encryptedBackup is! Map<String, dynamic>) {
        return (payload: null, error: 'Invalid pre-restore snapshot format.');
      }

      final masterKey = await _getDeviceKey();
      if (masterKey == null) {
        return (
          payload: null,
          error: 'Device encryption key unavailable for rollback.',
        );
      }

      final databaseBytes = await _encryptionService.decryptDatabase(
        encryptedBackup: encryptedBackup,
        masterKey: masterKey,
      );
      if (databaseBytes == null) {
        return (
          payload: null,
          error: 'Failed to decrypt pre-restore snapshot.',
        );
      }

      final payload =
          json.decode(utf8.decode(databaseBytes)) as Map<String, dynamic>;
      return (payload: payload, error: null);
    } catch (e) {
      return (payload: null, error: 'Failed to read pre-restore snapshot: $e');
    }
  }
}

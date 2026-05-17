import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/hive_initialization_service.dart';
import '../../models/flight_log.dart';
import '../../services/encryption_service.dart';
import '../models/backup_metadata.dart';
import '../models/backup_provider_enum.dart' show BackupInfo, BackupProvider;
import '../models/backup_status.dart';
import '../models/restore_mode.dart';
import '../models/restore_result.dart';
export '../models/restore_mode.dart';
import '../utils/backup_constants.dart';
import '../utils/backup_payload_codec.dart';
import '../utils/backup_provider_preferences.dart';
import '../utils/pre_restore_snapshot_service.dart';
import '../utils/replace_restore_transaction.dart';
import '../utils/restore_dispatch.dart';
import 'google_drive_service.dart';
import 'key_manager.dart';

/// Simplified backup service following AlKhazna's approach
class BackupService extends ChangeNotifier {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;

  final GoogleDriveService _driveService = GoogleDriveService();
  final EncryptionService _encryptionService = EncryptionService();
  late final KeyManagerNew _keyManager;

  BackupService._internal() {
    // Initialize KeyManager with GoogleSignIn from DriveService
    _keyManager = KeyManagerNew(
      _driveService,
      GoogleSignIn(
        scopes: [
          'https://www.googleapis.com/auth/drive.appdata',
          'email',
          'profile',
        ],
      ),
    );
  }

  OperationProgress _currentProgress = const OperationProgress(
    percentage: 0,
    backupStatus: BackupStatus.idle,
    currentAction: 'Ready',
  );

  bool _isBackupInProgress = false;
  bool _isRestoreInProgress = false;

  OperationProgress get currentProgress => _currentProgress;
  bool get isBackupInProgress => _isBackupInProgress;
  bool get isRestoreInProgress => _isRestoreInProgress;

  static const String _backupPrefix = 'falconlog_backup_';

  /// Initialize the backup service for the currently selected provider.
  Future<bool> initialize({bool interactive = true}) async {
    try {
      final provider = await BackupProviderPreferences.getSelectedProvider();
      switch (provider) {
        case BackupProvider.googleDrive:
          return _driveService.initialize(interactive: interactive);
        case BackupProvider.local:
          return true;
        case BackupProvider.firebase:
          return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Failed to initialize backup service: $e');
      }
      return false;
    }
  }

  /// Start backup using the persisted provider selection.
  Future<bool> startBackup({bool interactive = true}) async {
    if (_isBackupInProgress) {
      if (kDebugMode) {
        print('⚠️ Backup already in progress, skipping...');
      }
      return false;
    }

    if (_isRestoreInProgress) {
      if (kDebugMode) {
        print('⚠️ Restore in progress, cannot start backup');
      }
      return false;
    }

    _isBackupInProgress = true;

    try {
      final provider = await BackupProviderPreferences.getSelectedProvider();
      if (kDebugMode) {
        print('🐛 DEBUG: Backup started with provider: ${provider.name}');
      }

      switch (provider) {
        case BackupProvider.googleDrive:
          return await _startGoogleDriveBackup(interactive: interactive);
        case BackupProvider.local:
          return await _startLocalBackup(interactive: interactive);
        case BackupProvider.firebase:
          _updateProgress(
            0,
            BackupStatus.failed,
            'Cloud (Firebase) backup is not supported. Choose Google Drive or Local.',
          );
          return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Backup failed: $e');
        print('💥 Stack trace: ${StackTrace.current}');
      }
      _updateProgress(0, BackupStatus.failed, 'Backup failed: ${e.toString()}');
      return false;
    } finally {
      _isBackupInProgress = false;
    }
  }

  Future<bool> _startGoogleDriveBackup({required bool interactive}) async {
    _updateProgress(
        0, BackupStatus.checkingConnectivity, 'Checking connectivity...');

    final isConnected = await _checkConnectivity(interactive: interactive);
    if (!isConnected) {
      _updateProgress(0, BackupStatus.failed, 'No internet connection');
      return false;
    }

    _updateProgress(
        10, BackupStatus.initializingDrive, 'Connecting to Google Drive...');
    final driveInitialized =
        await _driveService.initialize(interactive: interactive);
    if (!driveInitialized) {
      _updateProgress(
          0, BackupStatus.failed, 'Failed to connect to Google Drive');
      return false;
    }

    final payload = await _prepareEncryptedBackup(
      interactive: interactive,
      useDeviceKey: false,
    );
    if (payload == null) {
      return false;
    }

    _updateProgress(70, BackupStatus.uploading, 'Uploading to Google Drive...');
    final fileName =
        '$_backupPrefix${DateTime.now().millisecondsSinceEpoch}.crypt14';
    final driveFileId = await _driveService.uploadFile(
      fileName: fileName,
      content: payload.encryptedBytes,
      mimeType: 'application/json',
    );

    if (driveFileId == null) {
      _updateProgress(0, BackupStatus.failed, 'Failed to upload backup');
      return false;
    }

    await _pruneOldBackups(keep: 5);

    _updateProgress(90, BackupStatus.uploading, 'Finalizing backup...');
    await _saveBackupMetadata(
      backupId: payload.backupId,
      driveFileId: driveFileId,
      fileName: fileName,
      originalSize: payload.originalSize,
      encryptedSize: payload.encryptedBytes.length,
      flightLogsCount: payload.flightLogsCount,
      location: BackupLocation.cloud,
    );
    await _recordSuccessfulBackup();

    _updateProgress(
        100, BackupStatus.completed, 'Backup completed successfully!');
    return true;
  }

  Future<bool> _startLocalBackup({required bool interactive}) async {
    _updateProgress(10, BackupStatus.creatingBackup, 'Preparing local backup...');

    final payload = await _prepareEncryptedBackup(
      interactive: interactive,
      useDeviceKey: true,
    );
    if (payload == null) {
      return false;
    }

    _updateProgress(70, BackupStatus.uploading, 'Saving backup on device...');
    final fileName =
        '$_backupPrefix${DateTime.now().millisecondsSinceEpoch}.crypt14';
    final localPath = await _writeLocalBackupFile(
      fileName: fileName,
      content: payload.encryptedBytes,
    );
    if (localPath == null) {
      _updateProgress(0, BackupStatus.failed, 'Failed to save local backup');
      return false;
    }

    await _pruneLocalBackups(keep: BackupConstants.defaultKeepCount);

    _updateProgress(90, BackupStatus.uploading, 'Finalizing backup...');
    await _saveBackupMetadata(
      backupId: payload.backupId,
      driveFileId: null,
      localPath: localPath,
      fileName: fileName,
      originalSize: payload.originalSize,
      encryptedSize: payload.encryptedBytes.length,
      flightLogsCount: payload.flightLogsCount,
      location: BackupLocation.local,
    );
    await _recordSuccessfulBackup();

    _updateProgress(
        100, BackupStatus.completed, 'Local backup completed successfully!');
    return true;
  }

  Future<_EncryptedBackupPayload?> _prepareEncryptedBackup({
    required bool interactive,
    required bool useDeviceKey,
  }) async {
    _updateProgress(20, BackupStatus.gettingKey, 'Preparing encryption...');

    final backupId = const Uuid().v4();

    _updateProgress(30, BackupStatus.creatingBackup, 'Preparing your data...');
    final databaseBytes = await _createDatabaseBackup(backupId: backupId);
    if (databaseBytes == null) {
      _updateProgress(0, BackupStatus.failed, 'Failed to create database backup');
      return null;
    }

    _updateProgress(45, BackupStatus.encrypting, 'Getting encryption key...');
    final masterKey = useDeviceKey
        ? await _keyManager.getOrCreateDeviceMasterKey()
        : await _keyManager.getOrCreatePersistentMasterKey(
            interactive: interactive,
          );
    if (masterKey == null) {
      _updateProgress(0, BackupStatus.failed, 'Failed to get encryption key');
      return null;
    }

    _updateProgress(50, BackupStatus.encrypting, 'Encrypting your data...');
    final encryptedBackup = await _encryptionService.encryptDatabase(
      databaseBytes: databaseBytes,
      masterKey: masterKey,
      backupId: backupId,
    );
    if (encryptedBackup == null) {
      _updateProgress(0, BackupStatus.failed, 'Failed to encrypt data');
      return null;
    }

    final encryptedBytes =
        Uint8List.fromList(utf8.encode(json.encode(encryptedBackup)));

    return _EncryptedBackupPayload(
      backupId: backupId,
      encryptedBytes: encryptedBytes,
      originalSize: databaseBytes.length,
      flightLogsCount: await _countFlightLogs(),
    );
  }

  Future<String?> _writeLocalBackupFile({
    required String fileName,
    required Uint8List content,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(
        p.join(appDir.path, BackupConstants.localBackupsFolder),
      );
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File(p.join(backupDir.path, fileName));
      await file.writeAsBytes(content, flush: true);
      return file.path;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error writing local backup: $e');
      }
      return null;
    }
  }

  Future<void> _pruneLocalBackups({int keep = 5}) async {
    try {
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      final localEntries = box.values
          .where((entry) => entry.location == BackupLocation.local)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final entry in localEntries.skip(keep)) {
        if (entry.localPath != null) {
          final file = File(entry.localPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
        await box.delete(entry.id);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Local retention prune error: $e');
      }
    }
  }

  /// Restore from a specific backup entry, or the latest for the selected provider.
  Future<RestoreResult> startRestore({
    RestoreMode mode = RestoreMode.merge,
    BackupInfo? target,
    bool interactive = true,
  }) async {
    if (_isRestoreInProgress) {
      return RestoreResult.failure(error: 'Restore already in progress');
    }

    if (_isBackupInProgress) {
      return RestoreResult.failure(
        error: 'Backup operation in progress. Please wait.',
      );
    }

    _isRestoreInProgress = true;

    try {
      final resolved = target ?? await resolveDefaultRestoreTarget();
      if (resolved == null) {
        return RestoreResult.failure(
          error: 'No backup found to restore for the selected location.',
        );
      }

      final unsupported = RestoreDispatch.unsupportedMessage(resolved.provider);
      if (unsupported != null) {
        _updateProgress(0, null, unsupported, RestoreStatus.failed);
        return RestoreResult.failure(error: unsupported);
      }

      switch (RestoreDispatch.routeForProvider(resolved.provider)) {
        case RestoreRoute.googleDrive:
          return await _restoreFromGoogleDrive(
            resolved,
            mode: mode,
            interactive: interactive,
          );
        case RestoreRoute.local:
          return await _restoreFromLocal(resolved, mode: mode);
        case RestoreRoute.unsupported:
          return RestoreResult.failure(
            error: RestoreDispatch.unsupportedMessage(
                  BackupProvider.firebase,
                ) ??
                'Unsupported backup provider.',
          );
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Restore failed: $e');
      }
      _updateProgress(0, null, 'Restore failed', RestoreStatus.failed);
      return RestoreResult.failure(error: 'Restore failed: ${e.toString()}');
    } finally {
      _isRestoreInProgress = false;
    }
  }

  /// Latest backup for the active provider as a [BackupInfo].
  Future<BackupInfo?> resolveDefaultRestoreTarget() async {
    final metadata = await findExistingBackup();
    return metadata == null ? null : BackupInfo.fromMetadata(metadata);
  }

  Future<RestoreResult> _restoreFromGoogleDrive(
    BackupInfo target, {
    required RestoreMode mode,
    required bool interactive,
  }) async {
    _updateProgress(
      0,
      null,
      'Checking connection...',
      RestoreStatus.checkingConnectivity,
    );

    final isConnected = await _checkConnectivity(interactive: interactive);
    if (!isConnected) {
      _updateProgress(0, null, 'No internet connection', RestoreStatus.failed);
      return RestoreResult.failure(
        error: 'No internet connection. Google Drive restore requires network.',
      );
    }

    _updateProgress(
      10,
      null,
      'Connecting to Google Drive...',
      RestoreStatus.initializingDrive,
    );
    if (!await _driveService.initialize(interactive: interactive)) {
      _updateProgress(
        0,
        null,
        'Google Drive sign-in required',
        RestoreStatus.failed,
      );
      return RestoreResult.failure(
        error:
            'Google Drive authentication is unavailable. Sign in and try again.',
      );
    }

    final driveFileId = target.driveFileId ?? target.id;
    _updateProgress(
      30,
      null,
      'Downloading backup...',
      RestoreStatus.downloading,
    );

    final encryptedBytes = await _driveService.downloadFile(driveFileId);
    if (encryptedBytes == null) {
      _updateProgress(
        0,
        null,
        'Failed to download backup',
        RestoreStatus.failed,
      );
      return RestoreResult.failure(
        error: 'Failed to download backup from Google Drive.',
      );
    }

    return _decryptValidateAndApply(
      encryptedFileBytes: encryptedBytes,
      mode: mode,
      useDeviceKey: false,
      interactive: interactive,
      backupDate: target.createdAt,
      sourceDevice: 'Google Drive',
      backupTargetId: target.metadataId,
    );
  }

  Future<RestoreResult> _restoreFromLocal(
    BackupInfo target, {
    required RestoreMode mode,
  }) async {
    _updateProgress(
      10,
      null,
      'Locating local backup...',
      RestoreStatus.findingBackup,
    );

    final localPath = await _resolveLocalBackupPath(target);
    if (localPath == null) {
      _updateProgress(
        0,
        null,
        'Local backup file missing',
        RestoreStatus.failed,
      );
      return RestoreResult.failure(
        error:
            'Local backup file is missing. The file may have been deleted or moved.',
      );
    }

    final file = File(localPath);
    if (!await file.exists()) {
      _updateProgress(
        0,
        null,
        'Local backup file missing',
        RestoreStatus.failed,
      );
      return RestoreResult.failure(
        error:
            'Local backup file not found at: $localPath',
      );
    }

    _updateProgress(
      30,
      null,
      'Reading local backup...',
      RestoreStatus.downloading,
    );

    Uint8List encryptedBytes;
    try {
      encryptedBytes = await file.readAsBytes();
    } catch (e) {
      return RestoreResult.failure(
        error: 'Failed to read local backup file: $e',
      );
    }

    if (encryptedBytes.isEmpty) {
      return RestoreResult.failure(
        error: 'Local backup file is empty or corrupted.',
      );
    }

    return _decryptValidateAndApply(
      encryptedFileBytes: encryptedBytes,
      mode: mode,
      useDeviceKey: true,
      interactive: false,
      backupDate: target.createdAt,
      sourceDevice: 'Local device',
      backupTargetId: target.metadataId,
    );
  }

  Future<String?> _resolveLocalBackupPath(BackupInfo target) async {
    if (target.localPath != null && await File(target.localPath!).exists()) {
      return target.localPath;
    }

    final metadata = await _lookupBackupMetadata(target);
    if (metadata?.localPath != null &&
        await File(metadata!.localPath!).exists()) {
      return metadata.localPath;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final candidate = File(
      p.join(appDir.path, BackupConstants.localBackupsFolder, target.fileName),
    );
    if (await candidate.exists()) {
      return candidate.path;
    }

    return null;
  }

  Future<BackupMetadata?> _lookupBackupMetadata(BackupInfo target) async {
    try {
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      for (final entry in box.values) {
        if (entry.id == target.metadataId ||
            entry.id == target.id ||
            entry.driveFileId == target.driveFileId ||
            entry.driveFileId == target.id) {
          return entry;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Validates encrypted payload, decrypts, then applies — never clears data before validation.
  Future<RestoreResult> _decryptValidateAndApply({
    required Uint8List encryptedFileBytes,
    required RestoreMode mode,
    required bool useDeviceKey,
    required bool interactive,
    required DateTime backupDate,
    required String sourceDevice,
    required String backupTargetId,
  }) async {
    _updateProgress(
      50,
      null,
      'Validating backup...',
      RestoreStatus.decrypting,
    );

    Map<String, dynamic> encryptedBackup;
    try {
      encryptedBackup =
          json.decode(utf8.decode(encryptedFileBytes)) as Map<String, dynamic>;
    } catch (e) {
      _updateProgress(0, null, 'Invalid backup format', RestoreStatus.failed);
      return RestoreResult.failure(
        error:
            'Invalid or corrupted backup payload. The file format is not recognized.',
      );
    }

    if (!_verifyBackupIntegrity(encryptedBackup)) {
      _updateProgress(0, null, 'Backup corrupted', RestoreStatus.failed);
      return RestoreResult.failure(
        error:
            'Backup failed integrity check. Please try another backup from Recent Backups.',
      );
    }

    _updateProgress(
      60,
      null,
      'Getting encryption key...',
      RestoreStatus.retrievingKey,
    );

    final masterKey = useDeviceKey
        ? await _keyManager.getOrCreateDeviceMasterKey()
        : await _keyManager.getOrCreatePersistentMasterKey(
            interactive: interactive,
          );

    if (masterKey == null) {
      _updateProgress(0, null, 'Failed to get encryption key', RestoreStatus.failed);
      return RestoreResult.failure(
        error: useDeviceKey
            ? 'Failed to get device encryption key. Restore this backup on the same device.'
            : 'Failed to get encryption key. Sign in to Google and try again.',
      );
    }

    _updateProgress(70, null, 'Decrypting backup...', RestoreStatus.decrypting);

    final databaseBytes = await _encryptionService.decryptDatabase(
      encryptedBackup: encryptedBackup,
      masterKey: masterKey,
    );

    if (databaseBytes == null) {
      _updateProgress(0, null, 'Decrypt failed', RestoreStatus.failed);
      return RestoreResult.failure(
        error:
            'Failed to decrypt backup. The encryption key may not match this device or account.',
      );
    }

    final payloadError = BackupPayloadCodec.validatePayloadBytes(databaseBytes);
    if (payloadError != null) {
      _updateProgress(0, null, 'Invalid backup payload', RestoreStatus.failed);
      return RestoreResult.failure(error: payloadError);
    }

    _updateProgress(85, null, 'Restoring your data...', RestoreStatus.applying);
    final restoreResult = await _restoreDatabase(
      databaseBytes,
      mode: mode,
      backupTargetId: backupTargetId,
    );

    if (!restoreResult.success) {
      _updateProgress(0, null, 'Failed to restore data', RestoreStatus.failed);
      return restoreResult;
    }

    _updateProgress(100, null, 'Restore completed!', RestoreStatus.completed);

    return RestoreResult.success(
      flightLogsRestored: restoreResult.flightLogsRestored,
      backupDate: backupDate,
      sourceDevice: sourceDevice,
    );
  }

  /// Keep only last [keep] backups in Drive (by modifiedTime desc)
  Future<void> _pruneOldBackups({int keep = 5}) async {
    try {
      final files = await _driveService.listFiles(
          query: "name contains '$_backupPrefix'");
      if (files.length <= keep) return;
      for (var i = keep; i < files.length; i++) {
        final f = files[i];
        if (f.id != null) {
          await _driveService.deleteFile(f.id!);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Retention prune error: $e');
      }
    }
  }

  /// Latest backup for the currently selected provider.
  Future<BackupMetadata?> findExistingBackup() async {
    final provider = await BackupProviderPreferences.getSelectedProvider();
    switch (provider) {
      case BackupProvider.local:
        return _findLatestLocalBackupMetadata();
      case BackupProvider.googleDrive:
        return _findLatestGoogleDriveBackupMetadata(interactive: false);
      case BackupProvider.firebase:
        return null;
    }
  }

  Future<BackupMetadata?> _findLatestLocalBackupMetadata() async {
    try {
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      final localEntries = box.values
          .where((entry) => entry.location == BackupLocation.local)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return localEntries.isEmpty ? null : localEntries.first;
    } catch (_) {
      return null;
    }
  }

  Future<BackupMetadata?> _findLatestGoogleDriveBackupMetadata({
    bool interactive = false,
  }) async {
    try {
      if (!await _driveService.initialize(interactive: interactive)) {
        return null;
      }

      final backupFiles = await _driveService.listFiles(
          query: "name contains '$_backupPrefix'");

      if (backupFiles.isEmpty) {
        return null;
      }

      final backupFile = backupFiles.first;

      // Get detailed file info to ensure we have the correct size
      final detailedFileInfo = await _driveService.getFileInfo(backupFile.id!);
      final fileSize =
          int.tryParse(detailedFileInfo?.size ?? backupFile.size ?? '0') ?? 0;

      if (kDebugMode) {
        print('📊 Backup file size from API: ${backupFile.size}');
        print('📊 Detailed file size: ${detailedFileInfo?.size}');
        print('📊 Final file size: $fileSize bytes');
      }

      return BackupMetadata(
        id: backupFile.id!,
        fileName: backupFile.name!,
        location: BackupLocation.cloud,
        createdAt: backupFile.modifiedTime ?? DateTime.now(),
        sizeBytes: fileSize,
        flightLogsCount: 0,
        checksum: 'unknown',
        driveFileId: backupFile.id!,
        isEncrypted: true,
        encryptionAlgorithm: 'AES-256-GCM',
        health: BackupHealth.healthy,
        deviceId: 'Unknown Device',
      );
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error finding backup: $e');
      }
      return null;
    }
  }

  /// List available cloud backups from the active Google Drive AppData storage.
  Future<List<BackupMetadata>> listBackups({bool interactive = false}) async {
    try {
      if (!await _driveService.initialize(interactive: interactive)) {
        return [];
      }

      final backupFiles = await _driveService.listFiles(
          query: "name contains '$_backupPrefix'");

      return backupFiles
          .where((file) => file.id != null && file.name != null)
          .map((file) {
        final fileSize = int.tryParse(file.size ?? '0') ?? 0;
        return BackupMetadata(
          id: file.id!,
          fileName: file.name!,
          location: BackupLocation.cloud,
          createdAt: file.modifiedTime ?? file.createdTime ?? DateTime.now(),
          sizeBytes: fileSize,
          flightLogsCount: 0,
          checksum: 'unknown',
          driveFileId: file.id!,
          isEncrypted: true,
          encryptionAlgorithm: 'AES-256-GCM',
          health: BackupHealth.unverified,
          deviceId: 'Unknown Device',
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error listing backups: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> _buildBackupPayload({
    required String backupId,
    BackupProvider? providerOverride,
  }) {
    return BackupPayloadCodec.buildPayload(
      backupId: backupId,
      providerOverride: providerOverride,
      accountEmail: _driveService.currentUser?.email,
    );
  }

  Future<Uint8List?> _createDatabaseBackup({required String backupId}) async {
    final payload = await _buildBackupPayload(backupId: backupId);
    if (payload == null) {
      return null;
    }

    final jsonString = json.encode(payload);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  PreRestoreSnapshotService get _preRestoreSnapshotService =>
      PreRestoreSnapshotService(
        encryptionService: _encryptionService,
        getDeviceKey: _keyManager.getOrCreateDeviceMasterKey,
      );

  ReplaceRestoreTransaction _createReplaceTransaction() {
    final snapshotService = _preRestoreSnapshotService;
    return ReplaceRestoreTransaction(
      createSnapshot: () async {
        final payload = await _buildBackupPayload(backupId: const Uuid().v4());
        if (payload == null) {
          return (
            path: null,
            error: 'Could not create safety snapshot before replace restore.',
          );
        }
        return snapshotService.savePayload(payload);
      },
      applyBackupPayload: (data) => BackupPayloadCodec.applyPayload(
        backupData: data,
        mode: RestoreMode.replace,
      ),
      rollbackFromSnapshot: _rollbackFromPreRestoreSnapshot,
    );
  }

  Future<({bool ok, String? error})> _rollbackFromPreRestoreSnapshot(
    String snapshotPath,
    int expectedFlightCount,
  ) async {
    final read = await _preRestoreSnapshotService.readPayload(snapshotPath);
    if (read.error != null) {
      return (ok: false, error: read.error);
    }

    final rollbackApply = await BackupPayloadCodec.applyPayload(
      backupData: read.payload!,
      mode: RestoreMode.replace,
    );
    if (!rollbackApply.success) {
      return (
        ok: false,
        error: rollbackApply.error ?? 'Rollback apply failed.',
      );
    }

    final count = await _countFlightLogs();
    if (expectedFlightCount > 0 && count != expectedFlightCount) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Rollback flight count mismatch: expected $expectedFlightCount, got $count',
        );
      }
    }

    return (ok: true, error: null);
  }

  /// Attempt rollback when app starts with a pending restore journal.
  static Future<PendingRestoreRecoveryResult>
      recoverPendingReplaceRestoreIfNeeded() async {
    final service = BackupService();
    return ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: service._rollbackFromPreRestoreSnapshot,
    );
  }

  /// Restore database from backup (settings → aircraft → flight logs).
  Future<RestoreResult> _restoreDatabase(
    Uint8List databaseBytes, {
    RestoreMode mode = RestoreMode.merge,
    required String backupTargetId,
  }) async {
    try {
      if (kDebugMode) {
        print('💾 Restoring from backup (mode: ${mode.name})...');
      }

      if (databaseBytes.isEmpty) {
        return RestoreResult.success(
          flightLogsRestored: 0,
          backupDate: DateTime.now(),
          sourceDevice: 'Unknown Device',
        );
      }

      final backupData =
          json.decode(utf8.decode(databaseBytes)) as Map<String, dynamic>;

      final targetId = backupTargetId.isNotEmpty
          ? backupTargetId
          : _backupIdFromPayload(backupData);

      if (mode == RestoreMode.replace) {
        final txResult = await _createReplaceTransaction().execute(
          backupData: backupData,
          backupTargetId: targetId,
        );

        if (!txResult.success) {
          return RestoreResult.failure(error: txResult.error);
        }

        if (kDebugMode) {
          print(
            '✅ Replace restored ${txResult.flightLogsRestored} flights '
            '(rolledBack=${txResult.rolledBack})',
          );
        }

        return RestoreResult.success(
          flightLogsRestored: txResult.flightLogsRestored,
          backupDate: DateTime.now(),
          sourceDevice: 'Unknown Device',
        );
      }

      final applyResult = await BackupPayloadCodec.applyPayload(
        backupData: backupData,
        mode: mode,
      );

      if (!applyResult.success) {
        return RestoreResult.failure(
          error: applyResult.error ?? 'Failed to restore database.',
        );
      }

      if (kDebugMode) {
        print(
          '✅ Restored ${applyResult.flightLogsRestored} flights, '
          '${applyResult.aircraftTypesRestored} aircraft types, '
          '${applyResult.settingsRestored} settings',
        );
      }

      return RestoreResult.success(
        flightLogsRestored: applyResult.flightLogsRestored,
        backupDate: DateTime.now(),
        sourceDevice: 'Unknown Device',
      );
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error restoring database: $e');
      }
      return RestoreResult.failure(
        error: 'Failed to restore database: ${e.toString()}',
      );
    }
  }

  /// Save backup metadata
  Future<void> _saveBackupMetadata({
    required String backupId,
    required String fileName,
    required int originalSize,
    required int encryptedSize,
    required int flightLogsCount,
    required BackupLocation location,
    String? driveFileId,
    String? localPath,
  }) async {
    try {
      final currentUser = _driveService.currentUser;
      final metadata = BackupMetadata(
        id: backupId,
        fileName: fileName,
        location: location,
        createdAt: DateTime.now(),
        sizeBytes: encryptedSize,
        flightLogsCount: flightLogsCount,
        checksum: 'unknown',
        driveFileId: driveFileId,
        localPath: localPath,
        isEncrypted: true,
        encryptionAlgorithm: 'AES-256-GCM',
        health: BackupHealth.unverified,
        deviceId: currentUser?.email ?? 'This device',
      );

      final metadataBox =
          await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      await metadataBox.put(backupId, metadata);

      if (kDebugMode) {
        print('💾 Backup metadata:');
        print('   ID: $backupId');
        print('   Drive File ID: $driveFileId');
        print('   User: ${currentUser?.email}');
        print('   Original size: $originalSize bytes');
        print('   Encrypted size: $encryptedSize bytes');
        print('   Flight logs: $flightLogsCount');
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error saving backup metadata: $e');
      }
    }
  }

  static String _backupIdFromPayload(Map<String, dynamic> backupData) {
    final manifest = backupData['manifest'];
    if (manifest is Map && manifest['backup_id'] is String) {
      return manifest['backup_id'] as String;
    }
    return 'unknown';
  }

  Future<int> _countFlightLogs() async {
    try {
      final box = await Hive.openBox<FlightLog>('flightLogsBox');
      return box.length;
    } catch (_) {
      return 0;
    }
  }

  /// Check network connectivity with retries
  Future<bool> _checkConnectivity({bool interactive = true}) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection =
          connectivityResult.contains(ConnectivityResult.mobile) ||
              connectivityResult.contains(ConnectivityResult.wifi);

      if (!hasConnection) {
        if (kDebugMode) {
          print('⚠️ No network connection detected');
        }
        return false;
      }

      // Verify actual internet access by testing Drive API
      try {
        final driveInitialized =
            await _driveService.initialize(interactive: interactive);
        if (!driveInitialized) {
          if (kDebugMode) {
            print('⚠️ Network available but cannot reach Google Drive');
          }
          return false;
        }
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Network connectivity verification failed: $e');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error checking connectivity: $e');
      }
      return false;
    }
  }

  Future<void> _recordSuccessfulBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      BackupConstants.settingsKeys['last_backup_time']!,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Update progress and notify listeners
  void _updateProgress(
      int percentage, BackupStatus? backupStatus, String action,
      [RestoreStatus? restoreStatus]) {
    _currentProgress = OperationProgress(
      percentage: percentage,
      backupStatus: backupStatus,
      restoreStatus: restoreStatus,
      currentAction: action,
    );
    notifyListeners();
  }

  /// Cancel current operation
  Future<void> cancelCurrentOperation() async {
    if (_isBackupInProgress) {
      _updateProgress(_currentProgress.percentage, BackupStatus.cancelled,
          'Backup cancelled');
      _isBackupInProgress = false;
    }

    if (_isRestoreInProgress) {
      _updateProgress(_currentProgress.percentage, null, 'Restore cancelled',
          RestoreStatus.cancelled);
      _isRestoreInProgress = false;
    }
  }

  /// Get available storage in Google Drive
  Future<int?> getAvailableStorage() async {
    try {
      if (!await _driveService.initialize()) {
        return null;
      }
      return await _driveService.getAvailableStorage();
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error getting storage info: $e');
      }
      return null;
    }
  }

  /// Sign out from Google Drive
  Future<void> signOut() async {
    await _driveService.signOut();
    // await _keyManager.clearAllKeys(); // Temporarily disabled
    notifyListeners();
  }

  /// Check if user is signed in
  bool get isSignedIn => _driveService.isSignedIn;

  /// Get current user
  dynamic get currentUser => _driveService.currentUser;

  /// Verify backup file integrity
  bool _verifyBackupIntegrity(Map<String, dynamic> encryptedBackup) {
    try {
      // Check required fields
      if (!encryptedBackup.containsKey('encrypted') ||
          !encryptedBackup.containsKey('version') ||
          !encryptedBackup.containsKey('backup_id') ||
          !encryptedBackup.containsKey('data') ||
          !encryptedBackup.containsKey('iv') ||
          !encryptedBackup.containsKey('tag')) {
        if (kDebugMode) {
          print('❌ Missing required backup fields');
        }
        return false;
      }

      // Verify encryption flag
      if (encryptedBackup['encrypted'] != true) {
        if (kDebugMode) {
          print('❌ Backup is not marked as encrypted');
        }
        return false;
      }

      // Verify version compatibility
      final version = encryptedBackup['version'] as String?;
      if (version == null || version.isEmpty) {
        if (kDebugMode) {
          print('❌ Invalid backup version');
        }
        return false;
      }

      if (kDebugMode) {
        print('✅ Backup integrity verified (version: $version)');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error verifying backup integrity: $e');
      }
      return false;
    }
  }

}

class _EncryptedBackupPayload {
  const _EncryptedBackupPayload({
    required this.backupId,
    required this.encryptedBytes,
    required this.originalSize,
    required this.flightLogsCount,
  });

  final String backupId;
  final Uint8List encryptedBytes;
  final int originalSize;
  final int flightLogsCount;
}

/// Progress tracking for backup/restore operations
class OperationProgress {
  final int percentage;
  final BackupStatus? backupStatus;
  final RestoreStatus? restoreStatus;
  final String currentAction;
  final String? errorMessage;

  const OperationProgress({
    required this.percentage,
    this.backupStatus,
    this.restoreStatus,
    required this.currentAction,
    this.errorMessage,
  });

  bool get isCompleted =>
      (backupStatus == BackupStatus.completed && percentage == 100) ||
      (restoreStatus == RestoreStatus.completed && percentage == 100);

  bool get isFailed =>
      backupStatus == BackupStatus.failed ||
      restoreStatus == RestoreStatus.failed;

  bool get isCancelled =>
      backupStatus == BackupStatus.cancelled ||
      restoreStatus == RestoreStatus.cancelled;

  String get statusText {
    if (isCompleted) return 'Completed';
    if (isFailed) return 'Failed';
    if (isCancelled) return 'Cancelled';
    if (backupStatus != null) return backupStatus!.displayName;
    if (restoreStatus != null) return restoreStatus!.displayName;
    return 'In Progress';
  }

  String get statusEmoji {
    if (isCompleted) return '✅';
    if (isFailed) return '❌';
    if (isCancelled) return '⏹️';
    if (backupStatus == BackupStatus.creatingBackup) return '🔧';
    if (backupStatus == BackupStatus.encrypting) return '🔐';
    if (backupStatus == BackupStatus.uploading) return '📤';
    if (restoreStatus == RestoreStatus.downloading) return '📥';
    if (restoreStatus == RestoreStatus.decrypting) return '🔓';
    if (restoreStatus == RestoreStatus.applying) return '🔄';
    return '⏳';
  }
}

/// Restore status enum
enum RestoreStatus {
  idle,
  checkingConnectivity,
  initializingDrive,
  findingBackup,
  downloading,
  retrievingKey,
  decrypting,
  applying,
  completed,
  failed,
  cancelled;

  String get displayName {
    switch (this) {
      case RestoreStatus.idle:
        return 'Ready';
      case RestoreStatus.checkingConnectivity:
        return 'Checking connection...';
      case RestoreStatus.initializingDrive:
        return 'Connecting to Google Drive...';
      case RestoreStatus.findingBackup:
        return 'Finding backup...';
      case RestoreStatus.downloading:
        return 'Downloading';
      case RestoreStatus.retrievingKey:
        return 'Getting encryption key...';
      case RestoreStatus.decrypting:
        return 'Decrypting';
      case RestoreStatus.applying:
        return 'Applying';
      case RestoreStatus.completed:
        return 'Completed';
      case RestoreStatus.failed:
        return 'Failed';
      case RestoreStatus.cancelled:
        return 'Cancelled';
    }
  }
}

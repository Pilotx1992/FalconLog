import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
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
import '../utils/backup_account_identity_guard.dart';
import '../utils/backup_constants.dart';
import '../utils/backup_filename.dart';
import '../utils/backup_operation_history.dart';
import '../utils/backup_operation_lock.dart';
import '../utils/drive_backup_discovery.dart';
import '../utils/backup_payload_codec.dart';
import '../utils/backup_provider_preferences.dart';
import '../utils/backup_safety_export_helper.dart';
import '../utils/backup_safety_import_helper.dart';
import '../utils/pre_restore_snapshot_service.dart';
import '../utils/merge_restore_transaction.dart';
import '../utils/replace_restore_transaction.dart';
import '../utils/restore_dispatch.dart';
import 'google_drive_service.dart';
import 'key_manager.dart';

/// Thrown when a backup is cancelled cooperatively between phases.
class BackupCancelledException implements Exception {}

/// Thrown when a restore is cancelled before the mutating apply phase.
class RestoreCancelledException implements Exception {}

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
  bool _backupOperationActive = false;
  bool _cancelRequested = false;
  bool _restoreMutating = false;
  BackupOperationLockLease? _activeOperationLease;

  @visibleForTesting
  Future<void> Function(File tempFile, Uint8List content)?
      localBackupTempWriterForTesting;

  @visibleForTesting
  Future<void> Function(File tempFile, File finalFile)?
      beforeLocalBackupRenameForTesting;

  OperationProgress get currentProgress => _currentProgress;
  bool get isBackupInProgress => _isBackupInProgress;
  bool get isRestoreInProgress => _isRestoreInProgress;
  bool get isBackupOperationActive => _backupOperationActive;
  bool get isRestoreMutating => _restoreMutating;
  bool get canCancelRestore => _isRestoreInProgress && !_restoreMutating;

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

  /// Test seam for scheduled backup worker tests.
  @visibleForTesting
  static Future<bool> Function({
    bool interactive,
    BackupProvider? providerOverride,
  })? startBackupForTesting;

  /// Start backup using [providerOverride] or the persisted provider selection.
  Future<bool> startBackup({
    bool interactive = true,
    BackupProvider? providerOverride,
  }) async {
    final testingOverride = startBackupForTesting;
    if (testingOverride != null) {
      return testingOverride(
        interactive: interactive,
        providerOverride: providerOverride,
      );
    }

    if (_backupOperationActive || _isBackupInProgress) {
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

    final operationType = interactive
        ? BackupOperationType.manualBackup
        : BackupOperationType.scheduledBackup;
    final ownerToken = const Uuid().v4();
    final startedAt = DateTime.now().toUtc();
    BackupOperationLockAcquisition? lock;
    BackupOperationLockLease? lease;
    var historyState = BackupOperationResultState.failed;
    var historyMessage = 'Backup failed';
    Object? historyError;

    try {
      lock = await BackupOperationLock.acquire(
        operationType: operationType,
        ownerToken: ownerToken,
      );
    } catch (e) {
      historyError = e;
      _updateProgress(0, BackupStatus.failed, 'Could not start backup.');
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: 'Could not start backup.',
        error: historyError,
      );
      return false;
    }

    if (!lock.acquired) {
      historyMessage = lock.message ?? 'Another backup operation is active.';
      _updateProgress(0, BackupStatus.failed, historyMessage);
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: historyMessage,
      );
      return false;
    }

    lease = BackupOperationLockLease(
      ownerToken: ownerToken,
      operationType: operationType,
    );
    _activeOperationLease = lease;
    lease.start();

    _cancelRequested = false;
    _isBackupInProgress = true;
    _backupOperationActive = true;

    try {
      final provider = providerOverride ??
          await BackupProviderPreferences.getSelectedProvider();
      if (kDebugMode) {
        print('🐛 DEBUG: Backup started with provider: ${provider.name}');
      }

      switch (provider) {
        case BackupProvider.googleDrive:
          final success =
              await _startGoogleDriveBackup(interactive: interactive);
          _checkOperationLease();
          historyState = success
              ? BackupOperationResultState.verified
              : BackupOperationResultState.failed;
          historyMessage = success
              ? 'Backup completed successfully.'
              : _currentProgress.currentAction;
          return success;
        case BackupProvider.local:
          final success = await _startLocalBackup(interactive: interactive);
          _checkOperationLease();
          historyState = success
              ? BackupOperationResultState.verified
              : BackupOperationResultState.failed;
          historyMessage = success
              ? 'Backup completed successfully.'
              : _currentProgress.currentAction;
          return success;
        case BackupProvider.firebase:
          historyMessage =
              'Cloud (Firebase) backup is not supported. Choose Google Drive or Local.';
          _updateProgress(
            0,
            BackupStatus.failed,
            historyMessage,
          );
          return false;
      }
    } on BackupCancelledException {
      historyState = BackupOperationResultState.cancelled;
      historyMessage = 'Backup cancelled';
      if (!_currentProgress.isCancelled) {
        _updateProgress(
          _currentProgress.percentage,
          BackupStatus.cancelled,
          'Backup cancelled',
        );
      }
      return false;
    } on BackupOperationLeaseLostException catch (e) {
      historyState = BackupOperationResultState.failed;
      historyMessage = 'Backup lock was lost before completion.';
      historyError = e;
      _updateProgress(0, BackupStatus.failed, historyMessage);
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Backup failed: $e');
        print('💥 Stack trace: ${StackTrace.current}');
      }
      historyState = BackupOperationResultState.failed;
      historyMessage = 'Backup failed';
      historyError = e;
      if (!_cancelRequested) {
        _updateProgress(
            0, BackupStatus.failed, 'Backup failed: ${e.toString()}');
      }
      return false;
    } finally {
      await lease.stop();
      if (_activeOperationLease == lease) {
        _activeOperationLease = null;
      }
      await BackupOperationLock.release(ownerToken: ownerToken);
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: historyMessage,
        error: historyError,
      );
      _backupOperationActive = false;
      _isBackupInProgress = false;
      _cancelRequested = false;
    }
  }

  void _checkBackupCancelled() {
    _checkOperationLease();
    if (_cancelRequested) {
      if (kDebugMode) {
        debugPrint('BACKUP_CANCEL_CHECK_THROW');
      }
      throw BackupCancelledException();
    }
  }

  void _checkRestoreCancelled() {
    _checkOperationLease();
    if (_cancelRequested && !_restoreMutating) {
      if (kDebugMode) {
        debugPrint('RESTORE_CANCEL_CHECK_THROW');
      }
      throw RestoreCancelledException();
    }
  }

  void _checkOperationLease() {
    _activeOperationLease?.throwIfLost();
  }

  Future<void> _deleteUploadedDriveFileAfterFailedBackup(
    String driveFileId, {
    Future<bool> Function(String fileId)? deleteUploadedDriveFile,
  }) async {
    try {
      final deleteFile = deleteUploadedDriveFile ?? _driveService.deleteFile;
      final deleted = await deleteFile(driveFileId);
      if (kDebugMode) {
        debugPrint(
          'BACKUP_UPLOADED_FILE_DELETED_AFTER_FAILED_BACKUP id=$driveFileId deleted=$deleted',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'BACKUP_UPLOADED_FILE_DELETE_FAILED_AFTER_BACKUP_FAILURE: $e',
        );
      }
    }
  }

  Future<void> _deleteLocalBackupFileAfterCancel(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          debugPrint(
            'BACKUP_LOCAL_FILE_DELETED_AFTER_CANCEL path=$localPath',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BACKUP_LOCAL_FILE_DELETE_FAILED_AFTER_CANCEL: $e');
      }
    }
  }

  Future<bool> _deleteBackupMetadataAfterCancel(String backupId) async {
    try {
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      if (!box.containsKey(backupId)) {
        return false;
      }
      await box.delete(backupId);
      if (kDebugMode) {
        debugPrint('BACKUP_METADATA_DELETED_AFTER_CANCEL id=$backupId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BACKUP_METADATA_DELETE_FAILED_AFTER_CANCEL: $e');
      }
      return false;
    }
  }

  Future<void> _deleteLocalBackupFileAfterFailedBackup(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          debugPrint(
            'BACKUP_LOCAL_FILE_DELETED_AFTER_FAILED_BACKUP path=$localPath',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BACKUP_LOCAL_FILE_DELETE_FAILED_AFTER_BACKUP_FAILURE: $e');
      }
    }
  }

  Future<bool> _deleteBackupMetadataAfterFailedBackup(String backupId) async {
    try {
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      if (!box.containsKey(backupId)) {
        return false;
      }
      await box.delete(backupId);
      if (kDebugMode) {
        debugPrint('BACKUP_METADATA_DELETED_AFTER_FAILED_BACKUP id=$backupId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BACKUP_METADATA_DELETE_FAILED_AFTER_BACKUP_FAILURE: $e');
      }
      return false;
    }
  }

  /// Rolls back artifacts from the current backup when a post-publish step fails.
  Future<void> _rollbackFailedBackupArtifacts({
    String? metadataBackupId,
    String? uploadedDriveFileId,
    String? writtenLocalPath,
    Future<bool> Function(String fileId)? deleteUploadedDriveFile,
  }) async {
    if (uploadedDriveFileId != null) {
      await _deleteUploadedDriveFileAfterFailedBackup(
        uploadedDriveFileId,
        deleteUploadedDriveFile: deleteUploadedDriveFile,
      );
    }
    if (writtenLocalPath != null) {
      await _deleteLocalBackupFileAfterFailedBackup(writtenLocalPath);
    }
    if (metadataBackupId != null) {
      await _deleteBackupMetadataAfterFailedBackup(metadataBackupId);
    }
  }

  /// Reverts partial backup artifacts when a cooperative cancel aborts the flow.
  Future<void> _rollbackCancelledBackupArtifacts({
    String? metadataBackupId,
    String? uploadedDriveFileId,
    String? writtenLocalPath,
    Future<bool> Function(String fileId)? deleteUploadedDriveFile,
  }) async {
    if (uploadedDriveFileId != null) {
      await _deleteUploadedDriveFileAfterFailedBackup(
        uploadedDriveFileId,
        deleteUploadedDriveFile: deleteUploadedDriveFile,
      );
    }
    if (writtenLocalPath != null) {
      await _deleteLocalBackupFileAfterCancel(writtenLocalPath);
    }
    if (metadataBackupId != null) {
      await _deleteBackupMetadataAfterCancel(metadataBackupId);
    }
  }

  Future<bool> _startGoogleDriveBackup({required bool interactive}) async {
    String? uploadedDriveFileId;
    String? savedMetadataBackupId;

    try {
      _checkBackupCancelled();
      _updateProgress(
          0, BackupStatus.checkingConnectivity, 'Checking connectivity...');

      final isConnected = await _checkConnectivity(interactive: interactive);
      if (!isConnected) {
        _updateProgress(0, BackupStatus.failed, 'No internet connection');
        return false;
      }

      _checkBackupCancelled();
      _updateProgress(
          10, BackupStatus.initializingDrive, 'Connecting to Google Drive...');
      final driveInitialized =
          await _driveService.initialize(interactive: interactive);
      if (!driveInitialized) {
        _updateProgress(
            0, BackupStatus.failed, 'Failed to connect to Google Drive');
        return false;
      }

      final identityCheck = BackupAccountIdentityGuard.checkCloudBackup(
        await _cloudIdentitySnapshot(),
      );
      if (!identityCheck.allowed) {
        _updateProgress(
          0,
          BackupStatus.failed,
          identityCheck.message ??
              BackupAccountIdentityGuard.accountMismatchMessage,
        );
        return false;
      }

      final payload = await _prepareEncryptedBackup(
        interactive: interactive,
        useDeviceKey: false,
      );
      if (payload == null) {
        return false;
      }

      _checkBackupCancelled();
      _updateProgress(
          70, BackupStatus.uploading, 'Uploading to Google Drive...');
      final fileName = BackupFilename.generate();
      uploadedDriveFileId = await _driveService.uploadFile(
        fileName: fileName,
        content: payload.encryptedBytes,
        mimeType: 'application/json',
        appProperties: DriveBackupDiscovery.pendingBackupAppProperties(
          backupId: payload.backupId,
        ),
      );

      if (uploadedDriveFileId == null) {
        _updateProgress(0, BackupStatus.failed, 'Failed to upload backup');
        return false;
      }

      late final _BackupPublishResult publishResult;
      try {
        publishResult = await _completeGoogleDriveBackupAfterUpload(
          uploadedDriveFileId: uploadedDriveFileId,
          getFileInfo: _driveService.getFileInfo,
          saveMetadata: () => _saveBackupMetadata(
            backupId: payload.backupId,
            driveFileId: uploadedDriveFileId,
            fileName: fileName,
            originalSize: payload.originalSize,
            encryptedSize: payload.encryptedBytes.length,
            flightLogsCount: payload.flightLogsCount,
            checksum: payload.checksum,
            location: BackupLocation.cloud,
          ),
          recordSuccessfulBackup: _recordSuccessfulBackup,
          deleteUploadedDriveFile: _driveService.deleteFile,
        );
      } on BackupCancelledException {
        uploadedDriveFileId = null;
        savedMetadataBackupId = null;
        rethrow;
      }
      savedMetadataBackupId = publishResult.metadataBackupId;
      if (!publishResult.success) {
        return false;
      }

      _checkBackupCancelled();
      await _markDriveBackupVerified(
        driveFileId: uploadedDriveFileId,
        backupId: payload.backupId,
        checksum: payload.checksum,
      );

      _checkBackupCancelled();
      await _pruneOldBackups(
        keep: BackupFilename.keepLatestSuccessfulCount,
        retainDriveFileId: uploadedDriveFileId,
      );

      _checkBackupCancelled();
      _updateProgress(
          100, BackupStatus.completed, 'Backup completed successfully!');
      return true;
    } on BackupCancelledException {
      await _rollbackCancelledBackupArtifacts(
        metadataBackupId: savedMetadataBackupId,
        uploadedDriveFileId: uploadedDriveFileId,
      );
      rethrow;
    }
  }

  Future<bool> _startLocalBackup({required bool interactive}) async {
    String? writtenLocalPath;
    String? savedMetadataBackupId;

    try {
      _checkBackupCancelled();
      _updateProgress(
          10, BackupStatus.creatingBackup, 'Preparing local backup...');

      final payload = await _prepareEncryptedBackup(
        interactive: interactive,
        useDeviceKey: true,
      );
      if (payload == null) {
        return false;
      }

      _checkBackupCancelled();
      _updateProgress(70, BackupStatus.uploading, 'Saving backup on device...');
      final fileName = BackupFilename.generate();
      writtenLocalPath = await _writeLocalBackupFile(
        fileName: fileName,
        content: payload.encryptedBytes,
      );
      if (writtenLocalPath == null) {
        _updateProgress(0, BackupStatus.failed, 'Failed to save local backup');
        return false;
      }

      late final _BackupPublishResult publishResult;
      try {
        publishResult = await _completeLocalBackupAfterWrite(
          writtenLocalPath: writtenLocalPath,
          saveMetadata: () => _saveBackupMetadata(
            backupId: payload.backupId,
            driveFileId: null,
            localPath: writtenLocalPath,
            fileName: fileName,
            originalSize: payload.originalSize,
            encryptedSize: payload.encryptedBytes.length,
            flightLogsCount: payload.flightLogsCount,
            checksum: payload.checksum,
            location: BackupLocation.local,
          ),
          recordSuccessfulBackup: _recordSuccessfulBackup,
        );
      } on BackupCancelledException {
        writtenLocalPath = null;
        savedMetadataBackupId = null;
        rethrow;
      }
      savedMetadataBackupId = publishResult.metadataBackupId;
      if (!publishResult.success) {
        return false;
      }

      _checkBackupCancelled();
      await _pruneLocalBackups(
        keep: BackupFilename.keepLatestSuccessfulCount,
        retainBackupId: savedMetadataBackupId,
      );

      _checkBackupCancelled();
      _updateProgress(
          100, BackupStatus.completed, 'Local backup completed successfully!');
      return true;
    } on BackupCancelledException {
      await _rollbackCancelledBackupArtifacts(
        metadataBackupId: savedMetadataBackupId,
        writtenLocalPath: writtenLocalPath,
      );
      rethrow;
    }
  }

  Future<_EncryptedBackupPayload?> _prepareEncryptedBackup({
    required bool interactive,
    required bool useDeviceKey,
  }) async {
    _checkBackupCancelled();
    _updateProgress(20, BackupStatus.gettingKey, 'Preparing encryption...');

    final backupId = const Uuid().v4();

    _checkBackupCancelled();
    _updateProgress(30, BackupStatus.creatingBackup, 'Preparing your data...');
    final databaseBytes = await _createDatabaseBackup(backupId: backupId);
    if (databaseBytes == null) {
      if (_cancelRequested) {
        throw BackupCancelledException();
      }
      _updateProgress(
          0, BackupStatus.failed, 'Failed to create database backup');
      return null;
    }

    _checkBackupCancelled();
    _updateProgress(45, BackupStatus.encrypting, 'Getting encryption key...');
    final masterKey = useDeviceKey
        ? await _keyManager.getOrCreateDeviceMasterKey()
        : await _keyManager.getOrCreatePersistentMasterKey(
            interactive: interactive,
          );
    if (masterKey == null) {
      if (_cancelRequested) {
        throw BackupCancelledException();
      }
      _updateProgress(0, BackupStatus.failed, 'Failed to get encryption key');
      return null;
    }

    _checkBackupCancelled();
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
    final checksum = sha256.convert(encryptedBytes).toString();

    return _EncryptedBackupPayload(
      backupId: backupId,
      encryptedBytes: encryptedBytes,
      checksum: checksum,
      originalSize: databaseBytes.length,
      flightLogsCount: await _countFlightLogs(),
    );
  }

  Future<String?> _writeLocalBackupFile({
    required String fileName,
    required Uint8List content,
  }) async {
    File? tempFile;
    File? finalFile;
    var finalFileCreatedByThisOperation = false;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(
        p.join(appDir.path, BackupConstants.localBackupsFolder),
      );
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      finalFile = File(p.join(backupDir.path, fileName));
      if (await finalFile.exists()) {
        if (kDebugMode) {
          debugPrint(
            'LOCAL_BACKUP_PUBLISH_BLOCKED_TARGET_EXISTS path=${finalFile.path}',
          );
        }
        return null;
      }

      tempFile = File(
        p.join(
          backupDir.path,
          '.$fileName.${const Uuid().v4()}.tmp',
        ),
      );

      final tempWriter = localBackupTempWriterForTesting;
      if (tempWriter != null) {
        await tempWriter(tempFile, content);
      } else {
        await tempFile.writeAsBytes(content, flush: true);
      }

      if (!await tempFile.exists()) {
        throw StateError('Temporary local backup file was not created.');
      }
      final tempSize = await tempFile.length();
      if (tempSize <= 0 || tempSize != content.length) {
        throw StateError(
          'Temporary local backup size mismatch: $tempSize != ${content.length}.',
        );
      }

      await beforeLocalBackupRenameForTesting?.call(tempFile, finalFile);

      if (await finalFile.exists()) {
        throw StateError('Final local backup path already exists.');
      }

      final publishedFile = await tempFile.rename(finalFile.path);
      finalFileCreatedByThisOperation = true;

      if (!await publishedFile.exists()) {
        throw StateError('Final local backup file was not created.');
      }
      final publishedSize = await publishedFile.length();
      if (publishedSize != content.length) {
        throw StateError(
          'Final local backup size mismatch: $publishedSize != ${content.length}.',
        );
      }

      return publishedFile.path;
    } catch (e) {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
        if (finalFileCreatedByThisOperation &&
            finalFile != null &&
            await finalFile.exists()) {
          await finalFile.delete();
        }
      } catch (cleanupError) {
        if (kDebugMode) {
          debugPrint('LOCAL_BACKUP_TEMP_CLEANUP_FAILED: $cleanupError');
        }
      }
      if (kDebugMode) {
        print('💥 Error writing local backup: $e');
      }
      return null;
    }
  }

  Future<_BackupPublishResult> _completeGoogleDriveBackupAfterUpload({
    required String uploadedDriveFileId,
    required Future<drive.File?> Function(String fileId) getFileInfo,
    required Future<String?> Function() saveMetadata,
    required Future<void> Function() recordSuccessfulBackup,
    Future<bool> Function(String fileId)? deleteUploadedDriveFile,
  }) async {
    String? savedMetadataBackupId;
    try {
      _checkBackupCancelled();
      if (await getFileInfo(uploadedDriveFileId) == null) {
        _updateProgress(
            0, BackupStatus.failed, 'Failed to verify cloud backup');
        await _rollbackFailedBackupArtifacts(
          uploadedDriveFileId: uploadedDriveFileId,
          deleteUploadedDriveFile: deleteUploadedDriveFile,
        );
        return const _BackupPublishResult.failure();
      }

      _checkBackupCancelled();
      _updateProgress(90, BackupStatus.uploading, 'Finalizing backup...');
      savedMetadataBackupId = await saveMetadata();
      if (savedMetadataBackupId == null) {
        _updateProgress(
            0, BackupStatus.failed, 'Failed to save backup metadata');
        await _rollbackFailedBackupArtifacts(
          uploadedDriveFileId: uploadedDriveFileId,
          deleteUploadedDriveFile: deleteUploadedDriveFile,
        );
        return const _BackupPublishResult.failure();
      }

      try {
        await recordSuccessfulBackup();
      } on BackupCancelledException {
        rethrow;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('BACKUP_SUCCESS_RECORD_FAILED: $e');
        }
        _updateProgress(
            0, BackupStatus.failed, 'Failed to record backup success');
        await _rollbackFailedBackupArtifacts(
          metadataBackupId: savedMetadataBackupId,
          uploadedDriveFileId: uploadedDriveFileId,
          deleteUploadedDriveFile: deleteUploadedDriveFile,
        );
        return _BackupPublishResult.failure(
          metadataBackupId: savedMetadataBackupId,
        );
      }

      return _BackupPublishResult.success(
        metadataBackupId: savedMetadataBackupId,
      );
    } on BackupCancelledException {
      await _rollbackCancelledBackupArtifacts(
        metadataBackupId: savedMetadataBackupId,
        uploadedDriveFileId: uploadedDriveFileId,
        deleteUploadedDriveFile: deleteUploadedDriveFile,
      );
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DRIVE_BACKUP_POST_UPLOAD_FINALIZE_FAILED: $e');
      }
      _updateProgress(0, BackupStatus.failed, 'Failed to finalize backup');
      await _rollbackFailedBackupArtifacts(
        metadataBackupId: savedMetadataBackupId,
        uploadedDriveFileId: uploadedDriveFileId,
        deleteUploadedDriveFile: deleteUploadedDriveFile,
      );
      return _BackupPublishResult.failure(
        metadataBackupId: savedMetadataBackupId,
      );
    }
  }

  Future<_BackupPublishResult> _completeLocalBackupAfterWrite({
    required String writtenLocalPath,
    required Future<String?> Function() saveMetadata,
    required Future<void> Function() recordSuccessfulBackup,
  }) async {
    String? savedMetadataBackupId;
    try {
      _checkBackupCancelled();
      final file = File(writtenLocalPath);
      if (!await file.exists()) {
        _updateProgress(
            0, BackupStatus.failed, 'Failed to verify local backup');
        await _rollbackFailedBackupArtifacts(
            writtenLocalPath: writtenLocalPath);
        return const _BackupPublishResult.failure();
      }

      _checkBackupCancelled();
      _updateProgress(90, BackupStatus.uploading, 'Finalizing backup...');
      savedMetadataBackupId = await saveMetadata();
      if (savedMetadataBackupId == null) {
        _updateProgress(
            0, BackupStatus.failed, 'Failed to save backup metadata');
        await _rollbackFailedBackupArtifacts(
            writtenLocalPath: writtenLocalPath);
        return const _BackupPublishResult.failure();
      }

      try {
        await recordSuccessfulBackup();
      } on BackupCancelledException {
        rethrow;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LOCAL_BACKUP_SUCCESS_RECORD_FAILED: $e');
        }
        _updateProgress(
            0, BackupStatus.failed, 'Failed to record backup success');
        await _rollbackFailedBackupArtifacts(
          metadataBackupId: savedMetadataBackupId,
          writtenLocalPath: writtenLocalPath,
        );
        return _BackupPublishResult.failure(
          metadataBackupId: savedMetadataBackupId,
        );
      }

      return _BackupPublishResult.success(
        metadataBackupId: savedMetadataBackupId,
      );
    } on BackupCancelledException {
      await _rollbackCancelledBackupArtifacts(
        metadataBackupId: savedMetadataBackupId,
        writtenLocalPath: writtenLocalPath,
      );
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LOCAL_BACKUP_FINALIZE_FAILED: $e');
      }
      _updateProgress(0, BackupStatus.failed, 'Failed to finalize backup');
      await _rollbackFailedBackupArtifacts(
        metadataBackupId: savedMetadataBackupId,
        writtenLocalPath: writtenLocalPath,
      );
      return _BackupPublishResult.failure(
        metadataBackupId: savedMetadataBackupId,
      );
    }
  }

  Future<void> _pruneLocalBackups({
    int keep = BackupFilename.keepLatestSuccessfulCount,
    String? retainBackupId,
  }) async {
    try {
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      final localEntries = box.values
          .where(
            (entry) =>
                entry.location == BackupLocation.local &&
                entry.health == BackupHealth.verified,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final retained = <String>{};
      if (retainBackupId != null && retainBackupId.isNotEmpty) {
        retained.add(retainBackupId);
      }
      for (final entry in localEntries.take(keep)) {
        retained.add(entry.id);
      }

      for (final entry in localEntries) {
        if (retained.contains(entry.id)) continue;
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

    final operationType = BackupOperationType.restore;
    final ownerToken = const Uuid().v4();
    final startedAt = DateTime.now().toUtc();
    BackupOperationLockAcquisition? lock;
    BackupOperationLockLease? lease;
    var historyState = BackupOperationResultState.failed;
    var historyMessage = 'Restore failed';
    Object? historyError;

    try {
      lock = await BackupOperationLock.acquire(
        operationType: operationType,
        ownerToken: ownerToken,
      );
    } catch (e) {
      historyError = e;
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: 'Could not start restore.',
        error: historyError,
      );
      return RestoreResult.failure(error: 'Could not start restore.');
    }

    if (!lock.acquired) {
      historyMessage = lock.message ?? 'Another operation is active.';
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: historyMessage,
      );
      return RestoreResult.failure(error: historyMessage);
    }

    lease = BackupOperationLockLease(
      ownerToken: ownerToken,
      operationType: operationType,
    );
    _activeOperationLease = lease;
    lease.start();

    _isRestoreInProgress = true;
    _restoreMutating = false;
    _cancelRequested = false;

    try {
      final resolved = target ?? await resolveDefaultRestoreTarget();
      if (resolved == null) {
        historyMessage =
            'No backup found to restore for the selected location.';
        return RestoreResult.failure(
          error: historyMessage,
        );
      }

      final unsupported = RestoreDispatch.unsupportedMessage(resolved.provider);
      if (unsupported != null) {
        historyMessage = unsupported;
        _updateProgress(0, null, unsupported, RestoreStatus.failed);
        return RestoreResult.failure(error: unsupported);
      }

      switch (RestoreDispatch.routeForProvider(resolved.provider)) {
        case RestoreRoute.googleDrive:
          final result = await _restoreFromGoogleDrive(
            resolved,
            mode: mode,
            interactive: interactive,
          );
          _checkOperationLease();
          historyState = result.success
              ? BackupOperationResultState.verified
              : BackupOperationResultState.failed;
          historyMessage = result.success
              ? 'Restore completed successfully.'
              : result.error ?? _currentProgress.currentAction;
          return result;
        case RestoreRoute.local:
          final result = await _restoreFromLocal(resolved, mode: mode);
          _checkOperationLease();
          historyState = result.success
              ? BackupOperationResultState.verified
              : BackupOperationResultState.failed;
          historyMessage = result.success
              ? 'Restore completed successfully.'
              : result.error ?? _currentProgress.currentAction;
          return result;
        case RestoreRoute.unsupported:
          historyMessage = RestoreDispatch.unsupportedMessage(
                BackupProvider.firebase,
              ) ??
              'Unsupported backup provider.';
          return RestoreResult.failure(
            error: historyMessage,
          );
      }
    } on RestoreCancelledException {
      historyState = BackupOperationResultState.cancelled;
      historyMessage = 'Restore cancelled';
      _updateProgress(
        _currentProgress.percentage,
        null,
        'Restore cancelled',
        RestoreStatus.cancelled,
      );
      return RestoreResult.failure(error: 'Restore cancelled');
    } on BackupOperationLeaseLostException catch (e) {
      historyState = BackupOperationResultState.failed;
      historyMessage = 'Restore lock was lost before completion.';
      historyError = e;
      _updateProgress(0, null, historyMessage, RestoreStatus.failed);
      return RestoreResult.failure(error: historyMessage);
    } catch (e) {
      if (kDebugMode) {
        print('💥 Restore failed: $e');
      }
      historyState = BackupOperationResultState.failed;
      historyMessage = 'Restore failed';
      historyError = e;
      _updateProgress(0, null, 'Restore failed', RestoreStatus.failed);
      return RestoreResult.failure(error: 'Restore failed: ${e.toString()}');
    } finally {
      await lease.stop();
      if (_activeOperationLease == lease) {
        _activeOperationLease = null;
      }
      await BackupOperationLock.release(ownerToken: ownerToken);
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: historyMessage,
        error: historyError,
      );
      _isRestoreInProgress = false;
      _restoreMutating = false;
      _cancelRequested = false;
    }
  }

  /// Restore from a user-picked safety copy (`.crypt14` outside app storage).
  ///
  /// Tries the device key first, then the Google account key used for cloud backups.
  Future<RestoreResult> startRestoreFromSafetyCopy({
    required BackupSafetyImportCandidate candidate,
    RestoreMode mode = RestoreMode.merge,
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

    final operationType = BackupOperationType.restore;
    final ownerToken = const Uuid().v4();
    final startedAt = DateTime.now().toUtc();
    BackupOperationLockAcquisition? lock;
    BackupOperationLockLease? lease;
    var historyState = BackupOperationResultState.failed;
    var historyMessage = 'Restore failed';
    Object? historyError;

    try {
      lock = await BackupOperationLock.acquire(
        operationType: operationType,
        ownerToken: ownerToken,
      );
    } catch (e) {
      historyError = e;
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: 'Could not start restore.',
        error: historyError,
      );
      return RestoreResult.failure(error: 'Could not start restore.');
    }

    if (!lock.acquired) {
      historyMessage = lock.message ?? 'Another operation is active.';
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: historyMessage,
      );
      return RestoreResult.failure(error: historyMessage);
    }

    lease = BackupOperationLockLease(
      ownerToken: ownerToken,
      operationType: operationType,
    );
    _activeOperationLease = lease;
    lease.start();

    _isRestoreInProgress = true;
    _restoreMutating = false;
    _cancelRequested = false;

    try {
      final validation = BackupSafetyImportHelper.validate(
        fileName: candidate.fileName,
        encryptedBytes: candidate.encryptedBytes,
      );
      if (!validation.isSuccess || validation.candidate == null) {
        historyMessage =
            validation.errorMessage ?? 'Invalid safety backup file.';
        return RestoreResult.failure(
          error: historyMessage,
        );
      }

      final bytes = validation.candidate!.encryptedBytes;
      final fileName = validation.candidate!.fileName;
      final backupDate =
          BackupFilename.parseTimestampFromFileName(fileName) ?? DateTime.now();
      final backupTargetId = 'safety-import:$fileName';

      _checkRestoreCancelled();
      final decryptResult = await _decryptSafetyCopyPayload(
        encryptedFileBytes: bytes,
        interactive: interactive,
      );

      if (!decryptResult.success || decryptResult.databaseBytes == null) {
        historyMessage = decryptResult.error ??
            'Failed to decrypt backup. Use the same device or Google account that created it.';
        _updateProgress(0, null, 'Decrypt failed', RestoreStatus.failed);
        return RestoreResult.failure(
          error: historyMessage,
        );
      }

      final databaseBytes = decryptResult.databaseBytes!;

      final payloadError =
          BackupPayloadCodec.validatePayloadBytes(databaseBytes);
      if (payloadError != null) {
        historyMessage = payloadError;
        _updateProgress(
          0,
          null,
          'Invalid backup payload',
          RestoreStatus.failed,
        );
        return RestoreResult.failure(error: payloadError);
      }

      _checkRestoreCancelled();
      _updateProgress(
        85,
        null,
        'Restoring your data... Do not close the app.',
        RestoreStatus.applying,
      );
      _restoreMutating = true;
      final restoreResult = await _restoreDatabase(
        databaseBytes,
        mode: mode,
        backupTargetId: backupTargetId,
      );

      if (!restoreResult.success) {
        historyMessage =
            restoreResult.error ?? 'Failed to restore data from safety copy.';
        _updateProgress(
            0, null, 'Failed to restore data', RestoreStatus.failed);
        return restoreResult;
      }

      _checkOperationLease();
      _updateProgress(100, null, 'Restore completed!', RestoreStatus.completed);

      historyState = BackupOperationResultState.verified;
      historyMessage = 'Restore completed successfully.';
      return RestoreResult.success(
        flightLogsRestored: restoreResult.flightLogsRestored,
        backupDate: backupDate,
        sourceDevice: 'Safety copy (file)',
      );
    } on RestoreCancelledException {
      historyState = BackupOperationResultState.cancelled;
      historyMessage = 'Restore cancelled';
      _updateProgress(
        _currentProgress.percentage,
        null,
        'Restore cancelled',
        RestoreStatus.cancelled,
      );
      return RestoreResult.failure(error: 'Restore cancelled');
    } on BackupOperationLeaseLostException catch (e) {
      historyState = BackupOperationResultState.failed;
      historyMessage = 'Restore lock was lost before completion.';
      historyError = e;
      _updateProgress(0, null, historyMessage, RestoreStatus.failed);
      return RestoreResult.failure(error: historyMessage);
    } catch (e) {
      historyState = BackupOperationResultState.failed;
      historyMessage = 'Restore failed';
      historyError = e;
      if (kDebugMode) {
        print('💥 Safety copy restore failed: $e');
      }
      _updateProgress(0, null, 'Restore failed', RestoreStatus.failed);
      return RestoreResult.failure(error: 'Restore failed: ${e.toString()}');
    } finally {
      await lease.stop();
      if (_activeOperationLease == lease) {
        _activeOperationLease = null;
      }
      await BackupOperationLock.release(ownerToken: ownerToken);
      await _recordOperationHistorySafe(
        operationType: operationType,
        state: historyState,
        startedAt: startedAt,
        message: historyMessage,
        error: historyError,
      );
      _isRestoreInProgress = false;
      _restoreMutating = false;
      _cancelRequested = false;
    }
  }

  /// Latest backup for [provider] or the active provider as a [BackupInfo].
  Future<BackupInfo?> resolveDefaultRestoreTarget({
    BackupProvider? provider,
  }) async {
    final metadata = await findExistingBackup(provider: provider);
    return metadata == null ? null : BackupInfo.fromMetadata(metadata);
  }

  /// Read-only: newest local or cloud-restorable backup suitable for safety export.
  ///
  /// Does not write metadata, change preferences, or download cloud backups to
  /// app storage — cloud bytes are returned in-memory only when needed.
  Future<BackupSafetyExportCandidate?>
      resolveLatestExportableBackupForSafetyCopy({
    bool interactive = false,
  }) async {
    final local = await _findLatestLocalBackupMetadata();
    final cloud = await _findLatestGoogleDriveBackupMetadata(
      interactive: interactive,
    );

    final BackupMetadata? metadata;
    if (local != null && cloud != null) {
      metadata = local.createdAt.isAfter(cloud.createdAt) ? local : cloud;
    } else {
      metadata = local ?? cloud;
    }

    if (metadata == null) {
      return null;
    }

    return _resolveSafetyExportCandidate(
      metadata,
      interactive: interactive,
    );
  }

  Future<BackupSafetyExportCandidate?> _resolveSafetyExportCandidate(
    BackupMetadata metadata, {
    required bool interactive,
  }) async {
    if (!BackupFilename.isRecognizedBackupFileName(metadata.fileName)) {
      return null;
    }

    final localPath = await _resolveExistingLocalBackupPath(metadata);
    if (localPath != null) {
      return BackupSafetyExportCandidate(
        fileName: metadata.fileName,
        localSourcePath: localPath,
      );
    }

    final driveFileId = metadata.driveFileId;
    if (driveFileId == null || driveFileId.isEmpty) {
      return null;
    }

    if (!await _driveService.initialize(interactive: interactive)) {
      return null;
    }

    final encryptedBytes = await _driveService.downloadFile(driveFileId);
    if (encryptedBytes == null ||
        !DriveBackupDiscovery.validateBackupFileBytes(encryptedBytes)) {
      return null;
    }

    return BackupSafetyExportCandidate(
      fileName: metadata.fileName,
      encryptedBytes: Uint8List.fromList(encryptedBytes),
    );
  }

  Future<String?> _resolveExistingLocalBackupPath(
    BackupMetadata metadata,
  ) async {
    final directPath = metadata.localPath;
    if (directPath != null &&
        directPath.isNotEmpty &&
        await File(directPath).exists()) {
      return directPath;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final candidate = File(
      p.join(
        appDir.path,
        BackupConstants.localBackupsFolder,
        metadata.fileName,
      ),
    );
    if (await candidate.exists()) {
      return candidate.path;
    }

    return null;
  }

  Future<RestoreResult> _restoreFromGoogleDrive(
    BackupInfo target, {
    required RestoreMode mode,
    required bool interactive,
  }) async {
    _checkRestoreCancelled();
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

    final identityCheck = BackupAccountIdentityGuard.checkCloudRestore(
      await _cloudIdentitySnapshot(),
    );
    if (!identityCheck.allowed) {
      _updateProgress(
        0,
        null,
        identityCheck.message ??
            BackupAccountIdentityGuard.accountMismatchMessage,
        RestoreStatus.failed,
      );
      return RestoreResult.failure(
        error: identityCheck.message ??
            BackupAccountIdentityGuard.accountMismatchMessage,
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
    _checkRestoreCancelled();
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
        error: 'Local backup file not found at: $localPath',
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

  /// Tries device-local key first, then Google account key (cloud backups).
  Future<({bool success, Uint8List? databaseBytes, String? error})>
      _decryptSafetyCopyPayload({
    required Uint8List encryptedFileBytes,
    required bool interactive,
  }) async {
    _checkRestoreCancelled();
    _updateProgress(
      40,
      null,
      'Decrypting safety copy...',
      RestoreStatus.decrypting,
    );

    final deviceBytes = await _tryDecryptSafetyCopyBytes(
      encryptedFileBytes: encryptedFileBytes,
      useDeviceKey: true,
      interactive: false,
    );
    if (deviceBytes != null) {
      return (success: true, databaseBytes: deviceBytes, error: null);
    }

    _checkRestoreCancelled();
    _updateProgress(
      55,
      null,
      'Getting encryption key...',
      RestoreStatus.retrievingKey,
    );

    if (!await _driveService.initialize(interactive: interactive)) {
      return (
        success: false,
        databaseBytes: null,
        error:
            'Google Drive sign-in is required to decrypt this backup. Sign in with the same Google account used for backup.',
      );
    }

    final cloudBytes = await _tryDecryptSafetyCopyBytes(
      encryptedFileBytes: encryptedFileBytes,
      useDeviceKey: false,
      interactive: interactive,
    );
    if (cloudBytes != null) {
      return (success: true, databaseBytes: cloudBytes, error: null);
    }

    final hasLocalKey = await _keyManager.getLocalMasterKeyIfPresent() != null;
    return (
      success: false,
      databaseBytes: null,
      error: hasLocalKey
          ? 'Failed to decrypt backup. This file may be from another device or Google account.'
          : 'Failed to decrypt backup. Sign in with the Google account used for backup, or use the same device that created a local backup.',
    );
  }

  /// Decrypts a safety copy with one key strategy; returns null when the key does not match.
  Future<Uint8List?> _tryDecryptSafetyCopyBytes({
    required Uint8List encryptedFileBytes,
    required bool useDeviceKey,
    required bool interactive,
  }) async {
    Map<String, dynamic> encryptedBackup;
    try {
      encryptedBackup =
          json.decode(utf8.decode(encryptedFileBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    if (!_validateEncryptedBackupEnvelope(encryptedBackup)) {
      return null;
    }

    final Uint8List? masterKey;
    if (useDeviceKey) {
      masterKey = await _keyManager.getLocalMasterKeyIfPresent();
    } else {
      masterKey = await _keyManager.getOrCreatePersistentMasterKey(
        interactive: interactive,
      );
    }

    if (masterKey == null) {
      return null;
    }

    return _encryptionService.decryptDatabase(
      encryptedBackup: encryptedBackup,
      masterKey: masterKey,
    );
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
    _checkRestoreCancelled();
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

    if (!_validateEncryptedBackupEnvelope(encryptedBackup)) {
      _updateProgress(0, null, 'Backup corrupted', RestoreStatus.failed);
      return RestoreResult.failure(
        error:
            'Backup envelope is invalid or incomplete. Please try another backup from Recent Backups.',
      );
    }

    _checkRestoreCancelled();
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
      _updateProgress(
          0, null, 'Failed to get encryption key', RestoreStatus.failed);
      return RestoreResult.failure(
        error: useDeviceKey
            ? 'Failed to get device encryption key. Restore this backup on the same device.'
            : 'Failed to get encryption key. Sign in to Google and try again.',
      );
    }

    _checkRestoreCancelled();
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

    _checkRestoreCancelled();
    _updateProgress(
      85,
      null,
      'Restoring your data... Do not close the app.',
      RestoreStatus.applying,
    );
    _restoreMutating = true;
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

  /// Keep only the newest [keep] Drive backups (by modifiedTime desc).
  Future<void> _pruneOldBackups({
    int keep = BackupFilename.keepLatestSuccessfulCount,
    String? retainDriveFileId,
  }) async {
    try {
      final files = await _driveService.listFiles(
        query: BackupFilename.driveDiscoveryQuery,
      );
      _sortDriveFilesNewestFirst(files);
      final storedByDriveId = await _loadStoredMetadataByDriveFileId();
      final idsToDelete = selectDriveFileIdsToPrune(
        files,
        keep: keep,
        alwaysRetainDriveFileId: retainDriveFileId,
        storedByDriveId: storedByDriveId,
      );
      for (final id in idsToDelete) {
        await _driveService.deleteFile(id);
        await _deleteBackupMetadataByDriveFileId(id);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Retention prune error: $e');
      }
    }
  }

  /// Drive file ids to delete when keeping [keep] newest entries.
  @visibleForTesting
  static List<String> selectDriveFileIdsToPrune(
    List<drive.File> filesNewestFirst, {
    int keep = BackupFilename.keepLatestSuccessfulCount,
    String? alwaysRetainDriveFileId,
    Map<String, BackupMetadata> storedByDriveId = const {},
  }) {
    if (filesNewestFirst.isEmpty) return const [];

    final protected = <String>{};
    final retainedVerified = <String>{};
    if (alwaysRetainDriveFileId != null && alwaysRetainDriveFileId.isNotEmpty) {
      protected.add(alwaysRetainDriveFileId);
    }

    for (final file in filesNewestFirst) {
      final id = file.id;
      if (id == null || id.isEmpty) continue;
      if (!_isVerifiedDriveRetentionCandidate(
        file,
        storedByDriveId: storedByDriveId,
      )) {
        continue;
      }
      if (protected.contains(id)) {
        retainedVerified.add(id);
      }
    }

    for (final file in filesNewestFirst) {
      if (retainedVerified.length >= keep) break;
      final id = file.id;
      if (id == null || id.isEmpty) continue;
      if (retainedVerified.contains(id)) continue;
      if (!_isVerifiedDriveRetentionCandidate(
        file,
        storedByDriveId: storedByDriveId,
      )) {
        continue;
      }
      retainedVerified.add(id);
    }

    final toDelete = <String>[];
    for (final file in filesNewestFirst) {
      final id = file.id;
      if (id == null || id.isEmpty) continue;
      if (protected.contains(id) || retainedVerified.contains(id)) continue;
      if (!_isVerifiedDriveRetentionCandidate(
        file,
        storedByDriveId: storedByDriveId,
      )) {
        continue;
      }
      toDelete.add(id);
    }
    return toDelete;
  }

  static bool _isVerifiedDriveRetentionCandidate(
    drive.File file, {
    required Map<String, BackupMetadata> storedByDriveId,
  }) {
    if (!DriveBackupDiscovery.isRecognizedDriveFile(file)) {
      return false;
    }

    final id = file.id;
    if (id == null || id.isEmpty) {
      return false;
    }

    final stored = storedByDriveId[id];
    if (stored != null &&
        (stored.location == BackupLocation.cloud ||
            stored.location == BackupLocation.both) &&
        stored.health == BackupHealth.verified) {
      return true;
    }

    return DriveBackupDiscovery.hasVerifiedBackupAppProperties(file);
  }

  Future<void> _deleteBackupMetadataByDriveFileId(String driveFileId) async {
    try {
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      for (final entry in box.values.toList()) {
        if (entry.driveFileId == driveFileId) {
          await box.delete(entry.id);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Drive metadata prune error: $e');
      }
    }
  }

  Future<void> _markDriveBackupVerified({
    required String driveFileId,
    required String backupId,
    required String checksum,
  }) async {
    final marked = await _driveService.updateFileAppProperties(
      fileId: driveFileId,
      appProperties: DriveBackupDiscovery.verifiedBackupAppProperties(
        backupId: backupId,
        checksum: checksum,
      ),
    );
    if (!marked && kDebugMode) {
      debugPrint('DRIVE_BACKUP_VERIFIED_APP_PROPERTIES_SKIPPED $driveFileId');
    }
  }

  /// Latest backup for [provider] or the currently selected provider.
  Future<BackupMetadata?> findExistingBackup({BackupProvider? provider}) async {
    final resolved =
        provider ?? await BackupProviderPreferences.getSelectedProvider();
    switch (resolved) {
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
      BackupMetadata? latest;
      for (final entry in box.values) {
        if (entry.location != BackupLocation.local) continue;
        if (entry.health == BackupHealth.failed ||
            entry.health == BackupHealth.cancelled) {
          continue;
        }

        final path = entry.localPath;
        if (path == null || path.isEmpty) continue;
        if (!await File(path).exists()) continue;

        if (latest == null || entry.createdAt.isAfter(latest.createdAt)) {
          latest = entry;
        }
      }
      return latest;
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
        query: BackupFilename.driveDiscoveryQuery,
      );

      if (backupFiles.isEmpty) {
        return null;
      }

      final storedByDriveId = await _loadStoredMetadataByDriveFileId();
      final identity = await _cloudIdentitySnapshot();

      return _resolveLatestRestorableDriveBackup(
        backupFiles: backupFiles,
        storedByDriveId: storedByDriveId,
        identitySnapshot: identity,
        downloadFile: _driveService.downloadFile,
        getFileInfo: _driveService.getFileInfo,
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
        query: BackupFilename.driveDiscoveryQuery,
      );

      _sortDriveFilesNewestFirst(backupFiles);
      final storedByDriveId = await _loadStoredMetadataByDriveFileId();
      final identity = await _cloudIdentitySnapshot();
      final identityAllowed =
          BackupAccountIdentityGuard.checkCloudRestore(identity).allowed;

      final results = <BackupMetadata>[];
      for (final file in backupFiles) {
        if (!DriveBackupDiscovery.isRecognizedDriveFile(file)) {
          continue;
        }

        final stored = storedByDriveId[file.id!];
        if (stored != null) {
          results.add(
            DriveBackupDiscovery.metadataFromDriveFile(file, stored: stored),
          );
          continue;
        }

        if (!identityAllowed) {
          continue;
        }

        final bytes = await _driveService.downloadFile(file.id!);
        if (bytes == null ||
            !DriveBackupDiscovery.validateBackupFileBytes(bytes)) {
          continue;
        }

        results.add(DriveBackupDiscovery.metadataFromDriveFile(file));
      }

      return results;
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

  MergeRestoreTransaction _createMergeTransaction() {
    final snapshotService = _preRestoreSnapshotService;
    return MergeRestoreTransaction(
      createSnapshot: () async {
        final payload = await _buildBackupPayload(backupId: const Uuid().v4());
        if (payload == null) {
          return (
            path: null,
            error: 'Could not create safety snapshot before merge restore.',
          );
        }
        return snapshotService.savePayload(payload);
      },
      applyBackupPayload: (data) => BackupPayloadCodec.applyPayload(
        backupData: data,
        mode: RestoreMode.merge,
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
    return MergeRestoreTransaction.recoverPendingOnStartup(
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

      final txResult = await _createMergeTransaction().execute(
        backupData: backupData,
        backupTargetId: targetId,
      );

      if (!txResult.success) {
        return RestoreResult.failure(error: txResult.error);
      }

      if (kDebugMode) {
        print(
          '✅ Merge restored ${txResult.flightLogsRestored} flights '
          '(rolledBack=${txResult.rolledBack})',
        );
      }

      return RestoreResult.success(
        flightLogsRestored: txResult.flightLogsRestored,
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

  /// Hive metadata keyed by Google Drive file id (saved at backup time).
  /// Resolves the newest restorable Drive backup (metadata-linked or reinstall recovery).
  Future<BackupMetadata?> _resolveLatestRestorableDriveBackup({
    required List<drive.File> backupFiles,
    required Map<String, BackupMetadata> storedByDriveId,
    required BackupAccountIdentitySnapshot identitySnapshot,
    required Future<Uint8List?> Function(String fileId) downloadFile,
    required Future<drive.File?> Function(String fileId) getFileInfo,
  }) async {
    _sortDriveFilesNewestFirst(backupFiles);

    final identityCheck =
        BackupAccountIdentityGuard.checkCloudRestore(identitySnapshot);
    if (!identityCheck.allowed) {
      if (kDebugMode) {
        print(
          '☁️ Drive backup discovery blocked: ${identityCheck.message}',
        );
      }
      return null;
    }

    // Path A: newest file with local Hive metadata (normal operation).
    for (final file in backupFiles) {
      if (!DriveBackupDiscovery.isRecognizedDriveFile(file)) {
        continue;
      }
      final stored = storedByDriveId[file.id!];
      if (stored == null) {
        continue;
      }

      final detailed = await getFileInfo(file.id!);
      final fileSize = int.tryParse(detailed?.size ?? file.size ?? '0') ?? 0;

      return DriveBackupDiscovery.metadataFromDriveFile(
        file,
        stored: stored,
        sizeBytesOverride: fileSize,
      );
    }

    // Path B: reinstall recovery — Drive file valid, local metadata wiped.
    for (final file in backupFiles) {
      if (!DriveBackupDiscovery.isRecognizedDriveFile(file)) {
        continue;
      }
      if (storedByDriveId.containsKey(file.id!)) {
        continue;
      }

      final bytes = await downloadFile(file.id!);
      if (bytes == null ||
          !DriveBackupDiscovery.validateBackupFileBytes(bytes)) {
        if (kDebugMode) {
          print('☁️ Skipping non-backup Drive file: ${file.name}');
        }
        continue;
      }

      final detailed = await getFileInfo(file.id!);
      final fileSize =
          int.tryParse(detailed?.size ?? file.size ?? '0') ?? bytes.length;

      if (kDebugMode) {
        print(
          '☁️ Recovered restorable Drive backup without local metadata: '
          '${file.name}',
        );
      }

      return DriveBackupDiscovery.metadataFromDriveFile(
        file,
        sizeBytesOverride: fileSize,
      );
    }

    return null;
  }

  @visibleForTesting
  Future<BackupMetadata?> resolveLatestRestorableDriveBackupForTesting({
    required List<drive.File> backupFiles,
    required Map<String, BackupMetadata> storedByDriveId,
    required BackupAccountIdentitySnapshot identitySnapshot,
    required Future<Uint8List?> Function(String fileId) downloadFile,
    Future<drive.File?> Function(String fileId)? getFileInfo,
  }) {
    return _resolveLatestRestorableDriveBackup(
      backupFiles: backupFiles,
      storedByDriveId: storedByDriveId,
      identitySnapshot: identitySnapshot,
      downloadFile: downloadFile,
      getFileInfo:
          getFileInfo ?? (id) async => drive.File(id: id, size: '1024'),
    );
  }

  Future<Map<String, BackupMetadata>> _loadStoredMetadataByDriveFileId() async {
    try {
      final box = await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      final byDriveId = <String, BackupMetadata>{};
      for (final metadata in box.values) {
        final driveId = metadata.driveFileId;
        if (driveId != null && driveId.isNotEmpty) {
          byDriveId[driveId] = metadata;
        }
      }
      return byDriveId;
    } catch (_) {
      return {};
    }
  }

  /// Save backup metadata. Returns [backupId] when persisted, null on failure.
  Future<String?> _saveBackupMetadata({
    required String backupId,
    required String fileName,
    required int originalSize,
    required int encryptedSize,
    required int flightLogsCount,
    required String checksum,
    required BackupLocation location,
    String? driveFileId,
    String? localPath,
  }) async {
    if (_cancelRequested) {
      if (kDebugMode) {
        debugPrint('BACKUP_METADATA_SAVE_BLOCKED_BY_CANCEL');
      }
      throw BackupCancelledException();
    }
    _checkBackupCancelled();
    try {
      final currentUser = _driveService.currentUser;
      final metadata = BackupMetadata(
        id: backupId,
        fileName: fileName,
        location: location,
        createdAt: DateTime.now(),
        sizeBytes: encryptedSize,
        flightLogsCount: flightLogsCount,
        checksum: checksum,
        driveFileId: driveFileId,
        localPath: localPath,
        isEncrypted: true,
        encryptionAlgorithm: 'AES-256-GCM',
        health: BackupHealth.verified,
        lastVerified: DateTime.now(),
        deviceId: currentUser?.email ?? 'This device',
      );

      final metadataBox =
          await HiveInitializationService.openBox<BackupMetadata>(
        'backupMetadata',
      );
      _checkBackupCancelled();
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
      return backupId;
    } on BackupCancelledException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error saving backup metadata: $e');
      }
      return null;
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
    if (_cancelRequested) {
      if (kDebugMode) {
        debugPrint('BACKUP_SUCCESS_RECORD_SKIPPED_BY_CANCEL');
      }
      throw BackupCancelledException();
    }
    _checkBackupCancelled();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      BackupConstants.settingsKeys['last_backup_time']!,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _recordOperationHistorySafe({
    required BackupOperationType operationType,
    required BackupOperationResultState state,
    required DateTime startedAt,
    required String message,
    Object? error,
    String? backupId,
  }) async {
    try {
      await BackupOperationHistory.record(
        operationType: operationType,
        state: state,
        startedAt: startedAt,
        message: message,
        error: error,
        backupId: backupId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BACKUP_OPERATION_HISTORY_WRITE_FAILED: $e');
      }
    }
  }

  /// Update progress and notify listeners
  void _updateProgress(
      int percentage, BackupStatus? backupStatus, String action,
      [RestoreStatus? restoreStatus]) {
    if (_cancelRequested &&
        _isBackupInProgress &&
        backupStatus == BackupStatus.completed) {
      if (kDebugMode) {
        debugPrint('BACKUP_COMPLETED_PROGRESS_SKIPPED_BY_CANCEL');
      }
      return;
    }

    _currentProgress = OperationProgress(
      percentage: percentage,
      backupStatus: backupStatus,
      restoreStatus: restoreStatus,
      currentAction: action,
    );
    notifyListeners();
  }

  @visibleForTesting
  Future<void> rollbackCancelledBackupArtifactsForTesting({
    String? metadataBackupId,
    String? uploadedDriveFileId,
    String? writtenLocalPath,
  }) =>
      _rollbackCancelledBackupArtifacts(
        metadataBackupId: metadataBackupId,
        uploadedDriveFileId: uploadedDriveFileId,
        writtenLocalPath: writtenLocalPath,
      );

  @visibleForTesting
  Future<bool> deleteBackupMetadataForTesting(String backupId) =>
      _deleteBackupMetadataAfterCancel(backupId);

  @visibleForTesting
  Future<void> recordSuccessfulBackupForTesting() => _recordSuccessfulBackup();

  @visibleForTesting
  Future<String?> saveBackupMetadataForTesting({
    required String backupId,
    required String fileName,
    required int originalSize,
    required int encryptedSize,
    required int flightLogsCount,
    required String checksum,
    required BackupLocation location,
    String? driveFileId,
    String? localPath,
  }) {
    return _saveBackupMetadata(
      backupId: backupId,
      fileName: fileName,
      originalSize: originalSize,
      encryptedSize: encryptedSize,
      flightLogsCount: flightLogsCount,
      checksum: checksum,
      location: location,
      driveFileId: driveFileId,
      localPath: localPath,
    );
  }

  @visibleForTesting
  Future<bool> completeGoogleDriveBackupAfterUploadForTesting({
    required String uploadedDriveFileId,
    required Future<drive.File?> Function(String fileId) getFileInfo,
    required Future<String?> Function() saveMetadata,
    required Future<void> Function() recordSuccessfulBackup,
    Future<bool> Function(String fileId)? deleteUploadedDriveFile,
  }) async {
    final result = await _completeGoogleDriveBackupAfterUpload(
      uploadedDriveFileId: uploadedDriveFileId,
      getFileInfo: getFileInfo,
      saveMetadata: saveMetadata,
      recordSuccessfulBackup: recordSuccessfulBackup,
      deleteUploadedDriveFile: deleteUploadedDriveFile,
    );
    return result.success;
  }

  @visibleForTesting
  Future<String?> writeLocalBackupFileForTesting({
    required String fileName,
    required Uint8List content,
  }) =>
      _writeLocalBackupFile(fileName: fileName, content: content);

  @visibleForTesting
  Future<bool> completeLocalBackupAfterWriteForTesting({
    required String writtenLocalPath,
    required Future<String?> Function() saveMetadata,
    required Future<void> Function() recordSuccessfulBackup,
  }) async {
    final result = await _completeLocalBackupAfterWrite(
      writtenLocalPath: writtenLocalPath,
      saveMetadata: saveMetadata,
      recordSuccessfulBackup: recordSuccessfulBackup,
    );
    return result.success;
  }

  @visibleForTesting
  void resetPublishTestingHooks() {
    localBackupTempWriterForTesting = null;
    beforeLocalBackupRenameForTesting = null;
  }

  @visibleForTesting
  Future<void> pruneLocalBackupsForTesting({
    int keep = BackupFilename.keepLatestSuccessfulCount,
    String? retainBackupId,
  }) =>
      _pruneLocalBackups(keep: keep, retainBackupId: retainBackupId);

  @visibleForTesting
  void setCancelRequestedForTesting(bool value) => _cancelRequested = value;

  @visibleForTesting
  void setBackupInProgressForTesting(bool value) {
    _isBackupInProgress = value;
    _backupOperationActive = value;
  }

  @visibleForTesting
  void updateProgressForTesting(
    int percentage,
    BackupStatus backupStatus,
    String action,
  ) =>
      _updateProgress(percentage, backupStatus, action);

  /// Request cooperative cancellation of the active backup/restore.
  Future<void> cancelCurrentOperation() async {
    if (!_isBackupInProgress && !_isRestoreInProgress) {
      return;
    }

    _cancelRequested = true;

    if (_isBackupInProgress) {
      if (kDebugMode) {
        debugPrint('BACKUP_CANCEL_REQUESTED');
      }
      _updateProgress(
        _currentProgress.percentage,
        BackupStatus.cancelled,
        'Backup cancelled',
      );
    }

    if (_isRestoreInProgress) {
      if (_restoreMutating) {
        if (kDebugMode) {
          debugPrint('RESTORE_CANCEL_IGNORED_DURING_APPLY');
        }
        return;
      }
      _updateProgress(
        _currentProgress.percentage,
        null,
        'Restore cancelled',
        RestoreStatus.cancelled,
      );
    }
  }

  static void _sortDriveFilesNewestFirst(List<drive.File> files) {
    files.sort((a, b) {
      final aTime = a.modifiedTime ?? a.createdTime;
      final bTime = b.modifiedTime ?? b.createdTime;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
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

  /// Validates encrypted backup JSON envelope shape (not cryptographic integrity).
  bool _validateEncryptedBackupEnvelope(Map<String, dynamic> encryptedBackup) {
    return DriveBackupDiscovery.validateBackupEnvelope(encryptedBackup);
  }

  Future<BackupAccountIdentitySnapshot> _cloudIdentitySnapshot() async {
    final user = FirebaseAuth.instance.currentUser;
    return BackupAccountIdentitySnapshot(
      firebaseEmail: user?.email,
      firebaseProviderIds:
          user?.providerData.map((info) => info.providerId).toList() ??
              const [],
      googleDriveEmail: _driveService.currentUser?.email,
      keyOwnerEmail: await _keyManager.readStoredKeyOwnerEmail(),
    );
  }
}

class _EncryptedBackupPayload {
  const _EncryptedBackupPayload({
    required this.backupId,
    required this.encryptedBytes,
    required this.checksum,
    required this.originalSize,
    required this.flightLogsCount,
  });

  final String backupId;
  final Uint8List encryptedBytes;
  final String checksum;
  final int originalSize;
  final int flightLogsCount;
}

class _BackupPublishResult {
  const _BackupPublishResult._({
    required this.success,
    this.metadataBackupId,
  });

  const _BackupPublishResult.success({
    required String metadataBackupId,
  }) : this._(
          success: true,
          metadataBackupId: metadataBackupId,
        );

  const _BackupPublishResult.failure({
    String? metadataBackupId,
  }) : this._(
          success: false,
          metadataBackupId: metadataBackupId,
        );

  final bool success;
  final String? metadataBackupId;
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

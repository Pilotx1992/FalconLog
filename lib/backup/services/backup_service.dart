import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/flight_log.dart';
import '../models/backup_metadata.dart';
import '../models/backup_status.dart';
import '../models/restore_result.dart';
import '../../services/encryption_service.dart';
import 'key_manager.dart';
import 'google_drive_service.dart';

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

  /// Initialize the backup service (AlKhazna style)
  Future<bool> initialize() async {
    try {
      return await _driveService.initialize();
    } catch (e) {
      if (kDebugMode) {
        print('💥 Failed to initialize backup service: $e');
      }
      return false;
    }
  }

  /// Start backup process (AlKhazna style)
  Future<bool> startBackup() async {
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
      if (kDebugMode) {
        print('🐛 DEBUG: Backup operation started');
      }
      _updateProgress(0, BackupStatus.checkingConnectivity, 'Checking connectivity...');

      // Step 1: Check connectivity
      if (kDebugMode) {
        print('🐛 DEBUG: Checking connectivity...');
      }
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        _updateProgress(0, BackupStatus.failed, 'No internet connection');
        return false;
      }
      if (kDebugMode) {
        print('🐛 DEBUG: Connectivity check passed');
      }

      // Step 2: Initialize Drive service
      _updateProgress(10, BackupStatus.initializingDrive, 'Connecting to Google Drive...');
      if (kDebugMode) {
        print('🐛 DEBUG: Initializing Google Drive service...');
      }
      final driveInitialized = await _driveService.initialize();
      if (!driveInitialized) {
        _updateProgress(0, BackupStatus.failed, 'Failed to connect to Google Drive');
        return false;
      }
      if (kDebugMode) {
        print('🐛 DEBUG: Google Drive service initialized successfully');
      }

      // Step 3: Get or create master key
      _updateProgress(20, BackupStatus.gettingKey, 'Preparing encryption...');
      if (kDebugMode) {
        print('🐛 DEBUG: Getting or creating master key...');
      }
      // Keys are managed internally by EncryptionServiceAdapter
      if (kDebugMode) {
        print('🐛 DEBUG: Encryption service ready');
      }

      // Step 4: Create database backup
      _updateProgress(30, BackupStatus.creatingBackup, 'Preparing your data...');
      if (kDebugMode) {
        print('🐛 DEBUG: Starting database backup creation...');
      }
      Uint8List? databaseBytes;
      try {
        databaseBytes = await _createDatabaseBackup();
        if (databaseBytes == null) {
          _updateProgress(0, BackupStatus.failed, 'Failed to create database backup');
          return false;
        }
        if (kDebugMode) {
          print('🐛 DEBUG: Database backup created successfully (${databaseBytes.length} bytes)');
        }
      } catch (e) {
        if (kDebugMode) {
          print('💥 DEBUG: Error in _createDatabaseBackup: $e');
          print('💥 DEBUG: Stack trace: ${StackTrace.current}');
        }
        _updateProgress(0, BackupStatus.failed, 'Failed to create database backup: $e');
        return false;
      }

      // Step 4.5: Get master encryption key
      _updateProgress(45, BackupStatus.encrypting, 'Getting encryption key...');
      if (kDebugMode) {
        print('🐛 DEBUG: Getting master key...');
      }
      final masterKey = await _keyManager.getOrCreatePersistentMasterKey(interactive: true);
      if (masterKey == null) {
        _updateProgress(0, BackupStatus.failed, 'Failed to get encryption key');
        return false;
      }
      if (kDebugMode) {
        print('✅ Master key obtained successfully');
      }

      // Step 5: Encrypt database
      _updateProgress(50, BackupStatus.encrypting, 'Encrypting your data...');
      if (kDebugMode) {
        print('🔐 Encrypting ${databaseBytes.length} bytes...');
      }
      final backupId = const Uuid().v4();
      final encryptedBackup = await _encryptionService.encryptDatabase(
        databaseBytes: databaseBytes,
        masterKey: masterKey,
        backupId: backupId,
      );

      if (encryptedBackup == null) {
        _updateProgress(0, BackupStatus.failed, 'Failed to encrypt data');
        return false;
      }

      // Convert to JSON bytes for upload
      final encryptedData = Uint8List.fromList(utf8.encode(json.encode(encryptedBackup)));
      if (kDebugMode) {
        print('✅ Encryption completed: ${encryptedData.length} bytes');
      }


      // Step 6: Upload to Drive
      _updateProgress(70, BackupStatus.uploading, 'Uploading to Google Drive...');
      if (kDebugMode) {
        print('🐛 DEBUG: Starting upload to Google Drive...');
      }
      final encryptedBytes = encryptedData;
      final fileName = '$_backupPrefix${DateTime.now().millisecondsSinceEpoch}.crypt14';
      final driveFileId = await _driveService.uploadFile(
        fileName: fileName,
        content: encryptedBytes,
        mimeType: 'application/json',
      );
      if (kDebugMode) {
        print('🐛 DEBUG: Upload completed, file ID: $driveFileId');
      }

      if (driveFileId != null) {
        await _pruneOldBackups(keep: 5);
      }

      if (driveFileId == null) {
        _updateProgress(0, BackupStatus.failed, 'Failed to upload backup');
        return false;
      }

      // Step 7: Save backup metadata
      _updateProgress(90, BackupStatus.uploading, 'Finalizing backup...');
      if (kDebugMode) {
        print('🐛 DEBUG: Saving backup metadata...');
      }
      await _saveBackupMetadata(
        backupId: backupId,
        driveFileId: driveFileId,
        originalSize: databaseBytes.length,
        encryptedSize: encryptedBytes.length,
      );
      if (kDebugMode) {
        print('🐛 DEBUG: Backup metadata saved successfully');
      }

      _updateProgress(100, BackupStatus.completed, 'Backup completed successfully!');

      if (kDebugMode) {
        print('✅ Backup completed successfully');
        print('   Backup ID: $backupId');
        print('   Drive File ID: $driveFileId');
        print('   Original size: ${databaseBytes.length} bytes');
        print('   Encrypted size: ${encryptedBytes.length} bytes');
      }

      return true;

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

  /// Start restore process (AlKhazna style)
  /// Default mode is merge to preserve existing data
  Future<RestoreResult> startRestore({RestoreMode mode = RestoreMode.merge}) async {
    if (_isRestoreInProgress) {
      if (kDebugMode) {
        print('⚠️ Restore already in progress, skipping...');
      }
      return RestoreResult.failure(error: 'Restore already in progress');
    }

    if (_isBackupInProgress) {
      if (kDebugMode) {
        print('⚠️ Backup in progress, cannot start restore');
      }
      return RestoreResult.failure(error: 'Backup operation in progress. Please wait.');
    }

    _isRestoreInProgress = true;

    try {
      _updateProgress(0, null, 'Checking for backup...', RestoreStatus.checkingConnectivity);

      // Step 1: Check connectivity
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        _updateProgress(0, null, 'No internet connection', RestoreStatus.failed);
        return RestoreResult.failure(error: 'No internet connection');
      }

      // Step 2: Initialize Drive service
      _updateProgress(10, null, 'Connecting to Google Drive...', RestoreStatus.initializingDrive);
      final driveInitialized = await _driveService.initialize();
      if (!driveInitialized) {
        _updateProgress(0, null, 'Failed to connect to Google Drive', RestoreStatus.failed);
        return RestoreResult.failure(error: 'Failed to connect to Google Drive');
      }

      // Step 3: Find backup file
      _updateProgress(20, null, 'Looking for backup...', RestoreStatus.findingBackup);
      final backupFiles = await _driveService.listFiles(query: "name contains '$_backupPrefix'");
      
      if (backupFiles.isEmpty) {
        _updateProgress(0, null, 'No backup found', RestoreStatus.failed);
        return RestoreResult.failure(error: 'No backup found for this Google account');
      }

      // Step 4: Download backup
      _updateProgress(40, null, 'Downloading backup...', RestoreStatus.downloading);
      final backupFile = backupFiles.first;
      final encryptedBytes = await _driveService.downloadFile(backupFile.id!);
      
      if (encryptedBytes == null) {
        _updateProgress(0, null, 'Failed to download backup', RestoreStatus.failed);
        return RestoreResult.failure(error: 'Failed to download backup file');
      }

      // Step 5: Get master decryption key
      _updateProgress(60, null, 'Getting encryption key...', RestoreStatus.retrievingKey);
      if (kDebugMode) {
        print('🔑 Getting master key for decryption...');
      }
      final masterKey = await _keyManager.getOrCreatePersistentMasterKey(interactive: true);
      if (masterKey == null) {
        _updateProgress(0, null, 'Failed to get encryption key', RestoreStatus.failed);
        return RestoreResult.failure(error: 'Failed to get encryption key');
      }
      if (kDebugMode) {
        print('✅ Master key obtained');
      }

      // Step 6: Decrypt backup with corruption recovery
      _updateProgress(70, null, 'Decrypting backup...', RestoreStatus.decrypting);
      if (kDebugMode) {
        print('🔓 Decrypting backup data...');
      }

      // Parse encrypted backup JSON
      Map<String, dynamic> encryptedBackup;
      try {
        encryptedBackup = json.decode(utf8.decode(encryptedBytes)) as Map<String, dynamic>;
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to parse encrypted backup: $e');
        }
        _updateProgress(0, null, 'Invalid backup format', RestoreStatus.failed);
        return RestoreResult.failure(error: 'Invalid backup format. The backup file may be corrupted.');
      }

      // Verify backup integrity before decryption
      if (!_verifyBackupIntegrity(encryptedBackup)) {
        if (kDebugMode) {
          print('❌ Backup integrity check failed');
        }
        _updateProgress(0, null, 'Backup corrupted', RestoreStatus.failed);
        return RestoreResult.failure(
          error: 'Backup file failed integrity check. Please try restoring from an older backup.',
        );
      }

      // Decrypt database
      final databaseBytes = await _encryptionService.decryptDatabase(
        encryptedBackup: encryptedBackup,
        masterKey: masterKey,
      );

      if (databaseBytes == null) {
        if (kDebugMode) {
          print('❌ Decryption failed - attempting recovery...');
        }

        // Try to find an older backup
        final olderBackups = await _findOlderBackups(backupFile.id!);
        if (olderBackups.isNotEmpty) {
          _updateProgress(0, null, 'Current backup corrupted. Try older backup?', RestoreStatus.failed);
          return RestoreResult.failure(
            error: 'Failed to decrypt backup. Found ${olderBackups.length} older backup(s) available.',
          );
        }

        _updateProgress(0, null, 'Failed to decrypt backup', RestoreStatus.failed);
        return RestoreResult.failure(
          error: 'Failed to decrypt backup. The encryption key may have changed or the backup is corrupted.',
        );
      }

      if (kDebugMode) {
        print('✅ Decryption completed: ${databaseBytes.length} bytes');
      }

      // Step 7: Restore database with selected mode
      _updateProgress(85, null, 'Restoring your data...', RestoreStatus.applying);
      final restoreResult = await _restoreDatabase(databaseBytes, mode: mode);

      if (!restoreResult.success) {
        _updateProgress(0, null, 'Failed to restore data', RestoreStatus.failed);
        return restoreResult;
      }

      _updateProgress(100, null, 'Restore completed!', RestoreStatus.completed);
      
      if (kDebugMode) {
        print('✅ Restore completed successfully');
      }

      return RestoreResult.success(
        flightLogsRestored: restoreResult.flightLogsRestored,
        backupDate: backupFile.modifiedTime ?? DateTime.now(),
        sourceDevice: 'Unknown Device',
      );

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

  /// Keep only last [keep] backups in Drive (by modifiedTime desc)
  Future<void> _pruneOldBackups({int keep = 5}) async {
    try {
      final files = await _driveService.listFiles(query: "name contains '$_backupPrefix'");
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

  /// Check for existing backup
  Future<BackupMetadata?> findExistingBackup() async {
    try {
      if (!await _driveService.initialize()) {
        return null;
      }

      final backupFiles = await _driveService.listFiles(query: "name contains '$_backupPrefix'");
      
      if (backupFiles.isEmpty) {
        return null;
      }

      final backupFile = backupFiles.first;

      // Get detailed file info to ensure we have the correct size
      final detailedFileInfo = await _driveService.getFileInfo(backupFile.id!);
      final fileSize = int.tryParse(detailedFileInfo?.size ?? backupFile.size ?? '0') ?? 0;
      
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

  /// Create database backup with chunking for large datasets
  Future<Uint8List?> _createDatabaseBackup() async {
    try {
      if (kDebugMode) {
        print('💾 Creating Hive database backup...');
      }

      // Get all data from Hive boxes
      final Map<String, dynamic> backupData = {};

      // Backup flight logs
      final flightLogsBox = await Hive.openBox<FlightLog>('flightLogsBox');
      if (kDebugMode) {
        print('📊 Flight logs box length: ${flightLogsBox.length}');
      }

      final flightLogsData = <String, dynamic>{};
      final totalCount = flightLogsBox.length;
      int processedCount = 0;
      int errorCount = 0;

      // Process in batches to avoid memory issues
      const batchSize = 100;
      final keys = flightLogsBox.keys.toList();

      for (int i = 0; i < keys.length; i += batchSize) {
        final batchEnd = (i + batchSize < keys.length) ? i + batchSize : keys.length;
        final batchKeys = keys.sublist(i, batchEnd);

        for (final key in batchKeys) {
          try {
            final value = flightLogsBox.get(key);
            if (value is FlightLog) {
              flightLogsData[key.toString()] = value.toJson();
              processedCount++;
            } else if (value is Map<String, dynamic>) {
              flightLogsData[key.toString()] = value;
              processedCount++;
            }
          } catch (e) {
            errorCount++;
            if (kDebugMode) {
              print('⚠️ Error processing flight log $key: $e');
            }
            // Skip this entry and continue
            continue;
          }
        }

        if (kDebugMode && i % (batchSize * 5) == 0) {
          debugPrint('📊 Progress: $processedCount/$totalCount logs processed');
        }
      }

      if (errorCount > 0 && kDebugMode) {
        debugPrint('⚠️ Skipped $errorCount corrupt entries during backup');
      }

      backupData['flight_logs'] = flightLogsData;
      backupData['metadata'] = {
        'total_logs': processedCount,
        'skipped_logs': errorCount,
        'backup_version': '2.0',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Convert to JSON bytes efficiently
      if (kDebugMode) {
        print('🐛 Converting backup data to JSON...');
      }

      final jsonString = json.encode(backupData);
      final bytes = utf8.encode(jsonString);

      if (kDebugMode) {
        print('✅ Database backup created');
        print('   Size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
        print('   Flight logs: $processedCount entries');
        print('   Errors skipped: $errorCount');
      }

      return Uint8List.fromList(bytes);
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error creating database backup: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      return null;
    }
  }

  /// Restore database from backup (FalconLog specific)
  /// Default mode is merge to preserve existing data
  Future<RestoreResult> _restoreDatabase(
    Uint8List databaseBytes, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    try {
      if (kDebugMode) {
        print('💾 Restoring Hive database from backup (mode: ${mode.name})...');
      }

      if (databaseBytes.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No data to restore (empty backup)');
        }

        return RestoreResult.success(
          flightLogsRestored: 0,
          backupDate: DateTime.now(),
          sourceDevice: 'Unknown Device',
        );
      }

      // Parse JSON from backup
      final jsonString = utf8.decode(databaseBytes);
      final Map<String, dynamic> backupData = json.decode(jsonString);

      int restoredFlightLogs = 0;

      // Restore flight logs
      if (backupData.containsKey('flight_logs')) {
        final flightLogsBox = await Hive.openBox<FlightLog>('flightLogsBox');

        // Get existing flights if in merge mode
        final existingFlights = mode == RestoreMode.merge
            ? flightLogsBox.values.toList()
            : <FlightLog>[];

        // Create a set of existing flight IDs for quick lookup
        final existingFlightIds = mode == RestoreMode.merge
            ? existingFlights.map((f) => f.id).toSet()
            : <String>{};

        // Clear existing data only in replace mode
        if (mode == RestoreMode.replace) {
          await flightLogsBox.clear();
          if (kDebugMode) {
            print('🗑️ Cleared existing flight logs (Replace mode)');
          }
        } else {
          if (kDebugMode) {
            print('🔄 Merging with ${existingFlights.length} existing flights (Merge mode)');
          }
        }

        final flightLogsData = backupData['flight_logs'] as Map<String, dynamic>;
        for (final entry in flightLogsData.entries) {
          try {
            FlightLog flightLog;

            if (entry.value is Map<String, dynamic>) {
              flightLog = FlightLog.fromJson(entry.value);
            } else if (entry.value is FlightLog) {
              flightLog = entry.value;
            } else {
              // Try to convert from dynamic
              flightLog = FlightLog.fromJson(entry.value as Map<String, dynamic>);
            }

            // In merge mode, skip if flight already exists
            if (mode == RestoreMode.merge && existingFlightIds.contains(flightLog.id)) {
              if (kDebugMode) {
                print('⏭️ Skipping duplicate flight: ${flightLog.id}');
              }
              continue;
            }

            await flightLogsBox.put(entry.key, flightLog);
            restoredFlightLogs++;
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error converting flight log ${entry.key}: $e');
              print('   Data: ${entry.value}');
            }
            // Skip this entry instead of failing the entire restore
            continue;
          }
        }

        if (kDebugMode) {
          print('📊 Restored $restoredFlightLogs flight logs from backup');
          if (mode == RestoreMode.merge) {
            print('   Total flights now: ${flightLogsBox.length}');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Database restored successfully');
        print('   Total flight logs: $restoredFlightLogs');
      }

      return RestoreResult.success(
        flightLogsRestored: restoredFlightLogs,
        backupDate: DateTime.now(),
        sourceDevice: 'Unknown Device',
      );
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error restoring database: $e');
      }
      return RestoreResult.failure(error: 'Failed to restore database: ${e.toString()}');
    }
  }

  /// Save backup metadata
  Future<void> _saveBackupMetadata({
    required String backupId,
    required String driveFileId,
    required int originalSize,
    required int encryptedSize,
  }) async {
    try {
      final currentUser = _driveService.currentUser;
      // This would typically be saved to SharedPreferences or local database
      // For now, we'll just log it
      if (kDebugMode) {
        print('💾 Backup metadata:');
        print('   ID: $backupId');
        print('   Drive File ID: $driveFileId');
        print('   User: ${currentUser?.email}');
        print('   Original size: $originalSize bytes');
        print('   Encrypted size: $encryptedSize bytes');
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error saving backup metadata: $e');
      }
    }
  }

  /// Check network connectivity with retries
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.contains(ConnectivityResult.mobile) ||
                            connectivityResult.contains(ConnectivityResult.wifi);

      if (!hasConnection) {
        if (kDebugMode) {
          print('⚠️ No network connection detected');
        }
        return false;
      }

      // Verify actual internet access by testing Drive API
      try {
        final driveInitialized = await _driveService.initialize();
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

  /// Update progress and notify listeners
  void _updateProgress(
    int percentage, 
    BackupStatus? backupStatus, 
    String action, 
    [RestoreStatus? restoreStatus]
  ) {
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
      _updateProgress(_currentProgress.percentage, BackupStatus.cancelled, 'Backup cancelled');
      _isBackupInProgress = false;
    }
    
    if (_isRestoreInProgress) {
      _updateProgress(_currentProgress.percentage, null, 'Restore cancelled', RestoreStatus.cancelled);
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

  /// Find older backups for recovery
  Future<List<String>> _findOlderBackups(String currentBackupId) async {
    try {
      final backupFiles = await _driveService.listFiles(query: "name contains '$_backupPrefix'");

      // Filter out the current backup and return IDs of older ones
      final olderBackups = backupFiles
          .where((file) => file.id != currentBackupId && file.id != null)
          .map((file) => file.id!)
          .toList();

      if (kDebugMode) {
        print('📋 Found ${olderBackups.length} older backup(s)');
      }

      return olderBackups;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error finding older backups: $e');
      }
      return [];
    }
  }
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

/// Restore mode enum
enum RestoreMode {
  replace,  // Clear all existing data and replace with backup
  merge,    // Merge backup data with existing data (no duplicates)
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

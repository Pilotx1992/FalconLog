import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/drive_file_meta.dart';
import 'drive_auth_service.dart';

/// Service for managing Google Drive backup operations
class GoogleDriveService {
  static const String _folderIdKey = 'drive.backupFolderId';
  static const String _backupFolderName = 'FalconLog_Backups';
  
  final DriveAuthService _authService;
  drive.DriveApi? _driveApi;
  String? _cachedFolderId;

  GoogleDriveService(this._authService);

  /// Gets an authenticated Drive API client
  Future<drive.DriveApi?> _getDriveApi() async {
    // Return cached client if available and still valid (within 5 minutes)
    if (_driveApi != null) return _driveApi;

    final account = await _authService.ensureAuthenticated();
    if (account == null) return null;

    // Stub implementation - TODO: Fix when Google Sign In API is properly configured
    debugPrint('Google Drive API not properly configured');
    return null;
  }

  /// Ensures the backup folder exists and returns its ID
  /// Uses cached folder ID to minimize API calls
  Future<String?> ensureBackupFolder() async {
    try {
      // Return cached folder ID if available
      if (_cachedFolderId != null) return _cachedFolderId;

      // Try to load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getString(_folderIdKey);
      if (cachedId != null) {
        _cachedFolderId = cachedId;
        return cachedId;
      }

      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      // Search for existing backup folder
      final query = "name = '$_backupFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final searchResult = await driveApi.files.list(q: query);

      String folderId;
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        // Folder exists, use the first one
        folderId = searchResult.files!.first.id!;
      } else {
        // Create new folder
        final folder = drive.File()
          ..name = _backupFolderName
          ..mimeType = 'application/vnd.google-apps.folder';
        
        final createdFolder = await driveApi.files.create(folder);
        folderId = createdFolder.id!;
      }

      // Cache the folder ID
      _cachedFolderId = folderId;
      await prefs.setString(_folderIdKey, folderId);
      
      return folderId;
    } catch (e) {
      print('Error ensuring backup folder: $e');
      return null;
    }
  }

  /// Uploads an encrypted backup file to Google Drive
  Future<DriveFileMeta?> uploadEncryptedBackup(File file, {String? sha256}) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final folderId = await ensureBackupFolder();
      if (folderId == null) return null;

      // Prepare file metadata
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileSize = await file.length();
      
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];

      // Add SHA256 to app properties if provided
      if (sha256 != null) {
        driveFile.appProperties = {'sha256': sha256};
      }

      // Choose upload method based on file size
      drive.File uploadedFile;
      bool resumable = false;
      if (fileSize < 5 * 1024 * 1024) { // < 5MB - use simple upload
        final media = drive.Media(file.openRead(), fileSize);
        uploadedFile = await driveApi.files.create(driveFile, uploadMedia: media);
      } else { // >= 5MB - use resumable upload
        final media = drive.Media(file.openRead(), fileSize);
        uploadedFile = await driveApi.files.create(
          driveFile,
          uploadMedia: media,
          uploadOptions: drive.ResumableUploadOptions(),
        );
        resumable = true;
      }
      final meta = DriveFileMeta.fromDriveFile(uploadedFile);
      print('[Drive][UPLOAD ${resumable ? 'RESUMABLE' : 'SIMPLE'}] id=${meta.id} name=${meta.name} size=${meta.size}');
      return meta;
    } catch (e) {
      print('Error uploading backup: $e');
      return null;
    }
  }

  /// Lists all backup files from Google Drive
  Future<List<DriveFileMeta>> listBackups() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return [];

      final folderId = await ensureBackupFolder();
      if (folderId == null) return [];

      final query = "'$folderId' in parents and trashed = false";
      final result = await driveApi.files.list(
        q: query,
        orderBy: 'createdTime desc',
        $fields: 'files(id,name,size,createdTime,modifiedTime,sha256Checksum,appProperties)',
      );

      if (result.files == null) return [];

      final metas = result.files!
          .map((file) => DriveFileMeta.fromDriveFile(file))
          .toList();
      if (metas.isNotEmpty) {
        print('[Drive][LIST] ${metas.length} files: ${metas.map((m) => m.id).join(', ')}');
      } else {
        print('[Drive][LIST] no backups');
      }
      return metas;
    } catch (e) {
      print('Error listing backups: $e');
      return [];
    }
  }

  /// Downloads a backup file from Google Drive
  Future<File?> downloadBackup(String fileId, String localPath) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      // Get file content
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Create local file
      final file = File(localPath);
      await file.create(recursive: true);

      // Write content to file
      final sink = file.openWrite();
      await sink.addStream(response.stream);
      await sink.close();

      return file;
    } catch (e) {
      print('Error downloading backup: $e');
      return null;
    }
  }

  /// Deletes a backup file from Google Drive
  Future<bool> deleteBackup(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

  await driveApi.files.delete(fileId);
  print('[Drive][DELETE] id=$fileId');
  return true;
    } catch (e) {
      print('Error deleting backup: $e');
      return false;
    }
  }

  /// Removes old backup files, keeping only the specified number
  Future<void> pruneBackups(int keepCount) async {
    try {
      if (keepCount <= 0) return;

      final backups = await listBackups();
      if (backups.length <= keepCount) return; // Nothing to prune

      // Sort by creation time (newest first) - listBackups already does this
      final toDelete = backups.skip(keepCount).toList();

      for (final backup in toDelete) {
        final deleted = await deleteBackup(backup.id);
        if (deleted) {
          print('[Drive][PRUNE] deleted id=${backup.id} name=${backup.name}');
        }
      }
    } catch (e) {
      print('Error pruning backups: $e');
    }
  }

  /// Clears cached folder ID (useful when switching accounts)
  Future<void> clearCache() async {
    _cachedFolderId = null;
    _driveApi = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_folderIdKey);
  }

  /// Gets storage info for the backup folder
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final backups = await listBackups();
      final totalSize = backups.fold<int>(0, (sum, backup) => sum + backup.size);
      
      return {
        'backupCount': backups.length,
        'totalSize': totalSize,
        'formattedSize': _formatBytes(totalSize),
        'oldestBackup': backups.isEmpty ? null : backups.last.createdTime,
        'newestBackup': backups.isEmpty ? null : backups.first.createdTime,
      };
    } catch (e) {
      print('Error getting storage info: $e');
      return {
        'backupCount': 0,
        'totalSize': 0,
        'formattedSize': '0B',
        'oldestBackup': null,
        'newestBackup': null,
      };
    }
  }

  /// Formats bytes to human readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

// --- Riverpod Providers ---

/// Provider for the [GoogleDriveService] instance.
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final authService = ref.watch(driveAuthServiceProvider);
  return GoogleDriveService(authService);
});

/// StateProvider to track whether a Drive operation is in progress
final driveOperationInProgressProvider = StateProvider<bool>((ref) => false);

/// FutureProvider to get Drive storage information
final driveStorageInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final driveService = ref.watch(googleDriveServiceProvider);
  return await driveService.getStorageInfo();
});

/// FutureProvider to list all backups from Drive
final driveBackupsProvider = FutureProvider<List<DriveFileMeta>>((ref) async {
  final driveService = ref.watch(googleDriveServiceProvider);
  return await driveService.listBackups();
});

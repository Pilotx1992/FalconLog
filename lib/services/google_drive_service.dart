import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/exceptions/backup_exceptions.dart';
import '../models/drive_file_meta.dart';
import 'drive_auth_service.dart';

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headerProvider) : _client = http.Client();

  final http.Client _client;
  final Future<Map<String, String>> Function() _headerProvider;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _headerProvider();
    request.headers.addAll(headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Service for managing Google Drive backup operations
class GoogleDriveService {
  static const String _folderIdKey = 'drive.backupFolderId';
  static const String _backupFolderName = 'FalconLog_Backups';

  final DriveAuthService _authService;
  drive.DriveApi? _driveApi;
  GoogleAuthClient? _authClient;
  String? _cachedFolderId;
  static final _logger = Logger('GoogleDriveService');

  GoogleDriveService(this._authService);

  void _resetAuthClient() {
    _authClient?.close();
    _authClient = null;
    _driveApi = null;
  }

  /// Gets an authenticated Drive API client.
  Future<drive.DriveApi?> _getDriveApi({bool interactive = true}) async {
    if (_driveApi != null) {
      if (!_authService.isSignedIn) {
        _resetAuthClient();
      } else {
        return _driveApi;
      }
    }

    try {
      await _authService.getAuthHeaders(interactive: interactive);
      final client = GoogleAuthClient(
        () => _authService.getAuthHeaders(
          interactive: false,
          attemptSilent: false,
        ),
      );
      final api = drive.DriveApi(client);

      _authClient?.close();
      _authClient = client;
      _driveApi = api;
      return _driveApi;
    } on CloudAuthenticationException catch (error, stackTrace) {
      _logger.severe('Google authentication failed', error, stackTrace);
      return null;
    } catch (error, stackTrace) {
      _logger.severe('Error creating Drive API client', error, stackTrace);
      return null;
    }
  }

  /// Ensures the backup folder exists and returns its ID.
  /// Uses cached folder ID to minimize API calls.
  Future<String?> ensureBackupFolder({bool interactive = true}) async {
    try {
      if (_cachedFolderId != null) {
        return _cachedFolderId;
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getString(_folderIdKey);
      if (cachedId != null) {
        _cachedFolderId = cachedId;
        return cachedId;
      }

      final driveApi = await _getDriveApi(interactive: interactive);
      if (driveApi == null) return null;

      final query =
          "name = '$_backupFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final searchResult = await driveApi.files.list(q: query);

      String folderId;
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        folderId = searchResult.files!.first.id!;
      } else {
        final folder = drive.File()
          ..name = _backupFolderName
          ..mimeType = 'application/vnd.google-apps.folder';

        final createdFolder = await driveApi.files.create(folder);
        folderId = createdFolder.id!;
      }

      _cachedFolderId = folderId;
      await prefs.setString(_folderIdKey, folderId);

      return folderId;
    } catch (error, stackTrace) {
      _logger.severe('Error ensuring backup folder', error, stackTrace);
      return null;
    }
  }

  /// Uploads an encrypted backup file to Google Drive.
  Future<DriveFileMeta?> uploadEncryptedBackup(
    File file, {
    String? sha256,
    bool interactive = true,
  }) async {
    try {
      final driveApi = await _getDriveApi(interactive: interactive);
      if (driveApi == null) return null;

      final folderId = await ensureBackupFolder(interactive: interactive);
      if (folderId == null) return null;

      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileSize = await file.length();

      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];

      if (sha256 != null) {
        driveFile.appProperties = {'sha256': sha256};
      }

      drive.File uploadedFile;
      bool resumable = false;
      if (fileSize < 5 * 1024 * 1024) {
        final media = drive.Media(file.openRead(), fileSize);
        uploadedFile = await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
      } else {
        final media = drive.Media(file.openRead(), fileSize);
        uploadedFile = await driveApi.files.create(
          driveFile,
          uploadMedia: media,
          uploadOptions: drive.ResumableUploadOptions(),
        );
        resumable = true;
      }
      final meta = DriveFileMeta.fromDriveFile(uploadedFile);
      _logger.info(
        'Drive upload ${resumable ? 'resumable' : 'simple'}: id=${meta.id} name=${meta.name} size=${meta.size}',
      );
      return meta;
    } catch (error, stackTrace) {
      _logger.severe('Error uploading backup', error, stackTrace);
      return null;
    }
  }

  /// Lists all backup files from Google Drive.
  Future<List<DriveFileMeta>> listBackups({bool interactive = false}) async {
    try {
      final driveApi = await _getDriveApi(interactive: interactive);
      if (driveApi == null) return [];

      final folderId = await ensureBackupFolder(interactive: interactive);
      if (folderId == null) return [];

      final query = "'$folderId' in parents and trashed = false";
      final result = await driveApi.files.list(
        q: query,
        orderBy: 'createdTime desc',
        $fields:
            'files(id,name,size,createdTime,modifiedTime,sha256Checksum,appProperties)',
      );

      if (result.files == null) return [];

      final metas = result.files!
          .map((file) => DriveFileMeta.fromDriveFile(file))
          .toList();
      if (metas.isNotEmpty) {
        _logger.info(
          'Drive list: ${metas.length} files: ${metas.map((m) => m.id).join(', ')}',
        );
      } else {
        _logger.info('Drive list: no backups');
      }
      return metas;
    } catch (error, stackTrace) {
      _logger.severe('Error listing backups', error, stackTrace);
      return [];
    }
  }

  /// Downloads a backup file from Google Drive.
  Future<File?> downloadBackup(
    String fileId,
    String localPath, {
    bool interactive = true,
  }) async {
    try {
      final driveApi = await _getDriveApi(interactive: interactive);
      if (driveApi == null) return null;

      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final file = File(localPath);
      await file.create(recursive: true);

      final sink = file.openWrite();
      await sink.addStream(response.stream);
      await sink.close();

      return file;
    } catch (error, stackTrace) {
      _logger.severe('Error downloading backup', error, stackTrace);
      return null;
    }
  }

  /// Deletes a backup file from Google Drive.
  Future<bool> deleteBackup(String fileId, {bool interactive = false}) async {
    try {
      final driveApi = await _getDriveApi(interactive: interactive);
      if (driveApi == null) return false;

      await driveApi.files.delete(fileId);
      _logger.info('Drive delete: id=$fileId');
      return true;
    } catch (error, stackTrace) {
      _logger.severe('Error deleting backup', error, stackTrace);
      return false;
    }
  }

  /// Removes old backup files, keeping only the specified number.
  Future<void> pruneBackups(int keepCount, {bool interactive = false}) async {
    try {
      if (keepCount <= 0) return;

      final backups = await listBackups(interactive: interactive);
      if (backups.length <= keepCount) return;

      final toDelete = backups.skip(keepCount).toList();

      for (final backup in toDelete) {
        final deleted = await deleteBackup(backup.id, interactive: interactive);
        if (deleted) {
          _logger
              .info('Drive prune: deleted id=${backup.id} name=${backup.name}');
        }
      }
    } catch (error, stackTrace) {
      _logger.severe('Error pruning backups', error, stackTrace);
    }
  }

  /// Clears cached data (useful when switching accounts).
  Future<void> clearCache() async {
    _cachedFolderId = null;
    _resetAuthClient();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_folderIdKey);
  }

  /// Gets storage info for the backup folder.
  Future<Map<String, dynamic>> getStorageInfo(
      {bool interactive = false}) async {
    try {
      final backups = await listBackups(interactive: interactive);
      final totalSize =
          backups.fold<int>(0, (sum, backup) => sum + backup.size);

      return {
        'backupCount': backups.length,
        'totalSize': totalSize,
        'formattedSize': _formatBytes(totalSize),
        'oldestBackup': backups.isEmpty ? null : backups.last.createdTime,
        'newestBackup': backups.isEmpty ? null : backups.first.createdTime,
      };
    } catch (error, stackTrace) {
      _logger.severe('Error getting storage info', error, stackTrace);
      return {
        'backupCount': 0,
        'totalSize': 0,
        'formattedSize': '0B',
        'oldestBackup': null,
        'newestBackup': null,
      };
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

// --- Riverpod Providers ---

/// Provider for the [GoogleDriveService] instance.
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final authService = ref.watch(driveAuthServiceProvider);
  return GoogleDriveService(authService);
});

/// StateProvider to track whether a Drive operation is in progress.
final driveOperationInProgressProvider = StateProvider<bool>((ref) => false);

/// FutureProvider to get Drive storage information.
final driveStorageInfoProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final driveService = ref.watch(googleDriveServiceProvider);
  return driveService.getStorageInfo(interactive: false);
});

/// FutureProvider to list all backups from Drive.
final driveBackupsProvider = FutureProvider<List<DriveFileMeta>>((ref) async {
  final driveService = ref.watch(googleDriveServiceProvider);
  return driveService.listBackups(interactive: false);
});

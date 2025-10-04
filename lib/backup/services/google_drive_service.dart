import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Simplified Google Drive service following AlKhazna's approach
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.appdata',
      'https://www.googleapis.com/auth/drive.file',
      'email',
      'profile',
    ],
  );

  drive.DriveApi? _driveApi;

  DateTime? _tokenExpiry;

  /// Initialize Google Drive API (AlKhazna style)
  Future<bool> initialize() async {
    try {
      if (kDebugMode) {
        print('🔧 Initializing Google Drive service...');
      }

      // Check if we need to refresh the token
      if (_driveApi != null && _tokenExpiry != null) {
        final now = DateTime.now().toUtc();
        final timeUntilExpiry = _tokenExpiry!.difference(now);

        // Refresh if less than 5 minutes remaining
        if (timeUntilExpiry.inMinutes > 5) {
          if (kDebugMode) {
            print('✅ Using existing valid token (expires in ${timeUntilExpiry.inMinutes} minutes)');
          }
          return true;
        } else {
          if (kDebugMode) {
            print('🔄 Token expires soon, refreshing...');
          }
        }
      }

      // Get authenticated account
      var account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        if (kDebugMode) {
          print('❌ No Google account available');
        }
        return false;
      }

      // Get fresh authentication
      final authentication = await account.authentication;
      final accessToken = authentication.accessToken;

      if (accessToken == null) {
        if (kDebugMode) {
          print('❌ No access token available');
        }
        return false;
      }

      if (kDebugMode) {
        print('🔑 Access token obtained: ${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}...');
      }

      // Set token expiry (use server time if available, otherwise 55 minutes for safety)
      final expiryTime = account.serverAuthCode != null
          ? DateTime.now().toUtc().add(const Duration(minutes: 55))
          : DateTime.now().toUtc().add(const Duration(minutes: 55));

      _tokenExpiry = expiryTime;

      final authenticatedClient = AuthenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken, expiryTime),
          null,
          [
            'https://www.googleapis.com/auth/drive.appdata',
            'https://www.googleapis.com/auth/drive.file',
          ],
        ),
      );

      _driveApi = drive.DriveApi(authenticatedClient);

      if (kDebugMode) {
        print('✅ Google Drive service initialized for: ${account.email}');
        print('🔑 Token expires at: $_tokenExpiry');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Failed to initialize Google Drive: $e');
      }
      _driveApi = null;
      _tokenExpiry = null;
      return false;
    }
  }

  /// Upload file to AppDataFolder (AlKhazna style)
  Future<String?> uploadFile({
    required String fileName,
    required Uint8List content,
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      if (_driveApi == null && !await initialize()) {
        return null;
      }

      if (kDebugMode) {
        print('📤 Uploading file: $fileName (${content.length} bytes)');
      }

      // Check if file already exists and delete it
      final existingFiles = await listFiles(query: "name='$fileName'");
      for (final file in existingFiles) {
        await _driveApi!.files.delete(file.id!);
        if (kDebugMode) {
          print('🗑️ Deleted existing file: ${file.id}');
        }
      }

      // Create new file in AppDataFolder
      final driveFile = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];

      final media = drive.Media(
        Stream.fromIterable([content]),
        content.length,
        contentType: mimeType,
      );

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      if (kDebugMode) {
        print('✅ File uploaded successfully: ${result.id}');
      }

      return result.id;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error uploading file: $e');
      }
      return null;
    }
  }

  /// Download file from AppDataFolder (AlKhazna style)
  Future<Uint8List?> downloadFile(String fileId) async {
    try {
      if (_driveApi == null && !await initialize()) {
        return null;
      }

      if (kDebugMode) {
        print('📥 Downloading file: $fileId');
      }

      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBytes = [];
      await for (var chunk in media.stream) {
        dataBytes.addAll(chunk);
      }

      final result = Uint8List.fromList(dataBytes);
      
      if (kDebugMode) {
        print('✅ File downloaded: ${result.length} bytes');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error downloading file: $e');
      }
      return null;
    }
  }

  /// List files in AppDataFolder (AlKhazna style)
  Future<List<drive.File>> listFiles({String? query}) async {
    try {
      if (_driveApi == null && !await initialize()) {
        return [];
      }

      String searchQuery = "parents in 'appDataFolder' and trashed=false";
      if (query != null) {
        searchQuery += " and $query";
      }

      if (kDebugMode) {
        print('📂 Listing files with query: $searchQuery');
      }

      final fileList = await _driveApi!.files.list(
        q: searchQuery,
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,size,modifiedTime,createdTime)',
      );

      final files = fileList.files ?? [];
      
      if (kDebugMode) {
        print('📋 Found ${files.length} files');
        for (final file in files) {
          print('  - ${file.name} (${file.id}) - Size: ${file.size} - ${file.modifiedTime}');
        }
      }

      return files;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error listing files: $e');
      }
      return [];
    }
  }

  /// Check if file exists in AppDataFolder
  Future<bool> fileExists(String fileName) async {
    try {
      final files = await listFiles(query: "name='$fileName'");
      return files.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error checking file existence: $e');
      }
      return false;
    }
  }

  /// Delete file from AppDataFolder
  Future<bool> deleteFile(String fileId) async {
    try {
      if (_driveApi == null && !await initialize()) {
        return false;
      }

      if (kDebugMode) {
        print('🗑️ Deleting file: $fileId');
      }

      await _driveApi!.files.delete(fileId);
      
      if (kDebugMode) {
        print('✅ File deleted successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error deleting file: $e');
      }
      return false;
    }
  }

  /// Get file info
  Future<drive.File?> getFileInfo(String fileId) async {
    try {
      if (_driveApi == null && !await initialize()) {
        return null;
      }

      return await _driveApi!.files.get(fileId) as drive.File;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error getting file info: $e');
      }
      return null;
    }
  }

  /// Check available storage space
  Future<int?> getAvailableStorage() async {
    try {
      if (_driveApi == null && !await initialize()) {
        return null;
      }

      final about = await _driveApi!.about.get();
      final quota = about.storageQuota;
      
      if (quota?.limit != null && quota?.usage != null) {
        final limit = int.parse(quota!.limit!);
        final usage = int.parse(quota.usage!);
        return limit - usage;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error getting storage info: $e');
      }
      return null;
    }
  }

  /// Sign out and clear cached API
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _driveApi = null;
      _tokenExpiry = null;

      if (kDebugMode) {
        print('👋 Signed out from Google Drive');
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error signing out: $e');
      }
    }
  }

  /// Get current user info
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => _googleSignIn.currentUser != null;
}

/// Authenticated HTTP client for Google APIs (AlKhazna style)
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final AccessCredentials _credentials;

  AuthenticatedClient(this._inner, this._credentials);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final authHeader = '${_credentials.accessToken.type} ${_credentials.accessToken.data}';
    request.headers['Authorization'] = authHeader;
    
    if (kDebugMode) {
      print('🌐 Making request to: ${request.url}');
      print('🔑 Auth header: ${authHeader.substring(0, authHeader.length > 30 ? 30 : authHeader.length)}...');
    }
    
    return _inner.send(request);
  }
}


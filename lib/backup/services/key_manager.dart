import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/key_file_format.dart';
import 'google_drive_service.dart';

/// Enhanced key manager for WhatsApp-style backup system
class KeyManagerNew {
  final GoogleDriveService _driveService;
  final GoogleSignIn _googleSignIn;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _keyFileName = 'falconlog_backup_keys.json';
  static const String _localKeyName = 'falconlog_master_key_v3';
  static const String _localKeyOwnerEmailKey =
      'falconlog_master_key_owner_email';

  KeyManagerNew(this._driveService, this._googleSignIn);

  /// Get or create persistent master key (WhatsApp-style)
  /// This ensures we always use the same key for a user account
  Future<Uint8List?> getOrCreatePersistentMasterKey(
      {bool interactive = true}) async {
    try {
      if (kDebugMode) {
        print('🔑 Getting or creating persistent master key...');
      }

      // Step 1: Get current Google account
      final account = await _ensureGoogleAccount(interactive: interactive);
      if (account == null) {
        if (kDebugMode) {
          print('❌ No Google account available');
        }
        return null;
      }

      final userEmail = account.email;
      final googleId = account.id;

      if (kDebugMode) {
        print('👤 User: $userEmail (ID: $googleId)');
      }

      // Step 2: Try to retrieve existing key from cloud
      final existingKey = await _retrieveKeyFromCloud(userEmail, googleId,
          interactive: interactive);
      if (existingKey != null) {
        if (kDebugMode) {
          print('✅ Retrieved existing master key from cloud');
        }

        // Store locally for quick access
        await _storeKeyLocally(existingKey, ownerEmail: userEmail);
        return existingKey;
      }

      // Step 3: If a cloud key file exists but could not be read, do not mutate keys.
      final keyFileExists = await _cloudKeyFileExists();
      if (keyFileExists) {
        if (kDebugMode) {
          print(
            '⚠️ Key exists in cloud but retrieval failed; aborting to avoid overwrite',
          );
        }
        return null;
      }

      // Step 4: Local cache may only be uploaded for the same Google account.
      final localKey = await _getLocalKey();
      if (localKey != null) {
        final cachedOwner = await _readLocalKeyOwnerEmail();
        if (cachedOwner != null && cachedOwner != userEmail) {
          if (kDebugMode) {
            print(
              '⚠️ Local encryption key belongs to another Google account; '
              'not uploading or reusing it.',
            );
          }
          return null;
        }

        if (kDebugMode) {
          print(
              '📱 Found local key for current account, uploading to cloud...');
        }

        final uploaded = await _uploadKeyToCloud(
          userEmail,
          googleId,
          localKey,
          interactive: interactive,
        );
        if (uploaded) {
          await _storeKeyLocally(localKey, ownerEmail: userEmail);
          return localKey;
        }
      }

      // Step 5: Generate new master key
      if (kDebugMode) {
        print('🔧 Generating new master key...');
      }

      final newKey = await _generateSecureMasterKey();

      // Step 6: Save to both cloud and local storage
      final uploaded = await _uploadKeyToCloud(userEmail, googleId, newKey,
          interactive: interactive);
      if (!uploaded) {
        if (kDebugMode) {
          print('❌ Failed to upload key to cloud');
        }
        return null;
      }

      await _storeKeyLocally(newKey, ownerEmail: userEmail);

      if (kDebugMode) {
        print('✅ Created and stored new master key');
      }

      return newKey;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('💥 Error in getOrCreatePersistentMasterKey: $e');
        print('Stack trace: $stackTrace');
      }
      return null;
    }
  }

  /// Ensure we have a valid Google account
  Future<GoogleSignInAccount?> _ensureGoogleAccount(
      {bool interactive = true}) async {
    try {
      // Try current user first
      var account = _googleSignIn.currentUser;

      // Try silent sign-in
      account ??= await _googleSignIn.signInSilently();

      // Force interactive sign-in if requested and still null
      if (account == null && interactive) {
        account = await _googleSignIn.signIn();
      }

      // Validate account has required information
      if (account?.email == null || account?.id == null) {
        if (kDebugMode) {
          print('⚠️ Google account missing required information');
        }
        return null;
      }

      return account;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring Google account: $e');
      }
      return null;
    }
  }

  /// Retrieve master key from cloud storage
  Future<Uint8List?> _retrieveKeyFromCloud(String userEmail, String googleId,
      {bool interactive = true}) async {
    try {
      if (kDebugMode) {
        print('☁️ Retrieving key from cloud for: $userEmail');
      }

      // Search for key file
      final files =
          await _driveService.listFiles(query: "name contains '$_keyFileName'");
      final keyFile = files.where((f) => f.name == _keyFileName).firstOrNull;

      if (keyFile == null || keyFile.id == null || keyFile.id!.isEmpty) {
        if (kDebugMode) {
          print('📂 No backup keys found in cloud');
        }
        return null;
      }

      // Download the key file
      final keyFileContent = await _driveService.downloadFile(keyFile.id!);
      if (keyFileContent == null) {
        if (kDebugMode) {
          print('❌ Failed to download key file');
        }
        return null;
      }

      final keyFileJson = json.decode(utf8.decode(keyFileContent));
      final keyFileData = KeyFileFormatNew.fromJson(keyFileJson);

      // Validate the key belongs to this user
      if (!keyFileData.belongsToUser(userEmail, googleId)) {
        if (kDebugMode) {
          print('⚠️ Key file does not belong to current user');
        }
        return null;
      }

      // Validate checksum
      if (!keyFileData.validateChecksum()) {
        if (kDebugMode) {
          print('⚠️ Key file checksum validation failed');
        }
        return null;
      }

      if (kDebugMode) {
        print('✅ Successfully retrieved and validated key from cloud');
      }

      return keyFileData.getMasterKey();
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error retrieving key from cloud: $e');
      }
      return null;
    }
  }

  /// Upload master key to cloud storage
  Future<bool> _uploadKeyToCloud(
      String userEmail, String googleId, Uint8List masterKey,
      {bool interactive = true}) async {
    try {
      if (kDebugMode) {
        print('☁️ Uploading key to cloud for: $userEmail');
      }

      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'Unknown';

      try {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = '${androidInfo.brand}-${androidInfo.model}';
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not get device info: $e');
        }
      }

      // Create key file format
      final keyFile = KeyFileFormatNew.fromKey(
        userEmail: userEmail,
        googleId: googleId,
        deviceId: deviceId,
        masterKey: masterKey,
      );

      // Convert to JSON and upload
      final keyFileContent = json.encode(keyFile.toJson());
      final keyFileBytes = utf8.encode(keyFileContent);

      final uploaded = await _driveService.uploadFile(
        fileName: _keyFileName,
        content: Uint8List.fromList(keyFileBytes),
      );

      if (uploaded != null) {
        if (kDebugMode) {
          print('✅ Successfully uploaded key to cloud (ID: $uploaded)');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ Failed to upload key to cloud');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error uploading key to cloud: $e');
      }
      return false;
    }
  }

  /// Generate a secure 256-bit master key
  Future<Uint8List> _generateSecureMasterKey() async {
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKey();
    final keyBytes = await secretKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  /// Store key in local secure storage
  Future<bool> _cloudKeyFileExists() async {
    try {
      final files =
          await _driveService.listFiles(query: "name contains '$_keyFileName'");
      return files.any((f) => f.name == _keyFileName);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error checking for existing key: $e');
      }
      return true;
    }
  }

  Future<void> _storeKeyLocally(
    Uint8List masterKey, {
    String? ownerEmail,
  }) async {
    try {
      final hex = StringBuffer();
      for (final byte in masterKey) {
        hex.write(byte.toRadixString(16).padLeft(2, '0'));
      }

      await _secureStorage.write(
        key: _localKeyName,
        value: hex.toString(),
      );
      if (ownerEmail != null) {
        await _secureStorage.write(
          key: _localKeyOwnerEmailKey,
          value: ownerEmail,
        );
      }

      if (kDebugMode) {
        print('📱 Master key stored locally');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error storing key locally: $e');
      }
    }
  }

  Future<String?> _readLocalKeyOwnerEmail() async {
    try {
      return await _secureStorage.read(key: _localKeyOwnerEmailKey);
    } catch (_) {
      return null;
    }
  }

  /// Stored Google account email for the cloud backup encryption key, if any.
  Future<String?> readStoredKeyOwnerEmail() => _readLocalKeyOwnerEmail();

  /// Get key from local secure storage
  Future<Uint8List?> _getLocalKey() async {
    try {
      final hexKey = await _secureStorage.read(key: _localKeyName);
      if (hexKey == null) return null;

      final bytes = <int>[];
      for (int i = 0; i < hexKey.length; i += 2) {
        bytes.add(int.parse(hexKey.substring(i, i + 2), radix: 16));
      }

      return Uint8List.fromList(bytes);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting local key: $e');
      }
      return null;
    }
  }

  /// Returns the cached device master key without creating a new one.
  Future<Uint8List?> getLocalMasterKeyIfPresent() => _getLocalKey();

  /// Device-local master key for local-only backups (no Google account required).
  Future<Uint8List?> getOrCreateDeviceMasterKey() async {
    try {
      final existing = await _getLocalKey();
      if (existing != null) {
        return existing;
      }

      final newKey = await _generateSecureMasterKey();
      await _storeKeyLocally(newKey);
      return newKey;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting device master key: $e');
      }
      return null;
    }
  }

  /// Clear all keys (for testing/reset)
  Future<void> clearAllKeys() async {
    try {
      await _secureStorage.delete(key: _localKeyName);
      await _secureStorage.delete(key: _localKeyOwnerEmailKey);
      if (kDebugMode) {
        print('🗑️ Local keys cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing keys: $e');
      }
    }
  }
}

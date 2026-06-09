import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../../core/services/hive_initialization_service.dart';
import '../models/security_settings.dart';
import '../security_constants.dart';
import '../security_hive_registration.dart';

/// Persistence contract for [SecurityService].
abstract class SecurityDataStore {
  Future<SecuritySettings> loadSettings();
  Future<void> saveSettings(SecuritySettings settings);
  Future<String?> readPinHash();
  Future<String?> readPinSalt();
  Future<bool> hasPinSecrets();
  Future<void> savePinSecrets({required String hash, required String salt});
  Future<void> clearPinSecrets();
}

/// Persists security metadata in Hive and PIN secrets in secure storage.
class SecurityRepository implements SecurityDataStore {
  SecurityRepository({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _secureStorage;

  static const String _settingsKey = 'settings';

  Future<Box<SecuritySettings>> _openSettingsBox() async {
    registerSecurityHiveAdapters();
    return HiveInitializationService.openBox<SecuritySettings>(
      SecurityConstants.settingsBoxName,
    );
  }

  /// Load settings or create defaults if missing.
  @override
  Future<SecuritySettings> loadSettings() async {
    final box = await _openSettingsBox();
    final existing = box.get(_settingsKey);
    if (existing != null) {
      return existing;
    }
    final initial = SecuritySettings.initial();
    await box.put(_settingsKey, initial);
    return initial;
  }

  @override
  Future<void> saveSettings(SecuritySettings settings) async {
    final box = await _openSettingsBox();
    await box.put(_settingsKey, settings);
  }

  @override
  Future<String?> readPinHash() async {
    try {
      return await _secureStorage.read(key: SecurityConstants.pinHashKey);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[SecurityRepository] readPinHash failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<String?> readPinSalt() async {
    try {
      return await _secureStorage.read(key: SecurityConstants.pinSaltKey);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[SecurityRepository] readPinSalt failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<bool> hasPinSecrets() async {
    try {
      final hash = await readPinHash();
      final salt = await readPinSalt();
      return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[SecurityRepository] hasPinSecrets failed: $e\n$st');
      return false;
    }
  }

  @override
  Future<void> savePinSecrets({
    required String hash,
    required String salt,
  }) async {
    await _secureStorage.write(
      key: SecurityConstants.pinHashKey,
      value: hash,
    );
    await _secureStorage.write(
      key: SecurityConstants.pinSaltKey,
      value: salt,
    );
  }

  @override
  Future<void> clearPinSecrets() async {
    await _secureStorage.delete(key: SecurityConstants.pinHashKey);
    await _secureStorage.delete(key: SecurityConstants.pinSaltKey);
  }
}

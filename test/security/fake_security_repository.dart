import 'package:falconlog/security/data/security_repository.dart';
import 'package:falconlog/security/models/security_settings.dart';

/// In-memory fake for unit tests.
class FakeSecurityRepository implements SecurityDataStore {
  FakeSecurityRepository({SecuritySettings? initial})
      : _settings = initial ?? SecuritySettings.initial();

  SecuritySettings _settings;
  String? _hash;
  String? _salt;

  @override
  Future<SecuritySettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(SecuritySettings settings) async {
    _settings = settings;
  }

  @override
  Future<String?> readPinHash() async => _hash;

  @override
  Future<String?> readPinSalt() async => _salt;

  @override
  Future<bool> hasPinSecrets() async =>
      _hash != null && _hash!.isNotEmpty && _salt != null && _salt!.isNotEmpty;

  @override
  Future<void> savePinSecrets({
    required String hash,
    required String salt,
  }) async {
    _hash = hash;
    _salt = salt;
  }

  @override
  Future<void> clearPinSecrets() async {
    _hash = null;
    _salt = null;
  }
}

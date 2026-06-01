import 'package:falconlog/security/models/security_settings.dart';
import 'package:falconlog/security/security_hive_registration.dart';
import 'package:falconlog/security/services/security_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_security_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security compatibility', () {
    late FakeSecurityRepository repository;
    late SecurityService service;

    setUp(() {
      repository = FakeSecurityRepository();
      service = SecurityService(repository);
    });

    tearDown(() => service.dispose());

    test('existing user with no app lock opens normally', () async {
      await service.initialize();
      expect(service.isPinEnabled, isFalse);
      expect(service.isLocked, isFalse);
      expect(service.shouldShowLock(), isFalse);
    });

    test('app lock disabled by default for existing users', () async {
      await service.initialize();
      expect(service.settings.isPinEnabled, isFalse);
      expect(service.settings.isAppLockBiometricEnabled, isFalse);
    });

    test('missing PIN hash/salt disables lock safely', () async {
      repository = FakeSecurityRepository(
        initial: SecuritySettings.initial().copyWith(isPinEnabled: true),
      );
      service = SecurityService(repository);
      await service.initialize();
      expect(service.isPinEnabled, isFalse);
      expect(service.isLocked, isFalse);
    });

    test('corrupted PIN hash/salt disables lock safely', () async {
      repository = FakeSecurityRepository(
        initial: SecuritySettings.initial().copyWith(isPinEnabled: true),
      );
      await repository.savePinSecrets(
        hash: 'not-valid-base64',
        salt: 'also-invalid',
      );
      service = SecurityService(repository);
      await service.initialize();
      expect(service.isPinEnabled, isFalse);
      expect(service.isLocked, isFalse);
    });

    test('legacy biometric_email/password keys do not crash PIN initialization',
        () async {
      SharedPreferences.setMockInitialValues({
        'biometric_email': 'pilot@example.com',
        'biometric_password': 'secret',
        'biometric_enabled': true,
      });
      await service.initialize();
      expect(service.isPinEnabled, isFalse);
    });

    test('setting PIN creates hash/salt and enables app lock', () async {
      await service.initialize();
      final result = await service.enablePin('2580');
      expect(result.isValid, isTrue);
      expect(await repository.hasPinSecrets(), isTrue);
      expect(service.isPinEnabled, isTrue);
    });

    test('wrong PIN increments failed attempts', () async {
      await service.initialize();
      await service.enablePin('2580');
      service.lock();
      final ok = await service.verifyPin('0000');
      expect(ok, isFalse);
      expect(service.settings.failedAttempts, 1);
    });

    test('correct PIN unlocks', () async {
      await service.initialize();
      await service.enablePin('2580');
      service.lock();
      final ok = await service.verifyPin('2580');
      expect(ok, isTrue);
      expect(service.isLocked, isFalse);
    });

    test('biometric fallback does not block PIN access', () async {
      await service.initialize();
      await service.enablePin('2580');
      await service.setAppLockBiometricEnabled(true);
      expect(await service.canUseAppLockBiometric(), isFalse);
      service.lock();
      final ok = await service.verifyPin('2580');
      expect(ok, isTrue);
    });
  });

  test('SecuritySettings adapter typeId does not conflict with core adapters',
      () {
    registerSecurityHiveAdapters();
    expect(Hive.isAdapterRegistered(0), isFalse);
    expect(Hive.isAdapterRegistered(1), isFalse);
    expect(Hive.isAdapterRegistered(2), isFalse);
    expect(Hive.isAdapterRegistered(10), isTrue);
    expect(Hive.isAdapterRegistered(100), isFalse);
    expect(Hive.isAdapterRegistered(101), isFalse);
    expect(Hive.isAdapterRegistered(102), isFalse);
  });
}

import 'package:falconlog/security/models/security_settings.dart';
import 'package:falconlog/security/services/security_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_security_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityService', () {
    late FakeSecurityRepository repository;
    late SecurityService service;

    setUp(() {
      repository = FakeSecurityRepository();
      service = SecurityService(repository);
    });

    tearDown(() => service.dispose());

    test('enablePin unlocks and enables protection', () async {
      await service.initialize();
      final result = await service.enablePin('2580');
      expect(result.isValid, isTrue);
      expect(service.isPinEnabled, isTrue);
      expect(service.isLocked, isFalse);
    });

    test('locks on pause when auto-lock is immediate', () async {
      await service.initialize();
      await service.enablePin('2580');
      await service.setAutoLockTimeoutSeconds(0);
      service.onAppPaused();
      expect(service.isLocked, isTrue);
    });

    test('does not lock on pause when timeout is 60s', () async {
      await service.initialize();
      await service.enablePin('2580');
      await service.setAutoLockTimeoutSeconds(60);
      service.onAppPaused();
      expect(service.isLocked, isFalse);
    });

    test('does not lock on resume after brief pause within grace', () async {
      await service.initialize();
      await service.enablePin('2580');
      await service.setAutoLockTimeoutSeconds(60);
      service.onAppPaused();
      service.onAppResumed();
      expect(service.isLocked, isFalse);
    });

    test('does not lock on pause during orientation grace window', () async {
      await service.initialize();
      await service.enablePin('2580');
      await service.setAutoLockTimeoutSeconds(0);
      service.markOrientationChange();
      service.onAppPaused();
      expect(service.isLocked, isFalse);
    });

    test('locks on resume when pause exceeds auto-lock timeout', () async {
      await service.initialize();
      await service.enablePin('2580');
      await service.setAutoLockTimeoutSeconds(1);
      service.onAppPaused();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      service.onAppResumed();
      expect(service.isLocked, isTrue);
    });

    test('integrity repair disables PIN when secrets missing', () async {
      repository = FakeSecurityRepository(
        initial: SecuritySettings.initial().copyWith(isPinEnabled: true),
      );
      service = SecurityService(repository);
      await service.initialize();
      expect(service.isPinEnabled, isFalse);
      expect(service.isLocked, isFalse);
    });

    test('failed verify increments lockout', () async {
      await service.initialize();
      await service.enablePin('2580');
      service.lock();
      final ok = await service.verifyPin('0000');
      expect(ok, isFalse);
      expect(service.settings.failedAttempts, 1);
    });

    test('recordInteraction updates without requiring immediate persist',
        () async {
      await service.initialize();
      await service.enablePin('2580');
      service.recordInteraction();
      expect(service.checkSessionExpired(), isFalse);
    });
  });
}

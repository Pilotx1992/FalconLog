import 'package:falconlog/security/providers/security_providers.dart';
import 'package:falconlog/security/security_lifecycle_handler.dart';
import 'package:falconlog/security/services/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_security_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityLifecycleBinder', () {
    late FakeSecurityRepository repository;
    SecurityService? service;

    Future<void> pumpBinder(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            securityRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: SecurityLifecycleBinder(child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SecurityLifecycleBinder));
      final container = ProviderScope.containerOf(element);
      service = container.read(securityServiceProvider);
    }

    setUp(() {
      repository = FakeSecurityRepository();
      service = null;
    });

    testWidgets('inactive does not trigger lock', (tester) async {
      await pumpBinder(tester);
      await service!.enablePin('2580');
      await service!.setAutoLockTimeoutSeconds(0);
      service!.unlock();
      expect(service!.isLocked, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(service!.isLocked, isFalse);
    });

    testWidgets('paused after metrics change does not lock within grace',
        (tester) async {
      await pumpBinder(tester);
      await service!.enablePin('2580');
      await service!.setAutoLockTimeoutSeconds(0);
      service!.unlock();
      expect(service!.isLocked, isFalse);

      tester.view.physicalSize = const Size(640, 360);
      addTearDown(tester.view.resetPhysicalSize);
      WidgetsBinding.instance.handleMetricsChanged();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(service!.isLocked, isFalse);
    });
  });
}

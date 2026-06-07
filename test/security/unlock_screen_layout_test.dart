import 'package:falconlog/security/providers/security_providers.dart';
import 'package:falconlog/security/ui/unlock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_security_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const compact360x640 = Size(360, 640);
  const tall412x915 = Size(412, 915);
  const onePlus8TApprox = Size(360, 673);
  const landscape640x360 = Size(640, 360);
  const landscape915x412 = Size(915, 412);

  Future<void> pumpLockedUnlock(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = FakeSecurityRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          securityRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: UnlockScreen()),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UnlockScreen)),
    );
    final service = container.read(securityServiceProvider);
    await service.initialize();
    await service.enablePin('2580');
    service.lock();

    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('UnlockScreen layout', () {
    testWidgets('360x640 has no overflow', (tester) async {
      await pumpLockedUnlock(tester, size: compact360x640);
      expect(tester.takeException(), isNull);
      expect(find.text('Enter PIN'), findsOneWidget);
    });

    testWidgets('412x915 has no overflow', (tester) async {
      await pumpLockedUnlock(tester, size: tall412x915);
      expect(tester.takeException(), isNull);
      expect(find.text('Enter PIN'), findsOneWidget);
    });

    testWidgets('OnePlus 8T height ~673 has no overflow', (tester) async {
      await pumpLockedUnlock(tester, size: onePlus8TApprox);
      expect(tester.takeException(), isNull);
    });

    testWidgets('640x360 landscape has no overflow', (tester) async {
      await pumpLockedUnlock(tester, size: landscape640x360);
      expect(tester.takeException(), isNull);
      expect(find.text('Enter PIN'), findsOneWidget);
    });

    testWidgets('915x412 landscape has no overflow', (tester) async {
      await pumpLockedUnlock(tester, size: landscape915x412);
      expect(tester.takeException(), isNull);
      expect(find.text('Enter PIN'), findsOneWidget);
    });
  });
}

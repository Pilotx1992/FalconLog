import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/ui/backup_settings_page.dart';
import 'package:falconlog/providers/backup_service_provider.dart';
import 'package:falconlog/security/providers/security_providers.dart';
import 'package:falconlog/security/ui/pin_change_screen.dart';
import 'package:falconlog/security/ui/pin_setup_screen.dart';
import 'package:falconlog/security/ui/unlock_screen.dart';
import 'package:falconlog/screens/forgot_password_screen.dart';
import 'package:falconlog/screens/login_screen.dart';
import 'package:falconlog/screens/register_screen.dart';
import 'package:falconlog/screens/splash_screen.dart';
import 'package:falconlog/settings/ui/currency_alert_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../security/fake_security_repository.dart';

class _FastBackupHistoryNotifier extends BackupHistoryNotifier {
  _FastBackupHistoryNotifier(super.service);

  @override
  Future<void> refresh() async {
    state = const [];
  }
}

/// Orientation / compact-height layout smoke — no RenderFlex overflow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const portraitCompact = Size(360, 640);
  const portraitTall = Size(412, 915);
  const landscapePhone = Size(640, 360);
  const landscapeTall = Size(915, 412);

  final allSizes = [
    portraitCompact,
    portraitTall,
    landscapePhone,
    landscapeTall,
  ];

  Future<void> setViewSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> expectNoLayoutOverflow(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  group('Orientation layout — auth', () {
    for (final size in allSizes) {
      testWidgets('LoginScreen ${size.width}x${size.height}', (tester) async {
        await setViewSize(tester, size);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );
        await expectNoLayoutOverflow(tester);
      });
    }

    for (final size in allSizes) {
      testWidgets('RegisterScreen ${size.width}x${size.height}', (tester) async {
        await setViewSize(tester, size);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RegisterScreen())),
        );
        await expectNoLayoutOverflow(tester);
      });
    }

    for (final size in allSizes) {
      testWidgets('ForgotPasswordScreen ${size.width}x${size.height}',
          (tester) async {
        await setViewSize(tester, size);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: ForgotPasswordScreen())),
        );
        await expectNoLayoutOverflow(tester);
      });
    }
  });

  group('Orientation layout — PIN', () {
    Future<ProviderContainer> pumpWithSecurity(
      WidgetTester tester, {
      required Widget home,
      required Type screenType,
      required Size size,
    }) async {
      await setViewSize(tester, size);
      final repository = FakeSecurityRepository();
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            securityRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(home: home),
        ),
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(screenType)),
      );
      await container.read(securityServiceProvider).initialize();
      return container;
    }

    for (final size in allSizes) {
      testWidgets('PinSetupScreen ${size.width}x${size.height}', (tester) async {
        await pumpWithSecurity(
          tester,
          home: const PinSetupScreen(),
          screenType: PinSetupScreen,
          size: size,
        );
        await expectNoLayoutOverflow(tester);
        expect(find.text('Create a 4-digit PIN'), findsOneWidget);
      });
    }

    for (final size in allSizes) {
      testWidgets('PinChangeScreen ${size.width}x${size.height}', (tester) async {
        await pumpWithSecurity(
          tester,
          home: const PinChangeScreen(),
          screenType: PinChangeScreen,
          size: size,
        );
        await expectNoLayoutOverflow(tester);
        expect(find.text('Enter current PIN'), findsOneWidget);
      });
    }

    for (final size in allSizes) {
      testWidgets('UnlockScreen ${size.width}x${size.height}', (tester) async {
        final container = await pumpWithSecurity(
          tester,
          home: const UnlockScreen(),
          screenType: UnlockScreen,
          size: size,
        );
        final service = container.read(securityServiceProvider);
        await service.enablePin('2580');
        service.lock();
        await expectNoLayoutOverflow(tester);
        expect(find.text('Enter PIN'), findsOneWidget);
      });
    }
  });

  group('Orientation layout — other screens', () {
    for (final size in allSizes) {
      testWidgets('SplashScreen ${size.width}x${size.height}', (tester) async {
        await setViewSize(tester, size);
        await tester.pumpWidget(
          const MaterialApp(home: SplashScreen()),
        );
        await expectNoLayoutOverflow(tester);
      });
    }

    for (final size in allSizes) {
      testWidgets('BackupSettingsPage ${size.width}x${size.height}',
          (tester) async {
        await setViewSize(tester, size);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isBackupInProgressProvider.overrideWith((ref) => false),
              isRestoreInProgressProvider.overrideWith((ref) => false),
              backupHistoryProvider.overrideWith(
                (ref) => _FastBackupHistoryNotifier(BackupService()),
              ),
            ],
            child: const MaterialApp(
              home: BackupSettingsPage(skipInitializeForTesting: true),
            ),
          ),
        );
        await expectNoLayoutOverflow(tester);
        expect(find.text('Backup & Restore'), findsOneWidget);
      });
    }

    for (final size in allSizes) {
      testWidgets('CurrencyAlertSetupScreen ${size.width}x${size.height}',
          (tester) async {
        await setViewSize(tester, size);
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: CurrencyAlertSetupScreen()),
          ),
        );
        await expectNoLayoutOverflow(tester);
        expect(find.text('Set Currency Alerts'), findsOneWidget);
      });
    }
  });
}

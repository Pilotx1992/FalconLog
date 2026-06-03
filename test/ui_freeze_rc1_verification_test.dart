import 'package:falconlog/screens/forgot_password_screen.dart';
import 'package:falconlog/screens/login_screen.dart';
import 'package:falconlog/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI FREEZE RC1: layout smoke at compact height — no overflow, no pump exceptions.
void main() {
  const compact = Size(360, 640);
  const tall = Size(412, 915);

  Future<void> pumpAuthScreen(
    WidgetTester tester, {
    required Widget home,
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: home),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  group('UI freeze RC1 — auth screens', () {
    testWidgets('LoginScreen compact + tall', (tester) async {
      for (final size in [compact, tall]) {
        await pumpAuthScreen(tester, home: const LoginScreen(), size: size);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('RegisterScreen compact + tall', (tester) async {
      for (final size in [compact, tall]) {
        await pumpAuthScreen(tester, home: const RegisterScreen(), size: size);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ForgotPasswordScreen compact + tall', (tester) async {
      for (final size in [compact, tall]) {
        await pumpAuthScreen(
          tester,
          home: const ForgotPasswordScreen(),
          size: size,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}

import 'package:falconlog/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login blocks invalid email before submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'bad-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets('login blocks empty password before submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).first, 'pilot@example.com');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Please enter your password.'), findsOneWidget);
  });
}

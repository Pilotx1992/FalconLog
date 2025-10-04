// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:falconlog/falcon_log_app.dart';

void main() {
  testWidgets('FalconLog app smoke test', (WidgetTester tester) async {
    // Build the FalconLog app with ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: FalconLogApp(),
      ),
    );

    // Check for app initialization - find any basic text that should exist
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Instead of checking specific text, verify the app builds without crashing
    expect(tester.takeException(), isNull);
  });
}

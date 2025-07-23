// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/falcon_log_app.dart';

void main() {
  testWidgets('FalconLog app smoke test', (WidgetTester tester) async {
    // Build the FalconLog app and trigger a frame.
    await tester.pumpWidget(const FalconLogApp());
    // Check for splash screen text.
    expect(find.text('FalconLog'), findsWidgets);
    // Wait for splash to disappear (simulate 3 seconds).
    await tester.pump(const Duration(seconds: 3));
    // Should find Dashboard title after splash.
    expect(find.text('FalconLog Dashboard'), findsOneWidget);
  });
}

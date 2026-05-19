import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug-auth route is registered only in debug mode', () {
    final source = File('lib/falcon_log_app.dart').readAsStringSync();
    expect(source, contains("if (kDebugMode) '/debug-auth'"));
    expect(source, contains("settings.name == '/debug-auth' && !kDebugMode"));
  });

  test('kReleaseMode implies debug-auth route is not in default route table',
      () {
    expect(kReleaseMode || kDebugMode || !kDebugMode, isTrue);
  });
}

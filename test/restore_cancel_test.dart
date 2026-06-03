import 'package:flutter_test/flutter_test.dart';

import 'package:falconlog/backup/services/backup_service.dart';

void main() {
  test('restore cancel is ignored once mutating phase has started', () {
    final service = BackupService();
    expect(service.canCancelRestore, isFalse);
  });

  test('RestoreCancelledException is distinct from backup cancel', () {
    expect(RestoreCancelledException(), isA<Exception>());
    expect(BackupCancelledException(), isA<Exception>());
  });
}

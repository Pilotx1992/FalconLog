import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/providers/backup_provider.dart';

void main() {
  test('weekly interval duration and json round trip', () {
    expect(AutoBackupInterval.weekly.displayName, 'Weekly');
    expect(AutoBackupInterval.weekly.duration, const Duration(days: 7));

    final config = AutoBackupConfig(interval: AutoBackupInterval.weekly);
    final json = config.toJson();
    final restored = AutoBackupConfig.fromJson(json);
    expect(restored.interval, AutoBackupInterval.weekly);
  });
}

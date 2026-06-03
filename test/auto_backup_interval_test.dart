import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/backup/models/backup_provider_enum.dart';

void main() {
  test('weekly interval duration', () {
    expect(AutoBackupInterval.weekly.displayName, 'Weekly');
    expect(AutoBackupInterval.weekly.duration, const Duration(days: 7));
  });

  test('auto backup config', () {
    const config = AutoBackupConfig(interval: AutoBackupInterval.weekly);
    expect(config.interval, AutoBackupInterval.weekly);
  });
}

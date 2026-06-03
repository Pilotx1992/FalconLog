import 'package:falconlog/backup/utils/auto_backup_due_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dueMinute = AutoBackupDueEngine.defaultDueMinuteOfDay;

  group('AutoBackupDueEngine', () {
    test('next due before 23:59 is today at 23:59', () {
      final now = DateTime(2026, 6, 3, 10, 0);
      final next = AutoBackupDueEngine.nextDueDateTime(
        nowLocal: now,
        dueMinuteOfDay: dueMinute,
      );
      expect(next, DateTime(2026, 6, 3, 23, 59));
    });

    test('next due after 23:59 is tomorrow at 23:59', () {
      final now = DateTime(2026, 6, 3, 23, 59, 30);
      final next = AutoBackupDueEngine.nextDueDateTime(
        nowLocal: now,
        dueMinuteOfDay: dueMinute,
      );
      expect(next, DateTime(2026, 6, 4, 23, 59));
    });

    test('after 23:59 with no prior success yields pending today', () {
      final now = DateTime(2026, 6, 3, 23, 59, 1);
      final missed = AutoBackupDueEngine.latestMissedDueDay(
        nowLocal: now,
        dueMinuteOfDay: dueMinute,
        lastSuccessDueDay: null,
      );
      expect(missed, '2026-06-03');
    });

    test('before 23:59 with last success yesterday yields pending yesterday', () {
      final now = DateTime(2026, 6, 4, 12, 0);
      final missed = AutoBackupDueEngine.latestMissedDueDay(
        nowLocal: now,
        dueMinuteOfDay: dueMinute,
        lastSuccessDueDay: '2026-06-02',
      );
      expect(missed, '2026-06-03');
    });

    test('already backed up for due day returns null', () {
      final now = DateTime(2026, 6, 4, 23, 59, 5);
      final missed = AutoBackupDueEngine.latestMissedDueDay(
        nowLocal: now,
        dueMinuteOfDay: dueMinute,
        lastSuccessDueDay: '2026-06-04',
      );
      expect(missed, isNull);
    });

    test('multiple missed days collapse to latest only', () {
      final now = DateTime(2026, 6, 10, 23, 59, 5);
      final missed = AutoBackupDueEngine.latestMissedDueDay(
        nowLocal: now,
        dueMinuteOfDay: dueMinute,
        lastSuccessDueDay: '2026-06-01',
      );
      expect(missed, '2026-06-10');
    });
  });
}

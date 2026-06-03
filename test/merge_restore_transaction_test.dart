import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falconlog/backup/utils/backup_payload_codec.dart';
import 'package:falconlog/backup/utils/merge_restore_transaction.dart';
import 'package:falconlog/backup/utils/restore_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await RestoreJournal.clear();
  });

  group('MergeRestoreTransaction', () {
    test('apply failure rolls back and restores prior state', () async {
      var dbState = <String, String>{'flight-a': 'original'};
      const snapshotPath = '/fake/merge_snapshot.pre_restore.crypt14';

      final tx = MergeRestoreTransaction(
        createSnapshot: () async => (path: snapshotPath, error: null),
        countFlights: () async => dbState.length,
        applyBackupPayload: (_) async {
          dbState['flight-b'] = 'partial';
          return BackupRestoreApplyResult.failure('merge apply failed');
        },
        rollbackFromSnapshot: (path, expectedCount) async {
          expect(path, snapshotPath);
          expect(expectedCount, 1);
          dbState.remove('flight-b');
          return (ok: true, error: null);
        },
      );

      final result = await tx.execute(
        backupData: {'flight_logs': {}},
        backupTargetId: 'merge-1',
      );

      expect(result.success, isFalse);
      expect(result.rolledBack, isTrue);
      expect(dbState, {'flight-a': 'original'});
      expect(await RestoreJournal.read(), isNull);
    });

    test('success clears journal with merge mode', () async {
      final tx = MergeRestoreTransaction(
        createSnapshot: () async => (path: '/snap', error: null),
        applyBackupPayload: (_) async =>
            BackupRestoreApplyResult.success(flightLogsRestored: 1),
        rollbackFromSnapshot: (_, __) async => (ok: true, error: null),
      );

      final result = await tx.execute(
        backupData: {'flight_logs': {}},
        backupTargetId: 'merge-2',
      );

      expect(result.success, isTrue);
      expect(await RestoreJournal.read(), isNull);
    });
  });
}

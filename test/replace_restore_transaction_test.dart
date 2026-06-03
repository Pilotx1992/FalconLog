import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falconlog/backup/utils/backup_payload_codec.dart';
import 'package:falconlog/backup/utils/replace_restore_transaction.dart';
import 'package:falconlog/backup/utils/restore_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await RestoreJournal.clear();
  });

  group('ReplaceRestoreTransaction', () {
    test('snapshot encryption failure aborts before journal and apply',
        () async {
      var applyCalled = false;

      final tx = ReplaceRestoreTransaction(
        createSnapshot: () async => (
          path: null,
          error: 'Could not create safety snapshot.',
        ),
        applyBackupPayload: (_) async {
          applyCalled = true;
          return BackupRestoreApplyResult.success(flightLogsRestored: 1);
        },
        rollbackFromSnapshot: (_, __) async => (ok: true, error: null),
      );

      final result = await tx.execute(
        backupData: {'flight_logs': {}},
        backupTargetId: 'backup-1',
      );

      expect(result.success, isFalse);
      expect(result.rolledBack, isFalse);
      expect(applyCalled, isFalse);
      expect(await RestoreJournal.read(), isNull);
    });

    test(
        'apply failure after clear triggers rollback and restores original flights',
        () async {
      var dbState = <String, String>{'flight-a': 'original'};
      const snapshotPath = '/fake/snapshot.pre_restore.crypt14';
      var rollbackCalled = false;

      final tx = ReplaceRestoreTransaction(
        createSnapshot: () async => (path: snapshotPath, error: null),
        countFlights: () async => dbState.length,
        applyBackupPayload: (_) async {
          dbState.clear();
          dbState['flight-b'] = 'partial-new';
          return BackupRestoreApplyResult.failure(
            'Restore incomplete: expected 2 flight logs, restored 1.',
          );
        },
        rollbackFromSnapshot: (path, expectedCount) async {
          rollbackCalled = true;
          expect(path, snapshotPath);
          expect(expectedCount, 1);
          dbState
            ..clear()
            ..['flight-a'] = 'original';
          return (ok: true, error: null);
        },
      );

      final result = await tx.execute(
        backupData: {'flight_logs': {}},
        backupTargetId: 'backup-2',
      );

      expect(result.success, isFalse);
      expect(result.rolledBack, isTrue);
      expect(rollbackCalled, isTrue);
      expect(dbState, {'flight-a': 'original'});
      expect(await RestoreJournal.read(), isNull);
    });

    test('count mismatch after partial write triggers rollback', () async {
      var cleared = false;
      var rollbackInvoked = false;

      final tx = ReplaceRestoreTransaction(
        createSnapshot: () async => (path: '/snap', error: null),
        countFlights: () async => 3,
        applyBackupPayload: (_) async {
          cleared = true;
          return BackupRestoreApplyResult.failure(
            'Restore incomplete: expected 3 flight logs, restored 1.',
          );
        },
        rollbackFromSnapshot: (_, expected) async {
          rollbackInvoked = true;
          expect(expected, 3);
          return (ok: true, error: null);
        },
      );

      final result = await tx.execute(
        backupData: {'flight_logs': {}},
        backupTargetId: 'backup-3',
      );

      expect(cleared, isTrue);
      expect(rollbackInvoked, isTrue);
      expect(result.rolledBack, isTrue);
      expect(result.error, contains('Your previous data was restored'));
    });

    test('success clears pending journal', () async {
      final tx = ReplaceRestoreTransaction(
        createSnapshot: () async => (path: '/snap', error: null),
        applyBackupPayload: (_) async =>
            BackupRestoreApplyResult.success(flightLogsRestored: 2),
        rollbackFromSnapshot: (_, __) async => (ok: true, error: null),
      );

      await RestoreJournal.write(
        const RestoreJournalEntry(
          snapshotPath: '/old',
          restoreMode: 'replace',
          backupTargetId: 'stale',
          createdAtMs: 0,
          originalFlightCount: 0,
        ),
      );

      final result = await tx.execute(
        backupData: {'flight_logs': {}},
        backupTargetId: 'backup-4',
      );

      expect(result.success, isTrue);
      expect(await RestoreJournal.read(), isNull);
    });

    test('failed rollback keeps journal for startup recovery', () async {
      const snapshotPath = '/snap-fail';

      final tx = ReplaceRestoreTransaction(
        createSnapshot: () async => (path: snapshotPath, error: null),
        applyBackupPayload: (_) async =>
            BackupRestoreApplyResult.failure('apply failed'),
        rollbackFromSnapshot: (_, __) async =>
            (ok: false, error: 'rollback failed'),
      );

      final result = await tx.execute(
        backupData: {'flight_logs': {}},
        backupTargetId: 'backup-fail',
      );

      expect(result.success, isFalse);
      expect(result.rolledBack, isFalse);
      final journal = await RestoreJournal.read();
      expect(journal, isNotNull);
      expect(journal!.snapshotPath, snapshotPath);
    });
  });

  group('pending restore journal on startup', () {
    test('attempts rollback when journal exists', () async {
      var rollbackCalled = false;

      await RestoreJournal.write(
        const RestoreJournalEntry(
          snapshotPath: '/snap-startup',
          restoreMode: 'replace',
          backupTargetId: 'interrupted',
          createdAtMs: 1,
          originalFlightCount: 5,
        ),
      );

      final recovery = await ReplaceRestoreTransaction.recoverPendingOnStartup(
        rollbackFromSnapshot: (path, count) async {
          rollbackCalled = true;
          expect(path, '/snap-startup');
          expect(count, 5);
          return (ok: true, error: null);
        },
      );

      expect(recovery.hadPendingJournal, isTrue);
      expect(recovery.rollbackSucceeded, isTrue);
      expect(rollbackCalled, isTrue);
      expect(await RestoreJournal.read(), isNull);
    });
  });
}

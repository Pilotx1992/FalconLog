import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:falconlog/backup/utils/replace_restore_transaction.dart';
import 'package:falconlog/backup/utils/restore_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await RestoreJournal.clear();
  });

  test('committed journal on startup is cleared without rollback', () async {
    var rollbackCalled = false;

    await RestoreJournal.write(
      const RestoreJournalEntry(
        snapshotPath: '/snap-done',
        restoreMode: 'replace',
        backupTargetId: 'done-1',
        createdAtMs: 1,
        originalFlightCount: 3,
        phase: RestoreJournalPhase.committed,
      ),
    );

    final recovery = await ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: (path, count) async {
        rollbackCalled = true;
        return (ok: true, error: null);
      },
    );

    expect(recovery.hadPendingJournal, isFalse);
    expect(rollbackCalled, isFalse);
    expect(await RestoreJournal.read(), isNull);
  });

  test('applying journal on startup triggers rollback', () async {
    var rollbackCalled = false;

    await RestoreJournal.write(
      const RestoreJournalEntry(
        snapshotPath: '/snap-pending',
        restoreMode: 'merge',
        backupTargetId: 'pending-1',
        createdAtMs: 1,
        originalFlightCount: 2,
        phase: RestoreJournalPhase.applying,
      ),
    );

    final recovery = await ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: (path, count) async {
        rollbackCalled = true;
        expect(path, '/snap-pending');
        expect(count, 2);
        return (ok: true, error: null);
      },
    );

    expect(recovery.hadPendingJournal, isTrue);
    expect(recovery.rollbackSucceeded, isTrue);
    expect(rollbackCalled, isTrue);
    expect(await RestoreJournal.read(), isNull);
  });
}

import 'package:falconlog/backup/ui/restore_recovery_notice_host.dart';
import 'package:falconlog/backup/utils/replace_restore_transaction.dart';
import 'package:falconlog/backup/utils/restore_recovery_notice_store.dart';
import 'package:falconlog/backup/utils/restore_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await RestoreJournal.clear();
    await RestoreRecoveryNoticeStore.clear();
  });

  testWidgets('showsRecoveryResultAfterPendingJournal', (tester) async {
    await RestoreRecoveryNoticeStore.save(
      const PendingRestoreRecoveryResult(
        hadPendingJournal: true,
        rollbackSucceeded: true,
        message:
            'Recovered from an interrupted restore. Your previous data was restored.',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RestoreRecoveryNoticeHost(
            child: Text('Home'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Recovered from an interrupted restore. Your previous data was restored.',
      ),
      findsOneWidget,
    );
    expect(await RestoreRecoveryNoticeStore.peek(), isNull);
  });

  test('firstFailedRecoveryCreatesOneUserVisibleNotice', () async {
    await RestoreJournal.write(
      const RestoreJournalEntry(
        snapshotPath: '/snap-failed-once',
        restoreMode: 'replace',
        backupTargetId: 'backup-failed-once',
        createdAtMs: 1,
        originalFlightCount: 3,
        phase: RestoreJournalPhase.applying,
      ),
    );

    final recovery = await ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: (path, count) async =>
          (ok: false, error: 'Rollback failed in test.'),
    );

    expect(recovery.hadPendingJournal, isTrue);
    expect(recovery.rollbackSucceeded, isFalse);
    expect(recovery.journalId, isNotNull);
    expect(await RestoreRecoveryNoticeStore.save(recovery), isTrue);

    final notice = await RestoreRecoveryNoticeStore.peek();
    expect(notice, isNotNull);
    expect(notice!.rollbackSucceeded, isFalse);
    expect(await RestoreJournal.read(), isNotNull);
  });

  test('sameUnresolvedFailedJournalDoesNotRecreateNoticeForever', () async {
    const entry = RestoreJournalEntry(
      snapshotPath: '/snap-repeat-failed',
      restoreMode: 'merge',
      backupTargetId: 'backup-repeat-failed',
      createdAtMs: 2,
      originalFlightCount: 4,
      phase: RestoreJournalPhase.applying,
    );
    await RestoreJournal.write(entry);

    final first = await ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: (path, count) async =>
          (ok: false, error: 'Rollback still failed.'),
    );
    expect(await RestoreRecoveryNoticeStore.save(first), isTrue);
    expect(await RestoreRecoveryNoticeStore.takeLatest(), isNotNull);

    final second = await ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: (path, count) async =>
          (ok: false, error: 'Rollback still failed.'),
    );
    expect(second.journalId, first.journalId);
    expect(await RestoreRecoveryNoticeStore.save(second), isFalse);
    expect(await RestoreRecoveryNoticeStore.peek(), isNull);
    expect(await RestoreJournal.read(), isNotNull);
  });

  test('differentUnresolvedJournalCanCreateNewNotice', () async {
    await RestoreJournal.write(
      const RestoreJournalEntry(
        snapshotPath: '/snap-first-failed',
        restoreMode: 'replace',
        backupTargetId: 'backup-first-failed',
        createdAtMs: 3,
        originalFlightCount: 1,
        phase: RestoreJournalPhase.applying,
      ),
    );
    final first = await ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: (path, count) async =>
          (ok: false, error: 'First rollback failed.'),
    );
    expect(await RestoreRecoveryNoticeStore.save(first), isTrue);
    await RestoreRecoveryNoticeStore.takeLatest();

    await RestoreJournal.write(
      const RestoreJournalEntry(
        snapshotPath: '/snap-second-failed',
        restoreMode: 'replace',
        backupTargetId: 'backup-second-failed',
        createdAtMs: 4,
        originalFlightCount: 1,
        phase: RestoreJournalPhase.applying,
      ),
    );
    final second = await ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: (path, count) async =>
          (ok: false, error: 'Second rollback failed.'),
    );

    expect(second.journalId, isNot(first.journalId));
    expect(await RestoreRecoveryNoticeStore.save(second), isTrue);
    expect(await RestoreRecoveryNoticeStore.peek(), isNotNull);
  });

  test('successfulRecoveryStillClearsJournalAndCreatesOneNotice', () async {
    await RestoreJournal.write(
      const RestoreJournalEntry(
        snapshotPath: '/snap-success',
        restoreMode: 'replace',
        backupTargetId: 'backup-success',
        createdAtMs: 5,
        originalFlightCount: 2,
        phase: RestoreJournalPhase.applying,
      ),
    );

    final recovery = await ReplaceRestoreTransaction.recoverPendingOnStartup(
      rollbackFromSnapshot: (path, count) async => (ok: true, error: null),
    );

    expect(recovery.hadPendingJournal, isTrue);
    expect(recovery.rollbackSucceeded, isTrue);
    expect(await RestoreJournal.read(), isNull);
    expect(await RestoreRecoveryNoticeStore.save(recovery), isTrue);
    expect(await RestoreRecoveryNoticeStore.takeLatest(), isNotNull);
    expect(await RestoreRecoveryNoticeStore.save(recovery), isFalse);
  });
}

import 'dart:io';

import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/utils/backup_operation_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DateTime now;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('falconlog_lock_test_');
    now = DateTime.utc(2026, 6, 1, 12);
    BackupOperationLock.baseDirectoryForTesting = tempDir;
    BackupOperationLock.nowForTesting = () => now;
    BackupOperationLock.heartbeatIntervalForTesting =
        const Duration(milliseconds: 20);
    SharedPreferences.setMockInitialValues({});
    await BackupOperationLock.clearForTesting();
  });

  tearDown(() async {
    await BackupOperationLock.clearForTesting();
    BackupOperationLock.resetTestOverrides();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('foregroundAndWorkmanagerDoNotOverlap', () async {
    final foreground = await BackupOperationLock.acquire(
      operationType: BackupOperationType.manualBackup,
      ownerToken: 'foreground-owner',
    );
    expect(foreground.acquired, isTrue);

    final workmanager = await BackupOperationLock.acquire(
      operationType: BackupOperationType.scheduledBackup,
      ownerToken: 'workmanager-owner',
    );

    expect(workmanager.acquired, isFalse);
    expect(workmanager.activeLock?.ownerToken, 'foreground-owner');
    expect(workmanager.message, contains('manual backup'));
  });

  test('restoreAndScheduledBackupDoNotOverlap', () async {
    final restore = await BackupOperationLock.acquire(
      operationType: BackupOperationType.restore,
      ownerToken: 'restore-owner',
    );
    expect(restore.acquired, isTrue);

    final scheduled = await BackupOperationLock.acquire(
      operationType: BackupOperationType.scheduledBackup,
      ownerToken: 'scheduled-owner',
    );

    expect(scheduled.acquired, isFalse);
    expect(scheduled.activeLock?.operationType, BackupOperationType.restore);
  });

  test('staleOwnerCannotReleaseNewerLock', () async {
    final first = await BackupOperationLock.acquire(
      operationType: BackupOperationType.manualBackup,
      ownerToken: 'old-owner',
      staleTimeout: const Duration(minutes: 10),
    );
    expect(first.acquired, isTrue);

    now = now.add(const Duration(minutes: 11));
    final second = await BackupOperationLock.acquire(
      operationType: BackupOperationType.scheduledBackup,
      ownerToken: 'new-owner',
      staleTimeout: const Duration(minutes: 10),
    );
    expect(second.acquired, isTrue);

    expect(await BackupOperationLock.touch(ownerToken: 'old-owner'), isFalse);
    expect(await BackupOperationLock.release(ownerToken: 'old-owner'), isFalse);
    expect((await BackupOperationLock.read())?.ownerToken, 'new-owner');
  });

  test('lockExpiresAfterStaleTimeout', () async {
    final first = await BackupOperationLock.acquire(
      operationType: BackupOperationType.restore,
      ownerToken: 'stale-owner',
      staleTimeout: const Duration(minutes: 5),
    );
    expect(first.acquired, isTrue);

    now = now.add(const Duration(minutes: 6));
    final second = await BackupOperationLock.acquire(
      operationType: BackupOperationType.manualBackup,
      ownerToken: 'fresh-owner',
      staleTimeout: const Duration(minutes: 5),
    );

    expect(second.acquired, isTrue);
    expect((await BackupOperationLock.read())?.ownerToken, 'fresh-owner');
  });

  test('longRunningOperationRefreshesLockAndCannotBeStolen', () async {
    final first = await BackupOperationLock.acquire(
      operationType: BackupOperationType.manualBackup,
      ownerToken: 'long-owner',
      staleTimeout: const Duration(milliseconds: 100),
    );
    expect(first.acquired, isTrue);

    final lease = BackupOperationLockLease(
      ownerToken: 'long-owner',
      operationType: BackupOperationType.manualBackup,
    );

    now = now.add(const Duration(milliseconds: 80));
    await lease.heartbeatNowForTesting();
    expect(lease.completedHeartbeatCount, 1);

    now = now.add(const Duration(milliseconds: 80));

    final second = await BackupOperationLock.acquire(
      operationType: BackupOperationType.scheduledBackup,
      ownerToken: 'would-steal',
      staleTimeout: const Duration(milliseconds: 100),
    );

    expect(second.acquired, isFalse);
    expect(second.activeLock?.ownerToken, 'long-owner');
  });

  test('staleLockCanBeAcquiredOnlyAfterHeartbeatStopsPastTimeout', () async {
    final first = await BackupOperationLock.acquire(
      operationType: BackupOperationType.manualBackup,
      ownerToken: 'heartbeat-owner',
      staleTimeout: const Duration(milliseconds: 100),
    );
    expect(first.acquired, isTrue);

    final lease = BackupOperationLockLease(
      ownerToken: 'heartbeat-owner',
      operationType: BackupOperationType.manualBackup,
    );

    now = now.add(const Duration(milliseconds: 80));
    await lease.heartbeatNowForTesting();

    now = now.add(const Duration(milliseconds: 80));
    final blocked = await BackupOperationLock.acquire(
      operationType: BackupOperationType.restore,
      ownerToken: 'blocked-owner',
      staleTimeout: const Duration(milliseconds: 100),
    );
    expect(blocked.acquired, isFalse);

    now = now.add(const Duration(milliseconds: 110));
    final acquired = await BackupOperationLock.acquire(
      operationType: BackupOperationType.restore,
      ownerToken: 'new-owner',
      staleTimeout: const Duration(milliseconds: 100),
    );
    expect(acquired.acquired, isTrue);
    expect((await BackupOperationLock.read())?.ownerToken, 'new-owner');
  });

  test('oldOwnerHeartbeatCannotTouchNewerLock', () async {
    final first = await BackupOperationLock.acquire(
      operationType: BackupOperationType.manualBackup,
      ownerToken: 'old-heartbeat-owner',
      staleTimeout: const Duration(minutes: 5),
    );
    expect(first.acquired, isTrue);

    now = now.add(const Duration(minutes: 6));
    final second = await BackupOperationLock.acquire(
      operationType: BackupOperationType.restore,
      ownerToken: 'new-heartbeat-owner',
      staleTimeout: const Duration(minutes: 5),
    );
    expect(second.acquired, isTrue);

    final oldLease = BackupOperationLockLease(
      ownerToken: 'old-heartbeat-owner',
      operationType: BackupOperationType.manualBackup,
      heartbeatInterval: const Duration(milliseconds: 20),
    );
    await oldLease.heartbeatNowForTesting();

    expect(oldLease.isLost, isTrue);
    expect(
      () => oldLease.throwIfLost(),
      throwsA(isA<BackupOperationLeaseLostException>()),
    );
    expect(
        (await BackupOperationLock.read())?.ownerToken, 'new-heartbeat-owner');
  });

  test('heartbeatStopsAfterStopAndDoesNotRefreshReleasedLock', () async {
    BackupOperationLock.nowForTesting = null;
    final first = await BackupOperationLock.acquire(
      operationType: BackupOperationType.manualBackup,
      ownerToken: 'stopping-owner',
      staleTimeout: const Duration(milliseconds: 60),
    );
    expect(first.acquired, isTrue);

    final lease = BackupOperationLockLease(
      ownerToken: 'stopping-owner',
      operationType: BackupOperationType.manualBackup,
      heartbeatInterval: const Duration(milliseconds: 20),
    );
    lease.start();

    final deadline = DateTime.now().add(const Duration(milliseconds: 200));
    while (lease.completedHeartbeatCount == 0 &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(lease.completedHeartbeatCount, greaterThan(0));

    await lease.stop();
    final heartbeatCountAfterStop = lease.completedHeartbeatCount;
    await Future<void>.delayed(const Duration(milliseconds: 70));

    expect(lease.completedHeartbeatCount, heartbeatCountAfterStop);
    expect(await BackupOperationLock.release(ownerToken: 'stopping-owner'),
        isTrue);
  });

  test('failedOperationReleasesOwnLock', () async {
    final service = BackupService();
    service.setBackupInProgressForTesting(false);

    final success = await service.startBackup(
      providerOverride: BackupProvider.firebase,
    );

    expect(success, isFalse);
    expect(await BackupOperationLock.read(), isNull);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(await BackupOperationLock.read(), isNull);
  });
}

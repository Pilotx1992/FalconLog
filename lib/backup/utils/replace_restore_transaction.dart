import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../models/flight_log.dart';
import '../models/restore_mode.dart';
import 'backup_payload_codec.dart';
import 'restore_journal.dart';

/// Result of a transactional Replace restore.
class ReplaceRestoreTransactionResult {
  final bool success;
  final bool rolledBack;
  final int flightLogsRestored;
  final int aircraftTypesRestored;
  final int settingsRestored;
  final String? error;

  const ReplaceRestoreTransactionResult._({
    required this.success,
    required this.rolledBack,
    required this.flightLogsRestored,
    required this.aircraftTypesRestored,
    required this.settingsRestored,
    this.error,
  });

  factory ReplaceRestoreTransactionResult.success({
    required int flightLogsRestored,
    int aircraftTypesRestored = 0,
    int settingsRestored = 0,
  }) =>
      ReplaceRestoreTransactionResult._(
        success: true,
        rolledBack: false,
        flightLogsRestored: flightLogsRestored,
        aircraftTypesRestored: aircraftTypesRestored,
        settingsRestored: settingsRestored,
      );

  factory ReplaceRestoreTransactionResult.failure({
    required String error,
    required bool rolledBack,
  }) =>
      ReplaceRestoreTransactionResult._(
        success: false,
        rolledBack: rolledBack,
        flightLogsRestored: 0,
        aircraftTypesRestored: 0,
        settingsRestored: 0,
        error: error,
      );
}

/// Startup recovery outcome for a pending restore journal.
class PendingRestoreRecoveryResult {
  final bool hadPendingJournal;
  final bool rollbackSucceeded;
  final String? message;

  const PendingRestoreRecoveryResult({
    required this.hadPendingJournal,
    required this.rollbackSucceeded,
    this.message,
  });

  static const none = PendingRestoreRecoveryResult(
    hadPendingJournal: false,
    rollbackSucceeded: true,
  );
}

typedef ApplyPayloadFn = Future<BackupRestoreApplyResult> Function(
  Map<String, dynamic> backupData,
);

typedef RollbackFromSnapshotFn = Future<({bool ok, String? error})> Function(
  String snapshotPath,
  int expectedFlightCount,
);

/// Journal-backed Replace restore with automatic rollback on failure.
class ReplaceRestoreTransaction {
  ReplaceRestoreTransaction({
    required Future<({String? path, String? error})> Function() createSnapshot,
    required ApplyPayloadFn applyBackupPayload,
    required RollbackFromSnapshotFn rollbackFromSnapshot,
    Future<int> Function()? countFlights,
  })  : _createSnapshot = createSnapshot,
        _applyBackupPayload = applyBackupPayload,
        _rollbackFromSnapshot = rollbackFromSnapshot,
        _countFlights = countFlights ?? _defaultCountFlights;

  final Future<({String? path, String? error})> Function() _createSnapshot;
  final ApplyPayloadFn _applyBackupPayload;
  final RollbackFromSnapshotFn _rollbackFromSnapshot;
  final Future<int> Function() _countFlights;

  static Future<int> _defaultCountFlights() async {
    if (!Hive.isBoxOpen('flightLogsBox')) {
      return 0;
    }
    return Hive.box<FlightLog>('flightLogsBox').length;
  }

  /// Replace restore: snapshot → journal → apply → commit marker → clear journal.
  Future<ReplaceRestoreTransactionResult> execute({
    required Map<String, dynamic> backupData,
    required String backupTargetId,
  }) async {
    final snapshot = await _createSnapshot();
    if (snapshot.error != null) {
      return ReplaceRestoreTransactionResult.failure(
        error: snapshot.error!,
        rolledBack: false,
      );
    }

    final snapshotPath = snapshot.path!;
    final originalFlightCount = await _countFlights();

    await RestoreJournal.write(
      RestoreJournalEntry(
        snapshotPath: snapshotPath,
        restoreMode: RestoreMode.replace.name,
        backupTargetId: backupTargetId,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        originalFlightCount: originalFlightCount,
        phase: RestoreJournalPhase.started,
      ),
    );

    try {
      await RestoreJournal.write(
        RestoreJournalEntry(
          snapshotPath: snapshotPath,
          restoreMode: RestoreMode.replace.name,
          backupTargetId: backupTargetId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          originalFlightCount: originalFlightCount,
          phase: RestoreJournalPhase.applying,
        ),
      );

      BackupRestoreApplyResult applyResult;
      try {
        applyResult = await _applyBackupPayload(backupData);
      } catch (e) {
        applyResult = BackupRestoreApplyResult.failure(
          'Restore failed unexpectedly: $e',
        );
      }

      if (!applyResult.success) {
        return await _failAndRollback(
          snapshotPath: snapshotPath,
          originalFlightCount: originalFlightCount,
          reason: applyResult.error ?? 'Replace restore failed.',
        );
      }

      await RestoreJournal.write(
        RestoreJournalEntry(
          snapshotPath: snapshotPath,
          restoreMode: RestoreMode.replace.name,
          backupTargetId: backupTargetId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          originalFlightCount: originalFlightCount,
          phase: RestoreJournalPhase.committed,
        ),
      );
      await RestoreJournal.clear();

      return ReplaceRestoreTransactionResult.success(
        flightLogsRestored: applyResult.flightLogsRestored,
        aircraftTypesRestored: applyResult.aircraftTypesRestored,
        settingsRestored: applyResult.settingsRestored,
      );
    } catch (e) {
      return await _failAndRollback(
        snapshotPath: snapshotPath,
        originalFlightCount: originalFlightCount,
        reason: 'Restore failed unexpectedly: $e',
      );
    }
  }

  Future<ReplaceRestoreTransactionResult> _failAndRollback({
    required String snapshotPath,
    required int originalFlightCount,
    required String reason,
  }) async {
    final rollback = await _rollbackFromSnapshot(
      snapshotPath,
      originalFlightCount,
    );
    final rolledBack = rollback.ok;
    if (rolledBack) {
      await RestoreJournal.clear();
    }
    return ReplaceRestoreTransactionResult.failure(
      error: rolledBack
          ? '$reason Your previous data was restored.'
          : '$reason Could not restore your previous data automatically. '
              'Please restart the app or contact support.',
      rolledBack: rolledBack,
    );
  }

  /// If a journal exists from a crashed/interrupted restore, recover safely.
  static Future<PendingRestoreRecoveryResult> recoverPendingOnStartup({
    required RollbackFromSnapshotFn rollbackFromSnapshot,
  }) async {
    final journal = await RestoreJournal.read();
    if (journal == null) {
      return PendingRestoreRecoveryResult.none;
    }

    if (journal.phase == RestoreJournalPhase.committed) {
      await RestoreJournal.clear();
      developer.log(
        '[RestoreJournal] Cleared committed journal for backup ${journal.backupTargetId}.',
        name: 'ReplaceRestoreTransaction',
      );
      return PendingRestoreRecoveryResult.none;
    }

    developer.log(
      '[RestoreJournal] Pending ${journal.restoreMode} (${journal.phase.name}) '
      'for backup ${journal.backupTargetId}; rolling back.',
      name: 'ReplaceRestoreTransaction',
    );

    final rollback = await rollbackFromSnapshot(
      journal.snapshotPath,
      journal.originalFlightCount,
    );

    if (rollback.ok) {
      await RestoreJournal.clear();
      final msg =
          'Recovered from an interrupted restore. Your previous data was restored.';
      if (kDebugMode) {
        debugPrint('✅ $msg');
      }
      return PendingRestoreRecoveryResult(
        hadPendingJournal: true,
        rollbackSucceeded: true,
        message: msg,
      );
    }

    final msg = rollback.error ??
        'Interrupted restore detected but automatic recovery failed.';
    developer.log('[RestoreJournal] Recovery failed: $msg',
        name: 'ReplaceRestoreTransaction', level: 1000);
    return PendingRestoreRecoveryResult(
      hadPendingJournal: true,
      rollbackSucceeded: false,
      message: msg,
    );
  }
}

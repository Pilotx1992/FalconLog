import 'package:hive/hive.dart';

import '../../models/flight_log.dart';
import '../models/restore_mode.dart';
import 'backup_payload_codec.dart';
import 'replace_restore_transaction.dart';
import 'restore_journal.dart';

/// Journal-backed Merge restore with snapshot rollback (same lifecycle as Replace).
class MergeRestoreTransaction {
  MergeRestoreTransaction({
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

    Future<void> writePhase(RestoreJournalPhase phase) => RestoreJournal.write(
          RestoreJournalEntry(
            snapshotPath: snapshotPath,
            restoreMode: RestoreMode.merge.name,
            backupTargetId: backupTargetId,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
            originalFlightCount: originalFlightCount,
            phase: phase,
          ),
        );

    await writePhase(RestoreJournalPhase.started);

    try {
      await writePhase(RestoreJournalPhase.applying);

      BackupRestoreApplyResult applyResult;
      try {
        applyResult = await _applyBackupPayload(backupData);
      } catch (e) {
        applyResult = BackupRestoreApplyResult.failure(
          'Merge restore failed unexpectedly: $e',
        );
      }

      if (!applyResult.success) {
        return await _failAndRollback(
          snapshotPath: snapshotPath,
          originalFlightCount: originalFlightCount,
          reason: applyResult.error ?? 'Merge restore failed.',
        );
      }

      await writePhase(RestoreJournalPhase.committed);
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
        reason: 'Merge restore failed unexpectedly: $e',
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

  static Future<PendingRestoreRecoveryResult> recoverPendingOnStartup({
    required RollbackFromSnapshotFn rollbackFromSnapshot,
  }) =>
      ReplaceRestoreTransaction.recoverPendingOnStartup(
        rollbackFromSnapshot: rollbackFromSnapshot,
      );
}

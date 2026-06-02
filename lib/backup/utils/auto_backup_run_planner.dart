import 'auto_backup_conditions.dart';

enum AutoBackupPlannerAction {
  noop,
  enqueueCatchup,
  executeCatchup,
}

class AutoBackupPlannerResult {
  const AutoBackupPlannerResult({
    required this.action,
    this.pendingDueDay,
    this.runDueDay,
    this.blockReason,
    this.reportWorkmanagerSuccess = true,
  });

  final AutoBackupPlannerAction action;
  final String? pendingDueDay;
  final String? runDueDay;
  final AutoBackupBlockReason? blockReason;
  final bool reportWorkmanagerSuccess;

  factory AutoBackupPlannerResult.noop({bool wmSuccess = true}) =>
      AutoBackupPlannerResult(
        action: AutoBackupPlannerAction.noop,
        reportWorkmanagerSuccess: wmSuccess,
      );

  factory AutoBackupPlannerResult.enqueueCatchup(String pendingDueDay) =>
      AutoBackupPlannerResult(
        action: AutoBackupPlannerAction.enqueueCatchup,
        pendingDueDay: pendingDueDay,
      );

  factory AutoBackupPlannerResult.executeCatchup({
    required String runDueDay,
    required String pendingDueDay,
  }) =>
      AutoBackupPlannerResult(
        action: AutoBackupPlannerAction.executeCatchup,
        runDueDay: runDueDay,
        pendingDueDay: pendingDueDay,
      );

  factory AutoBackupPlannerResult.blocked({
    required AutoBackupBlockReason reason,
    String? pendingDueDay,
    bool wmSuccess = true,
  }) =>
      AutoBackupPlannerResult(
        action: AutoBackupPlannerAction.noop,
        pendingDueDay: pendingDueDay,
        blockReason: reason,
        reportWorkmanagerSuccess: wmSuccess,
      );
}

class AutoBackupRunPlanner {
  AutoBackupRunPlanner._();

  /// Daily evaluator tick — may set pending; never executes backup.
  static AutoBackupPlannerResult planEvaluatorTick({
    required String? pendingAfterTick,
  }) {
    if (pendingAfterTick == null) {
      return AutoBackupPlannerResult.noop();
    }
    return AutoBackupPlannerResult.enqueueCatchup(pendingAfterTick);
  }

  /// Catch-up worker — captures [runDueDay] at start from pending.
  static AutoBackupPlannerResult planCatchupExecution(
    AutoBackupExecutionContext ctx,
  ) {
    final pending = ctx.pendingDueDay;
    if (pending == null) {
      return AutoBackupPlannerResult.noop();
    }

    final block = AutoBackupConditionsEvaluator.firstExecutionBlock(ctx);
    if (block != null) {
      return AutoBackupPlannerResult.blocked(
        reason: block,
        pendingDueDay: pending,
        wmSuccess: _wmSuccessForBlock(block),
      );
    }

    return AutoBackupPlannerResult.executeCatchup(
      runDueDay: pending,
      pendingDueDay: pending,
    );
  }

  static bool _wmSuccessForBlock(AutoBackupBlockReason block) {
    switch (block) {
      case AutoBackupBlockReason.networkNotSatisfied:
      case AutoBackupBlockReason.batteryLow:
      case AutoBackupBlockReason.storageLow:
      case AutoBackupBlockReason.operationLockHeld:
      case AutoBackupBlockReason.driveAuthNotReady:
      case AutoBackupBlockReason.noPendingDueDay:
      case AutoBackupBlockReason.alreadySucceededForDueDay:
        return true;
      case AutoBackupBlockReason.unsupportedProvider:
      case AutoBackupBlockReason.disabled:
      case AutoBackupBlockReason.notDailyFrequency:
      case AutoBackupBlockReason.noFlightLogs:
      case AutoBackupBlockReason.restoreInProgress:
        return true;
    }
  }
}

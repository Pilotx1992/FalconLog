import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/utils/auto_backup_conditions.dart';
import 'package:falconlog/backup/utils/auto_backup_run_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoBackupRunPlanner', () {
    test('evaluator tick with pending enqueues catch-up', () {
      final plan = AutoBackupRunPlanner.planEvaluatorTick(
        pendingAfterTick: '2026-06-03',
      );
      expect(plan.action, AutoBackupPlannerAction.enqueueCatchup);
      expect(plan.pendingDueDay, '2026-06-03');
    });

    test('catch-up captures runDueDay from pending', () {
      final plan = AutoBackupRunPlanner.planCatchupExecution(
        AutoBackupExecutionContext(
          autoBackupEnabled: true,
          frequency: 'daily',
          provider: BackupProvider.local,
          hasFlightLogs: true,
          pendingDueDay: '2026-06-03',
          lastSuccessDueDay: '2026-06-01',
          driveReady: true,
          networkSatisfied: true,
          batteryOk: true,
          storageOk: true,
          lockFree: true,
        ),
      );
      expect(plan.action, AutoBackupPlannerAction.executeCatchup);
      expect(plan.runDueDay, '2026-06-03');
    });

    test('wifi block keeps pending without execute', () {
      final plan = AutoBackupRunPlanner.planCatchupExecution(
        AutoBackupExecutionContext(
          autoBackupEnabled: true,
          frequency: 'daily',
          provider: BackupProvider.googleDrive,
          hasFlightLogs: true,
          pendingDueDay: '2026-06-03',
          lastSuccessDueDay: null,
          driveReady: true,
          networkSatisfied: false,
          batteryOk: true,
          storageOk: true,
          lockFree: true,
        ),
      );
      expect(plan.action, AutoBackupPlannerAction.noop);
      expect(plan.blockReason, AutoBackupBlockReason.networkNotSatisfied);
    });
  });
}

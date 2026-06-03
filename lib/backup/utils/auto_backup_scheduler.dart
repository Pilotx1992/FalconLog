import 'package:logging/logging.dart';
import 'package:workmanager/workmanager.dart';

import '../models/backup_provider_enum.dart';
import 'auto_backup_due_engine.dart';
import 'auto_backup_work_names.dart';
import 'backup_scheduler.dart';

/// Registers WorkManager work for daily vs interval auto backup paths.
class AutoBackupScheduler {
  AutoBackupScheduler({Logger? logger}) : _logger = logger ?? Logger('AutoBackupScheduler');

  final Logger _logger;

  static Constraints evaluatorConstraints() => Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      );

  Duration delayUntilNextDueOrMinimum({DateTime? now}) {
    final local = now ?? DateTime.now();
    final next = AutoBackupDueEngine.nextDueDateTime(
      nowLocal: local,
      dueMinuteOfDay: AutoBackupDueEngine.defaultDueMinuteOfDay,
    );
    var delay = next.difference(local);
    if (delay.isNegative) {
      delay = Duration.zero;
    }
    const minimum = Duration(minutes: 15);
    if (delay < minimum) {
      return minimum;
    }
    return delay;
  }

  Future<void> registerDailyEvaluator() async {
    await BackupScheduler.registerPeriodicTaskInternal(
      uniqueName: AutoBackupWorkNames.dailyEvaluatorUnique,
      taskName: AutoBackupWorkNames.dailyEvaluatorTask,
      frequency: const Duration(hours: 24),
      constraints: evaluatorConstraints(),
      initialDelay: delayUntilNextDueOrMinimum(),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      tag: AutoBackupWorkNames.taskTag,
    );
    _logger.info('Registered daily auto backup evaluator');
  }

  Future<void> registerCatchup({
    required BackupProvider provider,
    required bool wifiOnly,
  }) async {
    final constraints = BackupScheduler.constraintsForProvider(
      provider,
      wifiOnly: wifiOnly,
    );
    await BackupScheduler.registerOneOffTaskInternal(
      uniqueName: AutoBackupWorkNames.catchupUnique,
      taskName: AutoBackupWorkNames.catchupTask,
      constraints: constraints,
      initialDelay: Duration.zero,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      tag: AutoBackupWorkNames.taskTag,
    );
    _logger.info('Enqueued auto backup catch-up');
  }

  Future<void> registerIntervalPeriodic({
    required String frequency,
    required BackupProvider provider,
    required bool wifiOnly,
  }) async {
    final intervalSeconds = BackupScheduler.scheduleIntervalSeconds(frequency);
    if (intervalSeconds == null || intervalSeconds == 0) {
      throw ArgumentError.value(frequency, 'frequency', 'invalid interval');
    }
    final constraints = BackupScheduler.constraintsForProvider(
      provider,
      wifiOnly: wifiOnly,
    );
    await BackupScheduler.registerPeriodicTaskInternal(
      uniqueName: AutoBackupWorkNames.intervalPeriodicUnique,
      taskName: AutoBackupWorkNames.intervalTask,
      frequency: Duration(seconds: intervalSeconds),
      constraints: constraints,
      initialDelay: const Duration(minutes: 5),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      tag: AutoBackupWorkNames.taskTag,
    );
    _logger.info('Registered interval auto backup: $frequency');
  }

  Future<void> cancelDailyPath() async {
    await BackupScheduler.cancelByUniqueNameInternal(
      AutoBackupWorkNames.dailyEvaluatorUnique,
    );
    await BackupScheduler.cancelByUniqueNameInternal(
      AutoBackupWorkNames.catchupUnique,
    );
  }

  Future<void> cancelIntervalPath() async {
    await BackupScheduler.cancelByUniqueNameInternal(
      AutoBackupWorkNames.intervalPeriodicUnique,
    );
  }

  Future<void> cancelLegacyWork() async {
    await BackupScheduler.cancelByUniqueNameInternal(
      AutoBackupWorkNames.legacyImmediateUnique,
    );
    await BackupScheduler.cancelByUniqueNameInternal(
      AutoBackupWorkNames.legacyTaskUnique,
    );
    await BackupScheduler.cancelByUniqueNameInternal(
      AutoBackupWorkNames.legacyBackgroundUnique,
    );
    await BackupScheduler.cancelByTagInternal(AutoBackupWorkNames.taskTag);
  }

  Future<void> cancelAllAutoBackupWork() async {
    await cancelDailyPath();
    await cancelIntervalPath();
    await cancelLegacyWork();
  }
}

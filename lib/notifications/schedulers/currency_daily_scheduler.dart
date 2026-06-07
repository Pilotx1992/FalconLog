import 'package:logging/logging.dart';
import 'package:workmanager/workmanager.dart';

import '../../backup/utils/backup_scheduler.dart';
import '../domain/currency_daily_notification.dart';
import 'currency_daily_work_names.dart';

/// Registers/cancels the daily WorkManager task for currency countdown notifications.
class CurrencyDailyScheduler {
  CurrencyDailyScheduler._();

  static final _logger = Logger('CurrencyDailyScheduler');

  static Constraints constraints() => Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      );

  static Future<void> registerDailyTask({DateTime? now}) async {
    try {
      await BackupScheduler.registerPeriodicTaskInternal(
        uniqueName: CurrencyDailyWorkNames.uniqueName,
        taskName: CurrencyDailyWorkNames.taskName,
        frequency: const Duration(hours: 24),
        constraints: constraints(),
        initialDelay: delayUntilNext9Am(now: now),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        tag: CurrencyDailyWorkNames.taskTag,
      );
      _logger.info('Registered daily currency notification work');
    } catch (e, stackTrace) {
      _logger.warning('registerDailyTask failed', e, stackTrace);
    }
  }

  static Future<void> cancelDailyTask() async {
    try {
      await BackupScheduler.cancelByUniqueNameInternal(
        CurrencyDailyWorkNames.uniqueName,
      );
      await BackupScheduler.cancelByTagInternal(CurrencyDailyWorkNames.taskTag);
      _logger.info('Cancelled daily currency notification work');
    } catch (e, stackTrace) {
      _logger.warning('cancelDailyTask failed', e, stackTrace);
    }
  }
}

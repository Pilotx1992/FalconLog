import 'package:logging/logging.dart';

import '../../backup/utils/backup_scheduler.dart';
import 'currency_daily_work_names.dart';
import 'currency_expiry_scheduler.dart';

/// Background WorkManager handler for daily currency notifications.
class CurrencyDailyWorker {
  CurrencyDailyWorker._();

  static Future<bool> handleTask(String task, Logger logger) async {
    if (task != CurrencyDailyWorkNames.taskName) {
      return false;
    }

    try {
      await BackupScheduler.initializeBackgroundDependencies(logger);
      await CurrencyExpiryScheduler.runDailyCurrencyNotificationFromHive(
        allowShowNow: true,
      );
      return true;
    } catch (e, stackTrace) {
      logger.warning('Currency daily task failed', e, stackTrace);
      return false;
    }
  }
}

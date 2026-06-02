/// WorkManager unique names and task names for auto backup paths.
class AutoBackupWorkNames {
  AutoBackupWorkNames._();

  static const String dailyEvaluatorUnique = 'falconlog_auto_backup_daily';
  static const String dailyEvaluatorTask = 'falconlog_auto_backup_daily';

  static const String catchupUnique = 'falconlog_auto_backup_catchup';
  static const String catchupTask = 'falconlog_auto_backup_catchup';

  static const String intervalPeriodicUnique = 'falconlog_auto_backup_periodic';
  static const String intervalTask = 'falconlog_auto_backup';

  static const String taskTag = 'falconlog_backup';

  static const String legacyImmediateUnique = 'falconlog_auto_backup_immediate';
  static const String legacyTaskUnique = 'falconlog_backup_task';
  static const String legacyBackgroundUnique = 'encrypted_local_backup';
}

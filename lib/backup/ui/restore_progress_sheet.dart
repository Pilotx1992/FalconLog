import 'package:flutter/material.dart';

import '../models/backup_provider_enum.dart' show BackupInfo;
import '../services/backup_service.dart' show BackupService, RestoreMode;
import 'backup_progress_sheet.dart';

/// Deprecated thin wrapper. Use [BackupProgressSheet] with an explicit
/// [restoreTarget] instead.
@Deprecated('Use BackupProgressSheet with restoreTarget directly.')
class RestoreProgressSheet extends StatelessWidget {
  final BackupService backupService;
  final BackupInfo restoreTarget;
  final RestoreMode restoreMode;
  final VoidCallback? onRestoreComplete;

  const RestoreProgressSheet({
    super.key,
    required this.backupService,
    required this.restoreTarget,
    this.restoreMode = RestoreMode.replace,
    this.onRestoreComplete,
  });

  @override
  Widget build(BuildContext context) {
    return BackupProgressSheet(
      backupService: backupService,
      isRestore: true,
      restoreMode: restoreMode,
      restoreTarget: restoreTarget,
      onRestoreComplete: onRestoreComplete,
    );
  }
}

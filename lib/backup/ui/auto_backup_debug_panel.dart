import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/auto_backup_debug_qa.dart';

/// Temporary debug-only QA strip for on-device auto backup verification.
///
/// Wrapped in [kDebugMode]; not compiled into release UX paths.
class AutoBackupDebugPanel extends StatefulWidget {
  const AutoBackupDebugPanel({super.key});

  @override
  State<AutoBackupDebugPanel> createState() => _AutoBackupDebugPanelState();
}

class _AutoBackupDebugPanelState extends State<AutoBackupDebugPanel> {
  String? _status;

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _status = label);
    try {
      await action();
      if (mounted) setState(() => _status = '$label — ok');
    } catch (e) {
      if (mounted) setState(() => _status = '$label — $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auto Backup QA (debug)',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: muted),
          ),
          if (_status != null) ...[
            const SizedBox(height: 4),
            Text(_status!, style: TextStyle(fontSize: 10, color: muted)),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                'Set due time to now + 2 minutes',
                () => _run(
                  'Set due +2m',
                  () => AutoBackupDebugQa.setDueTimeToNowPlusMinutes(2),
                ),
              ),
              _chip(
                'Run auto backup reconcile now',
                () => _run(
                  'Reconcile',
                  AutoBackupDebugQa.runReconcileNow,
                ),
              ),
              _chip(
                'Dump auto backup state to log',
                () => _run(
                  'Dump state',
                  AutoBackupDebugQa.dumpStateToLog,
                ),
              ),
              _chip(
                'Clear daily auto backup state',
                () => _run(
                  'Clear state',
                  AutoBackupDebugQa.clearDailyAutoBackupState,
                ),
              ),
              _chip(
                'Reset due to 23:59',
                () => _run(
                  'Reset 23:59',
                  AutoBackupDebugQa.resetDueToProductionDefault,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: onTap,
    );
  }
}

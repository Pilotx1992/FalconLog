import 'package:flutter/material.dart';
import '../services/backup_service.dart';

/// Real-time progress display for backup/restore operations
class RestoreProgressSheet extends StatefulWidget {
  final bool isRestore;
  final VoidCallback? onRestoreComplete;

  const RestoreProgressSheet({
    super.key,
    this.isRestore = false,
    this.onRestoreComplete,
  });

  @override
  State<RestoreProgressSheet> createState() => _RestoreProgressSheetState();
}

class _RestoreProgressSheetState extends State<RestoreProgressSheet> {
  final BackupService _backupService = BackupService();
  bool _isStarted = false;

  @override
  void initState() {
    super.initState();
    _backupService.addListener(_onProgressUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOperation();
    });
  }

  void _onProgressUpdate() {
    if (mounted) {
      setState(() {});

      // Check if restore completed successfully
      if (widget.isRestore &&
          _backupService.currentProgress.restoreStatus == RestoreStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onRestoreComplete?.call();
        });
      }
    }
  }

  Future<void> _startOperation() async {
    if (_isStarted) return;
    _isStarted = true;

    if (widget.isRestore) {
      await _backupService.startRestore();
    } else {
      await _backupService.startBackup();
    }
  }

  @override
  void dispose() {
    _backupService.removeListener(_onProgressUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _backupService.currentProgress;
    final isCompleted = progress.isCompleted;
    final percentage = progress.percentage;
    final action = progress.currentAction;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                widget.isRestore ? Icons.restore : Icons.backup,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isRestore ? 'Restoring Backup' : 'Creating Backup',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (!isCompleted)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress Circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress.isFailed ? Colors.red : Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  progress.statusEmoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Progress Bar
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress.isFailed ? Colors.red : Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Status Text
          Text(
            progress.statusText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: progress.isFailed ? Colors.red : null,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            action,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Action Buttons
          if (isCompleted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(progress.isCompleted && !progress.isFailed ? 'Done' : 'Close'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../models/backup_status.dart';
import '../services/backup_service.dart';

class BackupProgressSheet extends StatefulWidget {
  final bool isRestore;
  final RestoreMode? restoreMode;
  final VoidCallback? onRestoreComplete;
  final VoidCallback? onBackupComplete;

  const BackupProgressSheet({
    super.key,
    this.isRestore = false,
    this.restoreMode,
    this.onRestoreComplete,
    this.onBackupComplete,
  });

  @override
  State<BackupProgressSheet> createState() => _BackupProgressSheetState();
}

class _BackupProgressSheetState extends State<BackupProgressSheet> {
  final BackupService _backupService = BackupService();

  late final bool _isRestore;
  bool _isOperationInProgress = false;
  bool _hasCalledCallback = false;
  OperationProgress _currentProgress = const OperationProgress(
    percentage: 0,
    backupStatus: BackupStatus.idle,
    currentAction: 'Ready',
  );

  @override
  void initState() {
    super.initState();
    _isRestore = widget.isRestore;

    _backupService.addListener(_onProgressUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isRestore) {
        _startRestore();
      } else {
        _startBackup();
      }
    });
  }

  @override
  void dispose() {
    _backupService.removeListener(_onProgressUpdate);
    super.dispose();
  }

  void _onProgressUpdate() {
    if (mounted) {
      setState(() {
        _currentProgress = _backupService.currentProgress;
      });

      if (!_isRestore && !_hasCalledCallback) {
        if (_currentProgress.backupStatus == BackupStatus.completed &&
            _currentProgress.percentage == 100) {
          _hasCalledCallback = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            widget.onBackupComplete?.call();
            if (mounted) Navigator.pop(context);
          });
        } else if (_currentProgress.backupStatus == BackupStatus.failed) {
          _hasCalledCallback = true;
          if (mounted) {
            _showErrorDialog('Backup failed. Please try again.');
          }
        }
      }
    }
  }

  Future<void> _startBackup() async {
    setState(() => _isOperationInProgress = true);
    try {
      await _backupService.startBackup();
      if (kDebugMode) print('🐛 DEBUG: Backup started');
    } catch (e) {
      if (kDebugMode) print('🐛 DEBUG: Error starting backup: $e');
      if (mounted) _showErrorDialog('Failed to start backup: $e');
    } finally {
      setState(() => _isOperationInProgress = false);
    }
  }

  Future<void> _startRestore() async {
    setState(() => _isOperationInProgress = true);
    try {
      // Default to merge mode to preserve existing data
      final mode = widget.restoreMode ?? RestoreMode.merge;
      final result = await _backupService.startRestore(mode: mode);
      if (mounted) {
        if (result.success) {
          widget.onRestoreComplete?.call();
          Navigator.of(context).pop();
        } else {
          _showErrorDialog(result.error ?? 'Restore failed. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Restore failed: $e');
    } finally {
      setState(() => _isOperationInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1924) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  _isRestore ? 'Restore Progress' : 'Backup Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                if (_isOperationInProgress && _currentProgress.percentage < 100)
                  TextButton(
                    onPressed: _cancelOperation,
                    child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularPercentIndicator(
                  radius: 80,
                  lineWidth: 8,
                  percent: _currentProgress.percentage / 100,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_currentProgress.statusEmoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 4),
                      Text('${_currentProgress.percentage}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          )),
                    ],
                  ),
                  progressColor: _getProgressColor(),
                  backgroundColor: isDark ? Colors.white24 : Colors.grey[200]!,
                  animation: true,
                  animationDuration: 300,
                ),
                const SizedBox(height: 32),
                Text(_currentProgress.statusText,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 8),
                Text(
                  _currentProgress.currentAction,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                if (_currentProgress.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentProgress.errorMessage!,
                            style: TextStyle(color: Colors.red[700], fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_currentProgress.isCompleted ||
              _currentProgress.isFailed ||
              _currentProgress.isCancelled)
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentProgress.isCompleted
                        ? Colors.green[600]
                        : Colors.grey[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentProgress.isCompleted ? 'Done' : 'Close',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getProgressColor() {
    if (_currentProgress.isFailed) return Colors.red[600]!;
    if (_currentProgress.isCompleted) return Colors.green[600]!;
    if (_currentProgress.isCancelled) return Colors.orange[600]!;
    return Colors.blue[600]!;
  }

  void _cancelOperation() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel ${_isRestore ? 'Restore' : 'Backup'}'),
        content: Text('Are you sure you want to cancel the ${_isRestore ? 'restore' : 'backup'} operation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await _backupService.cancelCurrentOperation();
              if (mounted) navigator.pop();
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
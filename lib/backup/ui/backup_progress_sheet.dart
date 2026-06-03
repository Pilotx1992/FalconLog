import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../models/backup_provider_enum.dart' show BackupInfo, BackupProvider;
import '../models/backup_status.dart';
import '../services/backup_service.dart';
import '../utils/backup_safety_import_helper.dart';
import 'backup_ui_theme.dart';

class BackupProgressSheet extends StatefulWidget {
  final BackupService backupService;
  final BackupProvider? backupProvider;
  final bool isRestore;
  final RestoreMode? restoreMode;
  final BackupInfo? restoreTarget;
  final BackupSafetyImportCandidate? safetyImportCandidate;
  final VoidCallback? onRestoreComplete;
  final VoidCallback? onBackupComplete;

  const BackupProgressSheet({
    super.key,
    required this.backupService,
    this.backupProvider,
    this.isRestore = false,
    this.restoreMode,
    this.restoreTarget,
    this.safetyImportCandidate,
    this.onRestoreComplete,
    this.onBackupComplete,
  });

  @override
  State<BackupProgressSheet> createState() => _BackupProgressSheetState();
}

class _BackupProgressSheetState extends State<BackupProgressSheet> {
  late final BackupService _backupService;
  late final bool _isRestore;

  bool _isOperationInProgress = false;
  bool _hasFinished = false;
  bool _isErrorDialogVisible = false;

  OperationProgress _currentProgress = const OperationProgress(
    percentage: 0,
    backupStatus: BackupStatus.idle,
    currentAction: 'Ready',
  );

  @override
  void initState() {
    super.initState();

    _backupService = widget.backupService;
    _isRestore = widget.isRestore;

    _backupService.addListener(_onProgressUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  bool get _isTerminal =>
      _currentProgress.isCompleted ||
      _currentProgress.isFailed ||
      _currentProgress.isCancelled;

  bool get _canPop => !_isOperationInProgress || _isTerminal;

  double get _progressPercent =>
      (_currentProgress.percentage / 100).clamp(0.0, 1.0);

  int get _safePercentage => _currentProgress.percentage.clamp(0, 100).toInt();

  String get _sheetTitle {
    if (_currentProgress.isCompleted) {
      return _isRestore ? 'Restore complete' : 'Backup complete';
    }
    if (_currentProgress.isFailed) {
      return _isRestore ? 'Restore failed' : 'Backup failed';
    }
    if (_currentProgress.isCancelled) return 'Backup cancelled';
    return _isRestore ? 'Restore in progress' : 'Backup in progress';
  }

  void _onProgressUpdate() {
    if (!mounted) return;

    setState(() {
      _currentProgress = _backupService.currentProgress;
    });

    if (_hasFinished) return;

    if (_currentProgress.isCompleted) {
      _finishOperation(success: true);
      return;
    }

    if (_currentProgress.isFailed) {
      _finishOperation(
        success: false,
        errorMessage: _currentProgress.errorMessage ??
            (_isRestore
                ? 'Restore failed. Please try again.'
                : 'Backup failed. Please try again.'),
      );
    }
  }

  Future<void> _finishOperation({
    required bool success,
    String? errorMessage,
  }) async {
    if (_hasFinished) return;
    _hasFinished = true;

    if (mounted) setState(() => _isOperationInProgress = false);

    if (success) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      if (_isRestore) {
        widget.onRestoreComplete?.call();
      } else {
        widget.onBackupComplete?.call();
      }

      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }

    if (!mounted) return;
    _showErrorDialog(
      errorMessage ??
          (_isRestore
              ? 'Restore failed. Please try again.'
              : 'Backup failed. Please try again.'),
    );
  }

  void _syncCompletionFromServiceIfNeeded() {
    if (_hasFinished) return;

    final progress = _backupService.currentProgress;
    _currentProgress = progress;

    if (progress.isCompleted) {
      _finishOperation(success: true);
      return;
    }

    if (progress.isFailed) {
      _finishOperation(
        success: false,
        errorMessage: progress.errorMessage ??
            (_isRestore
                ? 'Restore failed. Please try again.'
                : 'Backup failed. Please try again.'),
      );
    }
  }

  Future<void> _startBackup() async {
    if (!mounted) return;

    setState(() => _isOperationInProgress = true);

    try {
      await _backupService.startBackup(
        providerOverride: widget.backupProvider,
      );

      if (kDebugMode) {
        debugPrint('Backup operation completed from service call.');
      }

      if (!mounted) return;
      _syncCompletionFromServiceIfNeeded();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Backup failed to start: $e');
        debugPrint('$stackTrace');
      }

      if (!mounted) return;
      await _finishOperation(
        success: false,
        errorMessage: 'Failed to start backup: $e',
      );
    } finally {
      if (mounted && !_hasFinished) {
        setState(() => _isOperationInProgress = false);
      }
    }
  }

  Future<void> _startRestore() async {
    if (!mounted) return;

    final safetyCandidate = widget.safetyImportCandidate;
    final target = widget.restoreTarget;
    if (safetyCandidate == null && target == null) {
      await _finishOperation(
        success: false,
        errorMessage:
            'No backup selected. Choose a backup from Recent Backups.',
      );
      return;
    }

    setState(() => _isOperationInProgress = true);

    try {
      final result = safetyCandidate != null
          ? await _backupService.startRestoreFromSafetyCopy(
              candidate: safetyCandidate,
              mode: widget.restoreMode ?? RestoreMode.merge,
            )
          : await _backupService.startRestore(
              mode: widget.restoreMode ?? RestoreMode.merge,
              target: target!,
            );

      if (!mounted) return;

      if (!result.success) {
        await _finishOperation(
          success: false,
          errorMessage: result.error ?? 'Restore failed. Please try again.',
        );
        return;
      }

      _syncCompletionFromServiceIfNeeded();

      if (!_hasFinished) await _finishOperation(success: true);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Restore failed: $e');
        debugPrint('$stackTrace');
      }

      if (!mounted) return;
      await _finishOperation(
        success: false,
        errorMessage: 'Restore failed: $e',
      );
    } finally {
      if (mounted && !_hasFinished) {
        setState(() => _isOperationInProgress = false);
      }
    }
  }

  Color _getProgressColor() {
    if (_currentProgress.isFailed) return BackupUiTheme.danger;
    if (_currentProgress.isCompleted) return BackupUiTheme.success;
    if (_currentProgress.isCancelled) return BackupUiTheme.warning;
    return BackupUiTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Surfaces adapt to theme – dark cockpit palette in dark mode,
    // clean neutral in light mode.
    final sheetBg = isDark ? const Color(0xFF0E1C28) : Colors.white;
    final handleColor =
        isDark ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFCBD5E1);
    final strokeBorderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final progressTrackColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;

    final height = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isOperationInProgress && !_isTerminal) {
          ScaffoldMessenger.of(context).showSnackBar(
            BackupUiTheme.styledSnack(
              _isRestore
                  ? 'Restore is still running. Please wait until it finishes.'
                  : 'Backup is still running. Cancel it first if needed.',
            ),
          );
        }
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: height * 0.85,
              minHeight: 360,
            ),
            child: Material(
              color: sheetBg,
              elevation: 0,
              shadowColor: Colors.transparent,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: strokeBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: BackupUiTheme.accent.withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    // Sheet handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                      child: Row(
                        children: [
                          BackupUiTheme.iconBadge(
                            _isRestore
                                ? Icons.restore_rounded
                                : Icons.backup_rounded,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _sheetTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                          ),
                          if (!_isRestore &&
                              _isOperationInProgress &&
                              !_isTerminal &&
                              _currentProgress.percentage < 100)
                            TextButton(
                              onPressed: _cancelOperation,
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: BackupUiTheme.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Scrollable body
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularPercentIndicator(
                              radius: 80,
                              lineWidth: 10,
                              percent: _progressPercent,
                              center: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentProgress.statusEmoji,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_safePercentage%',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                    ),
                                  ),
                                ],
                              ),
                              progressColor: _getProgressColor(),
                              backgroundColor: progressTrackColor,
                              circularStrokeCap: CircularStrokeCap.round,
                              animation: true,
                              animationDuration: 300,
                              animateFromLastPercent: true,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _currentProgress.statusText,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentProgress.currentAction,
                              style: TextStyle(
                                fontSize: 14,
                                color: mutedColor,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_currentProgress.errorMessage != null) ...[
                              const SizedBox(height: 20),
                              BackupUiTheme.infoBanner(
                                icon: Icons.error_outline_rounded,
                                message: _currentProgress.errorMessage!,
                                tone: BackupUiTheme.danger,
                                messageColor: titleColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Done / Close button
                    if (_isTerminal)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _currentProgress.isCompleted
                                  ? LinearGradient(
                                      colors: [
                                        BackupUiTheme.success,
                                        BackupUiTheme.success
                                            .withValues(alpha: 0.75),
                                      ],
                                    )
                                  : null,
                              color: _currentProgress.isCompleted
                                  ? null
                                  : const Color(0xFF64748B),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                _currentProgress.isCompleted ? 'Done' : 'Close',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancelOperation() async {
    if (_isRestore || !_isOperationInProgress || _isTerminal) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel backup?'),
        content: const Text('Are you sure you want to cancel this backup?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Yes, cancel',
              style: TextStyle(color: BackupUiTheme.danger),
            ),
          ),
        ],
      ),
    );

    if (shouldCancel != true || !mounted) return;

    try {
      await _backupService.cancelCurrentOperation();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to cancel backup: $e');
    }

    if (!mounted) return;

    setState(() {
      _isOperationInProgress = false;
      _currentProgress = const OperationProgress(
        percentage: 0,
        backupStatus: BackupStatus.cancelled,
        currentAction: 'Backup cancelled',
      );
    });
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted || _isErrorDialogVisible) return;

    _isErrorDialogVisible = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: BackupUiTheme.danger),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Something went wrong', maxLines: 2),
            ),
          ],
        ),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    _isErrorDialogVisible = false;

    if (!mounted) return;

    // Do NOT call onRestoreComplete here — restore failed.
    // Only pop the sheet so the user returns to the settings page.
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }
}

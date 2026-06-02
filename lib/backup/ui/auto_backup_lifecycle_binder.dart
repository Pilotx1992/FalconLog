import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/auto_backup_log.dart';
import '../utils/auto_backup_reconciler.dart';

/// Debounced app-resume hook for auto backup scheduling (no direct backup execution).
class AutoBackupLifecycleBinder extends StatefulWidget {
  const AutoBackupLifecycleBinder({
    super.key,
    required this.child,
    this.debounceDuration = const Duration(seconds: 2),
    this.onResumeReconcile,
  });

  final Widget child;

  /// Debounce window for rapid [AppLifecycleState.resumed] events.
  final Duration debounceDuration;

  /// Test seam; defaults to [AutoBackupReconciler.reconcile].
  final Future<void> Function()? onResumeReconcile;

  @override
  State<AutoBackupLifecycleBinder> createState() =>
      _AutoBackupLifecycleBinderState();
}

class _AutoBackupLifecycleBinderState extends State<AutoBackupLifecycleBinder>
    with WidgetsBindingObserver {
  Timer? _debounceTimer;

  @visibleForTesting
  int scheduledReconcileCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleDebouncedReconcile();
    }
  }

  void _scheduleDebouncedReconcile() {
    _debounceTimer?.cancel();
    scheduledReconcileCount++;
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (!mounted) return;
      unawaited(_runReconcile());
    });
  }

  Future<void> _runReconcile() async {
    AutoBackupLog.lifecycle('resume reconcile firing after debounce');
    final reconcile = widget.onResumeReconcile ?? () async {
      await AutoBackupReconciler().reconcile();
    };
    await reconcile();
    AutoBackupLog.lifecycle('resume reconcile complete');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

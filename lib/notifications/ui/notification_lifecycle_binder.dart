import 'dart:async';

import 'package:flutter/widgets.dart';

import '../schedulers/currency_expiry_scheduler.dart';

/// Recomputes currency notification schedules on app resume; shows today's
/// countdown after 9:00 if not already shown (catch-up for delayed WorkManager).
class NotificationLifecycleBinder extends StatefulWidget {
  const NotificationLifecycleBinder({
    super.key,
    required this.child,
    this.debounceDuration = const Duration(seconds: 2),
    this.onResumeReschedule,
  });

  final Widget child;
  final Duration debounceDuration;

  @visibleForTesting
  final Future<void> Function()? onResumeReschedule;

  @override
  State<NotificationLifecycleBinder> createState() =>
      _NotificationLifecycleBinderState();
}

class _NotificationLifecycleBinderState
    extends State<NotificationLifecycleBinder> with WidgetsBindingObserver {
  Timer? _debounceTimer;

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
      _scheduleDebouncedReschedule();
    }
  }

  void _scheduleDebouncedReschedule() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (!mounted) return;
      unawaited(_runReschedule());
    });
  }

  Future<void> _runReschedule() async {
    final reschedule = widget.onResumeReschedule ??
        CurrencyExpiryScheduler.rescheduleOnAppResume;
    try {
      await reschedule();
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

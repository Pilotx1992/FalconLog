import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/security_providers.dart';

/// Observes app lifecycle and drives auto-lock on pause/resume.
class SecurityLifecycleBinder extends ConsumerStatefulWidget {
  const SecurityLifecycleBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SecurityLifecycleBinder> createState() =>
      _SecurityLifecycleBinderState();
}

class _SecurityLifecycleBinderState
    extends ConsumerState<SecurityLifecycleBinder> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final init = ref.read(securityInitProvider);
    if (!init.hasValue) return;
    ref.read(securityServiceProvider).markOrientationChange();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final init = ref.read(securityInitProvider);
    if (!init.hasValue) return;

    final service = ref.read(securityServiceProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        service.onAppPaused();
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.resumed:
        service.onAppResumed();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

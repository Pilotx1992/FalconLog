import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_providers.dart';
import 'unlock_screen.dart';

/// Gates protected content behind PIN / biometric app lock.
///
/// Switches UI state only — no route push to avoid navigation loops.
class SecurityWrapper extends ConsumerWidget {
  const SecurityWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(securityInitProvider);

    return init.when(
      loading: () => const _SecurityLoadingShell(),
      error: (error, _) => _SecurityErrorShell(
        message: kDebugMode ? error.toString() : null,
      ),
      data: (_) {
        // Rebuild when lock state or settings change (not only on init).
        ref.watch(securityLockStateProvider);
        ref.watch(securitySettingsProvider);
        final service = ref.watch(securityServiceProvider);

        if (!service.isPinEnabled) {
          return _InteractionListener(child: child);
        }

        if (service.shouldShowLock()) {
          return const UnlockScreen();
        }

        return _InteractionListener(child: child);
      },
    );
  }
}

class _InteractionListener extends ConsumerWidget {
  const _InteractionListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        ref.read(securityServiceProvider).recordInteraction();
      },
      child: child,
    );
  }
}

class _SecurityLoadingShell extends StatelessWidget {
  const _SecurityLoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SecurityErrorShell extends StatelessWidget {
  const _SecurityErrorShell({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 48, color: Color(0xFF3949ab)),
              const SizedBox(height: 16),
              const Text(
                'App lock could not be initialized.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Restart the app. If this continues, disable PIN or biometric lock in a previous session or reinstall.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../currency_alert_settings_provider.dart';
import 'currency_alert_setup_screen.dart';

/// Shows currency setup once after app lock unlock; otherwise passes child through.
class CurrencyAlertSetupGate extends ConsumerWidget {
  const CurrencyAlertSetupGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(currencyAlertSettingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => child,
      data: (settings) {
        if (settings.hasCompletedSetup) {
          return child;
        }
        return const CurrencyAlertSetupScreen();
      },
    );
  }
}

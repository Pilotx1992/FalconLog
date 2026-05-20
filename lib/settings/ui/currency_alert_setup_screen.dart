import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../currency_alert_settings_provider.dart';
import 'currency_alert_interval_form.dart';

/// Blocking first-run screen for manual currency alert intervals.
class CurrencyAlertSetupScreen extends ConsumerStatefulWidget {
  const CurrencyAlertSetupScreen({super.key});

  @override
  ConsumerState<CurrencyAlertSetupScreen> createState() =>
      _CurrencyAlertSetupScreenState();
}

class _CurrencyAlertSetupScreenState
    extends ConsumerState<CurrencyAlertSetupScreen> {
  final _formKey = GlobalKey<CurrencyAlertIntervalFormState>();
  bool _canSave = false;
  bool _busy = false;

  Future<void> _onSave() async {
    final form = _formKey.currentState;
    if (form == null || !form.validateAndSave()) return;
    final day = form.dayDays;
    final night = form.nightDays;
    if (day == null || night == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(currencyAlertSettingsProvider.notifier).completeSetup(
            dayAlertDays: day,
            nightAlertDays: night,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set Currency Alerts',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[850],
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 24),
                CurrencyAlertIntervalForm(
                  key: _formKey,
                  mode: CurrencyAlertFormMode.firstRun,
                  onValidityChanged: (valid) {
                    if (_canSave != valid) {
                      setState(() => _canSave = valid);
                    }
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canSave && !_busy ? _onSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      disabledBackgroundColor:
                          Colors.grey.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Text(
                            'Save / Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

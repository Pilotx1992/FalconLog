import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/app_snack_bar.dart';
import '../currency_alert_settings.dart';
import '../currency_alert_settings_provider.dart';
import 'currency_alert_interval_form.dart';

/// Currency Alerts rows for [SettingsScreen].
class SettingsCurrencyAlertsSection extends ConsumerWidget {
  const SettingsCurrencyAlertsSection({
    super.key,
    required this.buildTile,
    required this.buildDivider,
  });

  final Widget Function({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool bareTrailing,
  }) buildTile;

  final Widget Function() buildDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(currencyAlertSettingsProvider);

    return settingsAsync.when(
      loading: () => buildTile(
        icon: Icons.schedule_rounded,
        title: 'Currency Alerts',
        subtitle: 'Loading...',
        onTap: () {},
      ),
      error: (_, __) => buildTile(
        icon: Icons.schedule_rounded,
        title: 'Currency Alerts',
        subtitle: 'Unable to load',
        onTap: () {},
      ),
      data: (settings) => Column(
        children: [
          buildTile(
            icon: Icons.wb_sunny_rounded,
            title: 'Day currency alert',
            subtitle: '${settings.dayAlertDays} Day',
            onTap: () => _showEditDialog(
              context,
              ref,
              settings,
              scope: CurrencyAlertFormScope.dayOnly,
            ),
          ),
          buildDivider(),
          buildTile(
            icon: Icons.nights_stay_rounded,
            title: 'Night currency alert',
            subtitle: '${settings.nightAlertDays} Night',
            onTap: () => _showEditDialog(
              context,
              ref,
              settings,
              scope: CurrencyAlertFormScope.nightOnly,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    CurrencyAlertSettings settings, {
    required CurrencyAlertFormScope scope,
  }) async {
    final isDay = scope == CurrencyAlertFormScope.dayOnly;
    final title = isDay ? 'Day currency alert' : 'Night currency alert';
    final formKey = GlobalKey<CurrencyAlertIntervalFormState>();
    var canSave = true;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    isDay
                        ? Icons.wb_sunny_rounded
                        : Icons.nights_stay_rounded,
                    color: Theme.of(ctx).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: CurrencyAlertIntervalForm(
                  key: formKey,
                  mode: CurrencyAlertFormMode.edit,
                  scope: scope,
                  initialDayDays: settings.dayAlertDays,
                  initialNightDays: settings.nightAlertDays,
                  showDisclaimer: false,
                  onValidityChanged: (valid) {
                    if (canSave != valid) {
                      setDialogState(() => canSave = valid);
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: canSave
                      ? () {
                          final form = formKey.currentState;
                          if (form == null || !form.validateAndSave()) return;
                          final value =
                              isDay ? form.dayDays : form.nightDays;
                          if (value == null) return;
                          Navigator.pop(ctx, value);
                        }
                      : null,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !context.mounted) return;

    await ref.read(currencyAlertSettingsProvider.notifier).updateIntervals(
          dayAlertDays:
              isDay ? result : settings.dayAlertDays,
          nightAlertDays:
              isDay ? settings.nightAlertDays : result,
        );

    if (!context.mounted) return;
    AppSnackBar.show(context, message: 'Currency alert settings updated');
  }
}

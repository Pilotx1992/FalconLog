import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_providers.dart';
import '../security_constants.dart';
import '../services/security_service.dart';
import 'pin_change_screen.dart';
import 'pin_setup_screen.dart';

/// Security settings tiles for [SettingsScreen].
class SettingsSecuritySection extends ConsumerWidget {
  const SettingsSecuritySection({
    super.key,
    required this.buildTile,
    required this.buildDivider,
  });

  final Widget Function({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool bareTrailing,
  }) buildTile;

  final Widget Function() buildDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(securityInitProvider);
    ref.watch(securitySettingsProvider);
    final service = ref.watch(securityServiceProvider);
    final pinEnabled = service.isPinEnabled;
    final biometricAvailableAsync =
        ref.watch(biometricAvailableForAppLockProvider);
    final biometricAvailable = biometricAvailableAsync.valueOrNull ?? false;

    return Column(
      children: [
        buildTile(
          icon: Icons.pin_outlined,
          title: 'PIN Lock',
          subtitle: pinEnabled ? 'Enabled' : 'Set a 4-digit PIN',
          onTap: () {},
          bareTrailing: true,
          trailing: Switch.adaptive(
            value: pinEnabled,
            onChanged: (value) => _onPinToggle(context, ref, value),
          ),
        ),
        buildDivider(),
        buildTile(
          icon: Icons.fingerprint,
          title: 'Biometric App Unlock',
          subtitle: pinEnabled
              ? (biometricAvailable
                  ? 'Unlock the app with fingerprint or face after PIN lock'
                  : 'Set up fingerprint or face in phone Settings')
              : 'Enable PIN Lock first to use biometric app unlock.',
          onTap: () {},
          bareTrailing: true,
          trailing: Switch.adaptive(
            value: pinEnabled && service.settings.isAppLockBiometricEnabled,
            onChanged: pinEnabled && biometricAvailable
                ? (v) => _onBiometricToggle(context, ref, v)
                : null,
          ),
        ),
        if (pinEnabled) ...[
          buildDivider(),
          buildTile(
            icon: Icons.edit_outlined,
            title: 'Change PIN',
            subtitle: 'Update your PIN',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PinChangeScreen()),
              );
            },
          ),
          buildDivider(),
          buildTile(
            icon: Icons.timer_outlined,
            title: 'Auto-Lock',
            subtitle: _autoLockLabel(service.settings.autoLockTimeoutSeconds),
            onTap: () => _showAutoLockPicker(context, ref, service),
          ),
        ],
      ],
    );
  }

  String _autoLockLabel(int seconds) {
    for (final preset in SecurityConstants.autoLockPresets) {
      if (preset.seconds == seconds) return preset.label;
    }
    return '$seconds seconds';
  }

  Future<void> _onBiometricToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final service = ref.read(securityServiceProvider);
    if (enable) {
      final ok = await service.authenticateForAppUnlock(
        reason: 'Confirm fingerprint or face to enable app unlock',
      );
      if (!context.mounted) return;
      if (ok) {
        await service.setAppLockBiometricEnabled(true);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric app unlock enabled'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric setup cancelled or failed. Try again.',
            ),
          ),
        );
      }
    } else {
      await service.setAppLockBiometricEnabled(false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric app unlock disabled')),
      );
    }
  }

  Future<void> _onPinToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final service = ref.read(securityServiceProvider);
    if (enable) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (ok == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN lock enabled')),
        );
      }
    } else {
      await _confirmDisablePin(context, ref, service);
    }
  }

  Future<void> _showAutoLockPicker(
    BuildContext context,
    WidgetRef ref,
    SecurityService service,
  ) async {
    final current = service.settings.autoLockTimeoutSeconds;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final preset in SecurityConstants.autoLockPresets)
                ListTile(
                  title: Text(preset.label),
                  trailing: preset.seconds == current
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(ctx, preset.seconds),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await service.setAutoLockTimeoutSeconds(selected);
    }
  }

  Future<void> _confirmDisablePin(
    BuildContext context,
    WidgetRef ref,
    SecurityService service,
  ) async {
    final pinController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'Enter current PIN',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await service.disablePin(pin: pinController.text);
    pinController.dispose();
    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN lock disabled')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not disable PIN')),
      );
    }
  }
}

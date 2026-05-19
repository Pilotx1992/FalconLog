import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_providers.dart';
import '../security_constants.dart';
import 'pin_pad_widget.dart';

/// Minimal app-lock unlock screen (PIN + optional biometric).
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  static const String _logoAsset = 'assets/airplane.png';

  String _pin = '';
  String? _error;
  Timer? _lockoutTimer;
  bool _biometricAutoPromptAttempted = false;

  @override
  void initState() {
    super.initState();
    _startLockoutTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAutoPromptBiometric());
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutTicker() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final service = ref.read(securityServiceProvider);
      service.clearExpiredLockout();
      if (mounted) setState(() {});
    });
  }

  Future<void> _maybeAutoPromptBiometric() async {
    if (_biometricAutoPromptAttempted || !mounted) return;

    final service = ref.read(securityServiceProvider);
    if (!service.isPinEnabled ||
        !service.settings.isAppLockBiometricEnabled ||
        service.isInLockout) {
      return;
    }

    if (!await service.canUseAppLockBiometric()) return;

    _biometricAutoPromptAttempted = true;
    await service.unlockWithAppLockBiometric();
  }

  Future<void> _submitPin() async {
    final service = ref.read(securityServiceProvider);
    if (service.isInLockout) return;

    try {
      final ok = await service.verifyPin(_pin);
      if (!mounted) return;

      if (ok) {
        setState(() {
          _pin = '';
          _error = null;
        });
        return;
      }

      if (!service.isPinEnabled) {
        // Repaired while verifying — parent wrapper will show app content.
        return;
      }

      setState(() {
        _pin = '';
        _error = 'Incorrect PIN';
      });
    } catch (e, st) {
      debugPrint('[UnlockScreen] verifyPin failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _pin = '';
        _error = 'Unable to verify PIN. Try again or disable PIN in Settings.';
      });
    }
  }

  void _onDigit(String digit) {
    final service = ref.read(securityServiceProvider);
    if (service.isInLockout) return;

    setState(() {
      _error = null;
      if (_pin.length < SecurityConstants.pinLength) {
        _pin += digit;
      }
    });

    if (_pin.length == SecurityConstants.pinLength) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _tryBiometric() async {
    final service = ref.read(securityServiceProvider);
    if (service.isInLockout) return;
    await service.unlockWithAppLockBiometric();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildLogo(Color primary) {
    return Image.asset(
      _logoAsset,
      width: 72,
      height: 72,
      errorBuilder: (_, __, ___) => Icon(
        Icons.lock_outline,
        size: 48,
        color: primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(securityLockStateProvider);
    ref.watch(securitySettingsProvider);
    final service = ref.watch(securityServiceProvider);

    if (!service.isPinEnabled) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final inLockout = service.isInLockout;
    final remaining = service.lockoutRemaining;
    final biometricAsync = ref.watch(canUseAppLockBiometricProvider);
    final showBiometric = !inLockout && (biometricAsync.valueOrNull ?? false);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                _buildLogo(scheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Unlock FalconLog',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (inLockout && remaining != null)
                  Text(
                    'Try again in ${_formatDuration(remaining)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                        ),
                  )
                else if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(color: scheme.error),
                  ),
                const SizedBox(height: 24),
                PinDotsIndicator(
                  length: SecurityConstants.pinLength,
                  filled: inLockout ? 0 : _pin.length,
                ),
                const Spacer(),
                PinPadWidget(
                  enabled: !inLockout,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                ),
                const SizedBox(height: 16),
                if (showBiometric)
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use fingerprint or face unlock'),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

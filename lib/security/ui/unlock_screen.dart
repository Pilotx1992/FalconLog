import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
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
  int _errorPulse = 0;
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
        return;
      }

      setState(() {
        _pin = '';
        _error = 'Incorrect PIN';
        _errorPulse++;
      });
    } catch (e, st) {
      debugPrint('[UnlockScreen] verifyPin failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _pin = '';
        _error = 'Unable to verify PIN. Try again or disable PIN in Settings.';
        _errorPulse++;
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

  Widget _buildLogo(ColorScheme scheme) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer.withValues(alpha: 0.35),
      ),
      child: Center(
        child: Image.asset(
          _logoAsset,
          width: 52,
          height: 52,
          errorBuilder: (_, __, ___) => Icon(
            Icons.lock_outline_rounded,
            size: 40,
            color: AppColors.brandPrimary,
          ),
        ),
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

    String? statusMessage;
    var statusIsError = false;
    String? subtitle;

    if (inLockout && remaining != null) {
      statusMessage = 'Try again in ${_formatDuration(remaining)}';
      statusIsError = true;
      subtitle = 'Too many attempts';
    } else if (_error != null) {
      statusMessage = _error;
      statusIsError = true;
    } else {
      subtitle = 'Enter your 4-digit PIN';
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: PinEntryLayout(
            header: _buildLogo(scheme),
            title: 'Unlock FalconLog',
            subtitle: subtitle,
            statusMessage: statusMessage,
            statusIsError: statusIsError,
            pinLength: SecurityConstants.pinLength,
            filled: inLockout ? 0 : _pin.length,
            errorPulse: _errorPulse,
            dotsDimmed: inLockout,
            padEnabled: !inLockout,
            onDigit: _onDigit,
            onBackspace: _onBackspace,
            footer: showBiometric
                ? TextButton.icon(
                    onPressed: _tryBiometric,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 22),
                    label: const Text('Use biometrics'),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

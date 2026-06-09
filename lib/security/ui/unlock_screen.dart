import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../utils/responsive_layout.dart';
import '../providers/security_providers.dart';
import '../security_constants.dart';
import 'pin_pad_widget.dart';
import 'package:flutter/foundation.dart';

/// App-lock unlock screen (PIN + optional biometric).
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
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await service.unlockWithAppLockBiometric();
  }

  Future<void> _submitPin() async {
    final service = ref.read(securityServiceProvider);
    if (service.isInLockout) return;

    try {
      final ok = await service.verifyPin(_pin);
      if (!mounted) return;

      if (ok) {
        HapticFeedback.mediumImpact();
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
      if (kDebugMode) debugPrint('[UnlockScreen] verifyPin failed: $e\n$st');
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
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _pin.length == SecurityConstants.pinLength) {
          _submitPin();
        }
      });
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

  String _formatLockoutSeconds(Duration d) {
    final total = d.inSeconds;
    if (total >= 60) {
      final m = d.inMinutes.remainder(60);
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return total.toString();
  }

  Widget _buildBrandHeader({required bool compact}) {
    final logoSize = compact ? 52.0 : 60.0;
    final iconSize = compact ? 30.0 : 36.0;

    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              _logoAsset,
              width: iconSize,
              height: iconSize,
              errorBuilder: (_, __, ___) => Icon(
                Icons.flight_takeoff_rounded,
                size: iconSize - 4,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          'FalconLog',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
        ),
      ],
    );
  }

  Widget _buildLockoutBanner(Duration remaining, {required bool compact}) {
    final secondsLabel = _formatLockoutSeconds(remaining);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lock_clock,
            color: Colors.red.shade700,
            size: compact ? 28 : 32,
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            'Too Many Failed Attempts',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait $secondsLabel',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

    final inLockout = service.isInLockout;
    final remaining = service.lockoutRemaining;
    final biometricAsync = ref.watch(canUseAppLockBiometricProvider);
    final showBiometric = !inLockout && (biometricAsync.valueOrNull ?? false);

    String title;
    String? subtitle;
    String? statusMessage;
    var statusIsError = false;

    if (inLockout && remaining != null) {
      title = 'Locked';
      subtitle = 'Wait for lockout to end';
      statusMessage = null;
    } else if (_error != null) {
      title = 'Enter PIN';
      subtitle = 'Unlock to access your flights';
      statusMessage = _error;
      statusIsError = true;
    } else {
      title = 'Enter PIN';
      subtitle = 'Unlock to access your flights';
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = isCompactHeight(constraints.maxHeight);
              final brandGap = responsiveVerticalGap(
                maxHeight: constraints.maxHeight,
                normal: 20,
                compact: 12,
              );
              final lockoutGap = responsiveVerticalGap(
                maxHeight: constraints.maxHeight,
                normal: 14,
                compact: 10,
              );

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: compact ? 8 : 12,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBrandHeader(compact: compact),
                        SizedBox(height: brandGap),
                        if (inLockout && remaining != null) ...[
                          _buildLockoutBanner(
                            remaining,
                            compact: compact,
                          ),
                          SizedBox(height: lockoutGap),
                        ],
                        PinEntryLayout(
                          centerContent: true,
                          compactVertical: compact,
                          title: title,
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
                          onBiometric: showBiometric ? _tryBiometric : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

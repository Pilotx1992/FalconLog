import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_providers.dart';
import '../security_constants.dart';
import '../utils/pin_validator.dart';
import 'pin_pad_widget.dart';

enum _PinSetupStep { enter, confirm }

/// First-time PIN setup (enter + confirm).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  _PinSetupStep _step = _PinSetupStep.enter;
  String _pin = '';
  String _firstPin = '';
  String? _error;
  bool _busy = false;

  Future<void> _finish(String confirmed) async {
    if (confirmed != _firstPin) {
      setState(() {
        _error = 'PINs do not match';
        _pin = '';
        _step = _PinSetupStep.enter;
        _firstPin = '';
      });
      return;
    }

    setState(() => _busy = true);
    final service = ref.read(securityServiceProvider);
    final result = await service.enablePin(confirmed);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.isValid) {
      setState(() {
        _error = result.errorMessage;
        _pin = '';
        _firstPin = '';
        _step = _PinSetupStep.enter;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _onDigit(String digit) {
    if (_busy) return;
    setState(() {
      _error = null;
      if (_pin.length < SecurityConstants.pinLength) {
        _pin += digit;
      }
    });

    if (_pin.length < SecurityConstants.pinLength) return;

    if (_step == _PinSetupStep.enter) {
      final validation = PinValidator.validate(_pin);
      if (!validation.isValid) {
        setState(() {
          _error = validation.errorMessage;
          _pin = '';
        });
        return;
      }
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _step = _PinSetupStep.confirm;
      });
      return;
    }

    _finish(_pin);
  }

  void _onBackspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _step == _PinSetupStep.enter
        ? 'Create a 4-digit PIN'
        : 'Confirm your PIN';

    return Scaffold(
      appBar: AppBar(title: const Text('PIN Lock')),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 24),
              PinDotsIndicator(
                length: SecurityConstants.pinLength,
                filled: _pin.length,
              ),
              const Spacer(),
              if (_busy)
                const CircularProgressIndicator()
              else
                PinPadWidget(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

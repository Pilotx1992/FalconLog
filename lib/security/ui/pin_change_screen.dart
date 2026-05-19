import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_providers.dart';
import '../security_constants.dart';
import '../utils/pin_validator.dart';
import 'pin_pad_widget.dart';

enum _ChangeStep { current, newPin, confirm }

/// Change PIN (verify current, then new + confirm).
class PinChangeScreen extends ConsumerStatefulWidget {
  const PinChangeScreen({super.key});

  @override
  ConsumerState<PinChangeScreen> createState() => _PinChangeScreenState();
}

class _PinChangeScreenState extends ConsumerState<PinChangeScreen> {
  _ChangeStep _step = _ChangeStep.current;
  String _pin = '';
  String _currentPin = '';
  String _newPin = '';
  String? _error;
  bool _busy = false;

  Future<void> _submitChange(String confirmed) async {
    if (confirmed != _newPin) {
      setState(() {
        _error = 'PINs do not match';
        _resetToNew();
      });
      return;
    }

    setState(() => _busy = true);
    final service = ref.read(securityServiceProvider);
    final result = await service.changePin(
      currentPin: _currentPin,
      newPin: confirmed,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.isValid) {
      setState(() {
        _error = result.errorMessage;
        _resetToCurrent();
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN changed successfully')),
    );
    Navigator.of(context).pop(true);
  }

  void _resetToCurrent() {
    _pin = '';
    _step = _ChangeStep.current;
    _currentPin = '';
    _newPin = '';
  }

  void _resetToNew() {
    _pin = '';
    _step = _ChangeStep.newPin;
    _newPin = '';
  }

  Future<void> _verifyCurrent() async {
    final service = ref.read(securityServiceProvider);
    final ok = await service.checkPin(_pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'Current PIN is incorrect';
        _pin = '';
      });
      return;
    }
    setState(() {
      _currentPin = _pin;
      _pin = '';
      _step = _ChangeStep.newPin;
      _error = null;
    });
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

    switch (_step) {
      case _ChangeStep.current:
        _verifyCurrent();
      case _ChangeStep.newPin:
        final validation = PinValidator.validate(_pin);
        if (!validation.isValid) {
          setState(() {
            _error = validation.errorMessage;
            _pin = '';
          });
          return;
        }
        setState(() {
          _newPin = _pin;
          _pin = '';
          _step = _ChangeStep.confirm;
        });
      case _ChangeStep.confirm:
        _submitChange(_pin);
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  String get _title {
    switch (_step) {
      case _ChangeStep.current:
        return 'Enter current PIN';
      case _ChangeStep.newPin:
        return 'Enter new PIN';
      case _ChangeStep.confirm:
        return 'Confirm new PIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(_title, style: Theme.of(context).textTheme.titleMedium),
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

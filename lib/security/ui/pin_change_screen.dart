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
  int _errorPulse = 0;
  bool _busy = false;

  Future<void> _submitChange(String confirmed) async {
    if (confirmed != _newPin) {
      setState(() {
        _error = 'PINs do not match';
        _resetToNew();
        _errorPulse++;
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
        _errorPulse++;
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
        _errorPulse++;
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
            _errorPulse++;
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

  String? get _subtitle {
    switch (_step) {
      case _ChangeStep.current:
        return null;
      case _ChangeStep.newPin:
        return 'Choose a PIN that is not easy to guess';
      case _ChangeStep.confirm:
        return 'Re-enter your new PIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: PinEntryLayout(
          title: _title,
          subtitle: _subtitle,
          statusMessage: _error,
          statusIsError: _error != null,
          pinLength: SecurityConstants.pinLength,
          filled: _pin.length,
          errorPulse: _errorPulse,
          busy: _busy,
          onDigit: _onDigit,
          onBackspace: _onBackspace,
        ),
      ),
    );
  }
}

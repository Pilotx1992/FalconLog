import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_providers.dart';
import '../security_constants.dart';
import '../../utils/responsive_layout.dart';
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
  int _errorPulse = 0;
  bool _busy = false;

  Future<void> _finish(String confirmed) async {
    if (confirmed != _firstPin) {
      setState(() {
        _error = 'PINs do not match';
        _pin = '';
        _step = _PinSetupStep.enter;
        _firstPin = '';
        _errorPulse++;
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
        _errorPulse++;
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
          _errorPulse++;
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
    final isConfirm = _step == _PinSetupStep.confirm;
    final title = isConfirm ? 'Confirm your PIN' : 'Create a 4-digit PIN';
    final subtitle = isConfirm
        ? 'Enter the same PIN again'
        : 'Avoid simple sequences like 1234';

    const appBarForeground = Color(0xFF1E293B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN Lock'),
        foregroundColor: appBarForeground,
        iconTheme: const IconThemeData(color: appBarForeground),
        titleTextStyle: const TextStyle(
          color: appBarForeground,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = isCompactHeight(constraints.maxHeight);
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: PinEntryLayout(
                  compactVertical: compact,
                  title: title,
                  subtitle: subtitle,
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
          },
        ),
      ),
    );
  }
}

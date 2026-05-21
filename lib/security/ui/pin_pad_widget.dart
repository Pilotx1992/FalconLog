import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../security_constants.dart';

/// Numeric keypad for 4-digit PIN entry (circular keys, phone-style layout).
class PinPadWidget extends StatelessWidget {
  const PinPadWidget({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool enabled;

  static const double _keySize = 70;
  static const double _keyGap = 16;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KeyRow(
                keys: const ['1', '2', '3'],
                enabled: enabled,
                onDigit: onDigit,
              ),
              const SizedBox(height: _keyGap),
              _KeyRow(
                keys: const ['4', '5', '6'],
                enabled: enabled,
                onDigit: onDigit,
              ),
              const SizedBox(height: _keyGap),
              _KeyRow(
                keys: const ['7', '8', '9'],
                enabled: enabled,
                onDigit: onDigit,
              ),
              const SizedBox(height: _keyGap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onBiometric != null)
                    _BiometricKey(
                      enabled: enabled,
                      onPressed: onBiometric!,
                    )
                  else
                    const SizedBox(width: _keySize, height: _keySize),
                  const SizedBox(width: _keyGap),
                  _DigitKey(
                    digit: '0',
                    enabled: enabled,
                    onPressed: () => _tapDigit('0', onDigit),
                  ),
                  const SizedBox(width: _keyGap),
                  _DeleteKey(
                    enabled: enabled,
                    onPressed: () => _tapBackspace(onBackspace),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _tapDigit(String digit, ValueChanged<String> onDigit) {
    HapticFeedback.selectionClick();
    onDigit(digit);
  }

  static void _tapBackspace(VoidCallback onBackspace) {
    HapticFeedback.selectionClick();
    onBackspace();
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.keys,
    required this.enabled,
    required this.onDigit,
  });

  final List<String> keys;
  final bool enabled;
  final ValueChanged<String> onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: PinPadWidget._keyGap),
          _DigitKey(
            digit: keys[i],
            enabled: enabled,
            onPressed: () => PinPadWidget._tapDigit(keys[i], onDigit),
          ),
        ],
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.enabled,
    required this.onPressed,
  });

  final String digit;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.grey[300] : Colors.grey[300],
      elevation: enabled ? 2 : 0,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: PinPadWidget._keySize,
          height: PinPadWidget._keySize,
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: enabled ? Colors.black : Colors.grey[500],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteKey extends StatelessWidget {
  const _DeleteKey({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: PinPadWidget._keySize,
          height: PinPadWidget._keySize,
          child: Icon(
            Icons.backspace_outlined,
            size: 28,
            color: enabled ? AppColors.brandPrimary : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}

class _BiometricKey extends StatefulWidget {
  const _BiometricKey({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_BiometricKey> createState() => _BiometricKeyState();
}

class _BiometricKeyState extends State<_BiometricKey> {
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.enabled ? widget.onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: PinPadWidget._keySize,
          height: PinPadWidget._keySize,
          child: reduceMotion
              ? Icon(
                  Icons.fingerprint,
                  size: 32,
                  color: widget.enabled
                      ? AppColors.brandPrimary
                      : Colors.grey[400],
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.95, end: 1.05),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  onEnd: () {
                    if (mounted) setState(() {});
                  },
                  child: Icon(
                    Icons.fingerprint,
                    size: 32,
                    color: widget.enabled
                        ? AppColors.brandPrimary
                        : Colors.grey[400],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Filled PIN progress dots with fill animation and optional error shake.
class PinDotsIndicator extends StatefulWidget {
  const PinDotsIndicator({
    super.key,
    required this.length,
    this.filled = 0,
    this.errorPulse = 0,
    this.dimmed = false,
    this.hasError = false,
  });

  final int length;
  final int filled;
  final int errorPulse;
  final bool dimmed;
  final bool hasError;

  @override
  State<PinDotsIndicator> createState() => _PinDotsIndicatorState();
}

class _PinDotsIndicatorState extends State<PinDotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void didUpdateWidget(PinDotsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorPulse != oldWidget.errorPulse && widget.errorPulse > 0) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.hasError && !widget.dimmed;
    final activeColor =
        hasError ? Colors.red : AppColors.brandPrimary;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (index) {
          final isFilled = !widget.dimmed && index < widget.filled;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled
                  ? activeColor
                  : Colors.grey[300],
              border: Border.all(
                color: hasError ? Colors.red : AppColors.brandPrimary,
                width: 2,
              ),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isFilled
                ? const Center(
                    child: Icon(
                      Icons.circle,
                      color: Colors.white,
                      size: 12,
                    ),
                  )
                : null,
          );
        }),
      ),
    );
  }
}

/// Shared vertical layout for unlock, setup, and change PIN flows.
class PinEntryLayout extends StatelessWidget {
  const PinEntryLayout({
    super.key,
    this.header,
    required this.title,
    this.subtitle,
    this.statusMessage,
    this.statusIsError = false,
    required this.pinLength,
    required this.filled,
    this.errorPulse = 0,
    this.dotsDimmed = false,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.padEnabled = true,
    this.busy = false,
    this.footer,
    this.centerContent = false,
  });

  final Widget? header;
  final String title;
  final String? subtitle;
  final String? statusMessage;
  final bool statusIsError;
  final int pinLength;
  final int filled;
  final int errorPulse;
  final bool dotsDimmed;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool padEnabled;
  final bool busy;
  final Widget? footer;

  /// When true, vertically centers the block (unlock screen style).
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final content = _PinEntryBody(
      header: header,
      title: title,
      subtitle: subtitle,
      statusMessage: statusMessage,
      statusIsError: statusIsError,
      pinLength: pinLength,
      filled: filled,
      errorPulse: errorPulse,
      dotsDimmed: dotsDimmed,
      onDigit: onDigit,
      onBackspace: onBackspace,
      onBiometric: onBiometric,
      padEnabled: padEnabled,
      busy: busy,
      footer: footer,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: centerContent
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [content],
            )
          : Column(
              children: [
                const Spacer(flex: 2),
                content,
                const Spacer(flex: 3),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

class _PinEntryBody extends StatelessWidget {
  const _PinEntryBody({
    this.header,
    required this.title,
    this.subtitle,
    this.statusMessage,
    this.statusIsError = false,
    required this.pinLength,
    required this.filled,
    this.errorPulse = 0,
    this.dotsDimmed = false,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.padEnabled = true,
    this.busy = false,
    this.footer,
  });

  final Widget? header;
  final String title;
  final String? subtitle;
  final String? statusMessage;
  final bool statusIsError;
  final int pinLength;
  final int filled;
  final int errorPulse;
  final bool dotsDimmed;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool padEnabled;
  final bool busy;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: 12),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        PinDotsIndicator(
          length: pinLength,
          filled: filled,
          errorPulse: errorPulse,
          dimmed: dotsDimmed,
          hasError: statusIsError,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: statusMessage == null
              ? null
              : Text(
                  statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusIsError ? Colors.red : Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
        const SizedBox(height: 24),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        else
          PinPadWidget(
            enabled: padEnabled,
            onDigit: onDigit,
            onBackspace: onBackspace,
            onBiometric: onBiometric,
          ),
        if (footer != null) ...[
          const SizedBox(height: 20),
          footer!,
        ],
      ],
    );
  }
}

/// Max PIN length for pad input.
int get pinPadMaxLength => SecurityConstants.pinLength;

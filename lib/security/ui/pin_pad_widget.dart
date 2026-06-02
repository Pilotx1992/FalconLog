import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../security_constants.dart';

/// Layout metrics for a 3-column PIN pad and dot row (shared width).
@immutable
class PinPadMetrics {
  const PinPadMetrics({
    required this.keySize,
    required this.gap,
    required this.dotSize,
    required this.dotGap,
  });

  final double keySize;
  final double gap;
  final double dotSize;
  final double dotGap;

  double get rowWidth => keySize * 3 + gap * 2;

  static PinPadMetrics fromMaxWidth(double maxWidth, {bool compact = false}) {
    const minKey = 52.0;
    const maxKey = 72.0;
    final usable = maxWidth.clamp(220.0, 360.0);
    final gap = (usable * 0.045).clamp(10.0, 16.0);
    var keySize = ((usable - gap * 2) / 3).clamp(minKey, maxKey);
    if (compact) {
      keySize = (keySize * 0.92).clamp(minKey, maxKey);
    }
    final dotSize = (keySize * 0.52).clamp(28.0, 40.0);
    final dotGap = (gap * 0.35).clamp(6.0, 10.0);
    return PinPadMetrics(
      keySize: keySize,
      gap: compact ? gap * 0.9 : gap,
      dotSize: dotSize,
      dotGap: dotGap,
    );
  }
}

/// Numeric keypad for 4-digit PIN entry (circular keys, phone-style layout).
class PinPadWidget extends StatelessWidget {
  const PinPadWidget({
    super.key,
    required this.metrics,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.enabled = true,
  });

  final PinPadMetrics metrics;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SizedBox(
          width: m.rowWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KeyRow(
                keys: const ['1', '2', '3'],
                metrics: m,
                enabled: enabled,
                onDigit: onDigit,
              ),
              SizedBox(height: m.gap),
              _KeyRow(
                keys: const ['4', '5', '6'],
                metrics: m,
                enabled: enabled,
                onDigit: onDigit,
              ),
              SizedBox(height: m.gap),
              _KeyRow(
                keys: const ['7', '8', '9'],
                metrics: m,
                enabled: enabled,
                onDigit: onDigit,
              ),
              SizedBox(height: m.gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onBiometric != null)
                    _BiometricKey(
                      metrics: m,
                      enabled: enabled,
                      onPressed: onBiometric!,
                    )
                  else
                    SizedBox(width: m.keySize, height: m.keySize),
                  SizedBox(width: m.gap),
                  _DigitKey(
                    digit: '0',
                    metrics: m,
                    enabled: enabled,
                    onPressed: () => _tapDigit('0', onDigit),
                  ),
                  SizedBox(width: m.gap),
                  _DeleteKey(
                    metrics: m,
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
    required this.metrics,
    required this.enabled,
    required this.onDigit,
  });

  final List<String> keys;
  final PinPadMetrics metrics;
  final bool enabled;
  final ValueChanged<String> onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) SizedBox(width: metrics.gap),
          _DigitKey(
            digit: keys[i],
            metrics: metrics,
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
    required this.metrics,
    required this.enabled,
    required this.onPressed,
  });

  final String digit;
  final PinPadMetrics metrics;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fontSize = (metrics.keySize * 0.4).clamp(22.0, 28.0);

    return Material(
      color: const Color(0xFFF1F5F9),
      elevation: enabled ? 1 : 0,
      shadowColor: AppColors.brandPrimary.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: metrics.keySize,
          height: metrics.keySize,
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: enabled ? const Color(0xFF0F172A) : Colors.grey[500],
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
    required this.metrics,
    required this.enabled,
    required this.onPressed,
  });

  final PinPadMetrics metrics;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconSize = (metrics.keySize * 0.4).clamp(24.0, 30.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: metrics.keySize,
          height: metrics.keySize,
          child: Icon(
            Icons.backspace_outlined,
            size: iconSize,
            color: enabled ? AppColors.brandPrimary : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}

class _BiometricKey extends StatefulWidget {
  const _BiometricKey({
    required this.metrics,
    required this.enabled,
    required this.onPressed,
  });

  final PinPadMetrics metrics;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_BiometricKey> createState() => _BiometricKeyState();
}

class _BiometricKeyState extends State<_BiometricKey> {
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final iconSize = (widget.metrics.keySize * 0.46).clamp(26.0, 34.0);

    final icon = Icon(
      Icons.fingerprint,
      size: iconSize,
      color: widget.enabled ? AppColors.brandPrimary : Colors.grey[400],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.enabled ? widget.onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: widget.metrics.keySize,
          height: widget.metrics.keySize,
          child: reduceMotion
              ? icon
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
                  child: icon,
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
    required this.metrics,
    required this.length,
    this.filled = 0,
    this.errorPulse = 0,
    this.dimmed = false,
    this.hasError = false,
  });

  final PinPadMetrics metrics;
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
    final activeColor = hasError ? Colors.red : AppColors.brandPrimary;
    final m = widget.metrics;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: SizedBox(
        width: m.rowWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            final isFilled = !widget.dimmed && index < widget.filled;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              margin: EdgeInsets.symmetric(horizontal: m.dotGap / 2),
              width: m.dotSize,
              height: m.dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? activeColor : const Color(0xFFE2E8F0),
                border: Border.all(
                  color: hasError ? Colors.red : AppColors.brandPrimary,
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.28),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isFilled
                  ? Center(
                      child: Icon(
                        Icons.circle,
                        color: Colors.white,
                        size: m.dotSize * 0.3,
                      ),
                    )
                  : null,
            );
          }),
        ),
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
    this.compactVertical = false,
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

  /// Tighter vertical spacing for compact unlock heights.
  final bool compactVertical;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = MediaQuery.sizeOf(context).width;
        final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : screenW;
        const cardInset = 32.0;
        final metrics = PinPadMetrics.fromMaxWidth(
          maxW - cardInset,
          compact: compactVertical,
        );

        final card = _PinEntryCard(
          metrics: metrics,
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
          compactVertical: compactVertical,
        );

        final constrained = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: card,
        );

        if (centerContent) {
          return constrained;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const Spacer(flex: 2),
              constrained,
              const Spacer(flex: 3),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _PinEntryCard extends StatelessWidget {
  const _PinEntryCard({
    required this.metrics,
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
    this.compactVertical = false,
  });

  final PinPadMetrics metrics;
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
  final bool compactVertical;

  @override
  Widget build(BuildContext context) {
    final vPad = compactVertical ? 16.0 : 20.0;
    final hPad = 16.0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.brandPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
        child: _PinEntryBody(
          metrics: metrics,
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
          compactVertical: compactVertical,
        ),
      ),
    );
  }
}

class _PinEntryBody extends StatelessWidget {
  const _PinEntryBody({
    required this.metrics,
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
    this.compactVertical = false,
  });

  final PinPadMetrics metrics;
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
  final bool compactVertical;

  @override
  Widget build(BuildContext context) {
    final gapBeforeDots = compactVertical ? 14.0 : 20.0;
    final gapAfterDots = compactVertical ? 6.0 : 10.0;
    final gapBeforePad = compactVertical ? 12.0 : 16.0;
    final gapFooter = compactVertical ? 12.0 : 16.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          Center(child: header!),
          SizedBox(height: compactVertical ? 8 : 12),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: compactVertical ? 4 : 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
        ],
        SizedBox(height: gapBeforeDots),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PinDotsIndicator(
                metrics: metrics,
                length: pinLength,
                filled: filled,
                errorPulse: errorPulse,
                dimmed: dotsDimmed,
                hasError: statusIsError,
              ),
              SizedBox(height: gapAfterDots),
              SizedBox(
                height: 18,
                child: statusMessage == null
                    ? null
                    : Text(
                        statusMessage!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusIsError
                              ? Colors.red
                              : const Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              SizedBox(height: gapBeforePad),
              if (busy)
                SizedBox(
                  height: metrics.rowWidth * 0.85,
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else
                PinPadWidget(
                  metrics: metrics,
                  enabled: padEnabled,
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                  onBiometric: onBiometric,
                ),
            ],
          ),
        ),
        if (footer != null) ...[
          SizedBox(height: gapFooter),
          footer!,
        ],
      ],
    );
  }
}

/// Max PIN length for pad input.
int get pinPadMaxLength => SecurityConstants.pinLength;

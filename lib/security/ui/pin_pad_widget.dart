import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../security_constants.dart';

/// Numeric keypad for 4-digit PIN entry (circular keys, familiar phone layout).
class PinPadWidget extends StatelessWidget {
  const PinPadWidget({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  static const double _maxPadWidth = 300;
  static const double _keySize = 72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxPadWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _KeyRow(
                  keys: const ['1', '2', '3'],
                  keySize: _keySize,
                  scheme: scheme,
                  reduceMotion: reduceMotion,
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                ),
                const SizedBox(height: 16),
                _KeyRow(
                  keys: const ['4', '5', '6'],
                  keySize: _keySize,
                  scheme: scheme,
                  reduceMotion: reduceMotion,
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                ),
                const SizedBox(height: 16),
                _KeyRow(
                  keys: const ['7', '8', '9'],
                  keySize: _keySize,
                  scheme: scheme,
                  reduceMotion: reduceMotion,
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: _keySize, height: _keySize),
                    const SizedBox(width: 24),
                    _PadKey(
                      size: _keySize,
                      scheme: scheme,
                      reduceMotion: reduceMotion,
                      label: '0',
                      onPressed: () => _tapDigit(context, '0', onDigit),
                    ),
                    const SizedBox(width: 24),
                    _PadKey(
                      size: _keySize,
                      scheme: scheme,
                      reduceMotion: reduceMotion,
                      isBackspace: true,
                      onPressed: () => _tapBackspace(context, onBackspace),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _tapDigit(
    BuildContext context,
    String digit,
    ValueChanged<String> onDigit,
  ) {
    HapticFeedback.lightImpact();
    onDigit(digit);
  }

  static void _tapBackspace(BuildContext context, VoidCallback onBackspace) {
    HapticFeedback.selectionClick();
    onBackspace();
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.keys,
    required this.keySize,
    required this.scheme,
    required this.reduceMotion,
    required this.onDigit,
    required this.onBackspace,
  });

  final List<String> keys;
  final double keySize;
  final ColorScheme scheme;
  final bool reduceMotion;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
          _PadKey(
            size: keySize,
            scheme: scheme,
            reduceMotion: reduceMotion,
            label: keys[i],
            onPressed: () => PinPadWidget._tapDigit(context, keys[i], onDigit),
          ),
        ],
      ],
    );
  }
}

class _PadKey extends StatefulWidget {
  const _PadKey({
    required this.size,
    required this.scheme,
    required this.reduceMotion,
    required this.onPressed,
    this.label,
    this.isBackspace = false,
  });

  final double size;
  final ColorScheme scheme;
  final bool reduceMotion;
  final VoidCallback onPressed;
  final String? label;
  final bool isBackspace;

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.reduceMotion || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final scale = widget.reduceMotion
        ? 1.0
        : (_pressed ? 0.94 : 1.0);
    final borderColor = scheme.outline.withValues(alpha: 0.35);
    final fillColor = _pressed
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : Colors.transparent;

    return Semantics(
      button: true,
      label: widget.isBackspace ? 'Delete last digit' : 'Digit ${widget.label}',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Material(
            color: fillColor,
            shape: CircleBorder(side: BorderSide(color: borderColor, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onPressed,
              onHighlightChanged: _setPressed,
              splashColor: scheme.primary.withValues(alpha: 0.12),
              highlightColor: scheme.primary.withValues(alpha: 0.08),
              child: Center(
                child: widget.isBackspace
                    ? Icon(
                        Icons.backspace_outlined,
                        size: 26,
                        color: scheme.onSurface.withValues(alpha: 0.85),
                      )
                    : Text(
                        widget.label!,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                          height: 1,
                        ),
                      ),
              ),
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
  });

  final int length;
  final int filled;

  /// Increment to trigger a horizontal shake (e.g. on wrong PIN).
  final int errorPulse;
  final bool dimmed;

  @override
  State<PinDotsIndicator> createState() => _PinDotsIndicatorState();
}

class _PinDotsIndicatorState extends State<PinDotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7, end: 7), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PinDotsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorPulse != oldWidget.errorPulse && widget.errorPulse > 0) {
      if (MediaQuery.disableAnimationsOf(context)) return;
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
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final filledColor =
        widget.dimmed ? scheme.outlineVariant : AppColors.brandPrimary;
    final emptyBorder = scheme.outline.withValues(alpha: 0.4);

    final dots = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (i) {
        final isFilled = !widget.dimmed && i < widget.filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: AnimatedContainer(
            duration: animDuration,
            curve: Curves.easeOutCubic,
            width: isFilled ? 14 : 12,
            height: isFilled ? 14 : 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? filledColor : Colors.transparent,
              border: Border.all(
                color: isFilled ? filledColor : emptyBorder,
                width: isFilled ? 0 : 2,
              ),
            ),
          ),
        );
      }),
    );

    return AnimatedBuilder(
      animation: _shakeOffset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeOffset.value, 0),
          child: child,
        );
      },
      child: dots,
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
  final bool padEnabled;
  final bool busy;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          if (header != null) ...[
            header!,
            const SizedBox(height: 20),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 28),
          PinDotsIndicator(
            length: pinLength,
            filled: filled,
            errorPulse: errorPulse,
            dimmed: dotsDimmed,
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: statusMessage == null
                ? const SizedBox(height: 22, key: ValueKey('pin-status-empty'))
                : Text(
                    statusMessage!,
                    key: ValueKey('pin-status-$statusMessage'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: statusIsError ? scheme.error : scheme.onSurfaceVariant,
                      fontWeight:
                          statusIsError ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
          ),
          const Spacer(flex: 3),
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
            ),
          if (footer != null) ...[
            const SizedBox(height: 20),
            footer!,
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Max PIN length for pad input.
int get pinPadMaxLength => SecurityConstants.pinLength;

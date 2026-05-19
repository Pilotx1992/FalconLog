import 'package:flutter/material.dart';

import '../security_constants.dart';

/// Numeric keypad for 4-digit PIN entry.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: keys.length,
          itemBuilder: (context, index) {
            final key = keys[index];
            if (key.isEmpty) return const SizedBox.shrink();

            if (key == '⌫') {
              return _PadButton(
                label: key,
                onPressed: onBackspace,
                foreground: scheme.onSurface,
              );
            }

            return _PadButton(
              label: key,
              onPressed: () => onDigit(key),
              foreground: scheme.onSurface,
            );
          },
        ),
      ),
    );
  }
}

class PinDotsIndicator extends StatelessWidget {
  const PinDotsIndicator({
    super.key,
    required this.length,
    this.filled = 0,
  });

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? scheme.primary : scheme.outlineVariant,
          ),
        );
      }),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.label,
    required this.onPressed,
    required this.foreground,
  });

  final String label;
  final VoidCallback onPressed;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: label == '⌫' ? 22 : 28,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Max PIN length for pad input.
int get pinPadMaxLength => SecurityConstants.pinLength;

import '../security_constants.dart';

/// Result of a PIN validation check.
class PinValidationResult {
  final bool isValid;
  final String? errorMessage;

  const PinValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const PinValidationResult.invalid(this.errorMessage) : isValid = false;
}

/// PIN format and strength validator.
///
/// Rejects weak PINs (repeated digits, ascending/descending sequences)
/// with a user‑friendly error message — never throws.
class PinValidator {
  PinValidator._();

  /// Validate [pin] for format and strength.
  static PinValidationResult validate(String pin) {
    // ── Format checks ──
    if (pin.length != SecurityConstants.pinLength) {
      return PinValidationResult.invalid(
        'PIN must be exactly ${SecurityConstants.pinLength} digits',
      );
    }

    if (!_isNumericOnly(pin)) {
      return const PinValidationResult.invalid('PIN must contain only digits');
    }

    // ── Strength checks ──
    if (_isAllSameDigit(pin)) {
      return const PinValidationResult.invalid(
        'PIN is too weak — all digits are the same',
      );
    }

    if (_isStrictSequence(pin)) {
      return const PinValidationResult.invalid(
        'PIN is too weak — sequential digits',
      );
    }

    return const PinValidationResult.valid();
  }

  /// Human‑readable strength label (for UI indicators).
  static String strengthLabel(String pin) {
    if (pin.length != SecurityConstants.pinLength) return 'Invalid';
    if (_isAllSameDigit(pin)) return 'Very Weak';
    if (_isStrictSequence(pin)) return 'Weak';
    return 'Good';
  }

  // ── Internals ───────────────────────────────────────────────────────

  static bool _isNumericOnly(String s) => RegExp(r'^[0-9]+$').hasMatch(s);

  /// Every digit identical: 0000, 1111, …, 9999.
  static bool _isAllSameDigit(String pin) => pin.split('').toSet().length == 1;

  /// Strictly ascending (1234, 2345) or descending (4321, 9876).
  static bool _isStrictSequence(String pin) {
    final digits = pin.codeUnits.map((c) => c - 48).toList(); // '0' == 48

    var ascending = true;
    var descending = true;
    for (var i = 0; i < digits.length - 1; i++) {
      if (digits[i + 1] != digits[i] + 1) ascending = false;
      if (digits[i + 1] != digits[i] - 1) descending = false;
    }

    return ascending || descending;
  }
}

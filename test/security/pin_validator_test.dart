import 'package:falconlog/security/utils/pin_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinValidator', () {
    test('accepts valid non-weak PIN', () {
      expect(PinValidator.validate('2580').isValid, isTrue);
    });

    test('rejects wrong length', () {
      expect(PinValidator.validate('123').isValid, isFalse);
    });

    test('rejects non-numeric', () {
      expect(PinValidator.validate('12a4').isValid, isFalse);
    });

    test('rejects all same digit', () {
      expect(PinValidator.validate('0000').isValid, isFalse);
      expect(PinValidator.validate('9999').isValid, isFalse);
    });

    test('rejects known weak PINs', () {
      for (final pin in ['1234', '4321', '0123', '9876']) {
        expect(PinValidator.validate(pin).isValid, isFalse);
      }
    });

    test('rejects ascending and descending sequences', () {
      expect(PinValidator.validate('2345').isValid, isFalse);
      expect(PinValidator.validate('5432').isValid, isFalse);
    });
  });
}

import 'package:falconlog/security/utils/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinHasher', () {
    test('verifyPin succeeds for correct PIN', () {
      final salt = PinHasher.generateSalt();
      final hash = PinHasher.hashPin('2580', salt);
      expect(PinHasher.verifyPin('2580', salt, hash), isTrue);
    });

    test('verifyPin fails for wrong PIN', () {
      final salt = PinHasher.generateSalt();
      final hash = PinHasher.hashPin('2580', salt);
      expect(PinHasher.verifyPin('2581', salt, hash), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/auth/auth_validators.dart';

void main() {
  group('validateEmail', () {
    test('rejects empty', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
    });

    test('rejects invalid format', () {
      expect(validateEmail('not-an-email'), isNotNull);
    });

    test('accepts valid email', () {
      expect(validateEmail('pilot@example.com'), isNull);
    });
  });

  group('validateLoginPassword', () {
    test('rejects empty', () {
      expect(validateLoginPassword(''), isNotNull);
    });

    test('accepts any non-empty password', () {
      expect(validateLoginPassword('x'), isNull);
    });
  });

  group('validateRegisterPassword', () {
    test('rejects weak password', () {
      expect(validateRegisterPassword('12345'), isNotNull);
    });

    test('accepts 6+ characters', () {
      expect(validateRegisterPassword('123456'), isNull);
    });
  });

  group('validateConfirmPassword', () {
    test('rejects mismatch', () {
      expect(
        validateConfirmPassword('abc', 'xyz'),
        'Passwords do not match.',
      );
    });

    test('accepts match', () {
      expect(validateConfirmPassword('secret', 'secret'), isNull);
    });
  });
}

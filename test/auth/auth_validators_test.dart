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
      expect(validateLoginPassword(null), isNotNull);
    });

    test('accepts non-empty password including spaces', () {
      expect(validateLoginPassword('x'), isNull);
      expect(validateLoginPassword('  my pass  '), isNull);
    });
  });

  group('validateRegisterPassword', () {
    test('rejects weak password', () {
      expect(validateRegisterPassword('12345'), isNotNull);
    });

    test('rejects whitespace-only password', () {
      expect(validateRegisterPassword('      '), isNotNull);
    });

    test('accepts 6+ characters', () {
      expect(validateRegisterPassword('123456'), isNull);
    });
  });

  group('validateDisplayName', () {
    test('rejects control characters', () {
      expect(validateDisplayName('Jo\x00hn'), isNotNull);
      expect(validateDisplayName('Test\nName'), isNotNull);
    });

    test('accepts trimmed name with at least 2 characters', () {
      expect(validateDisplayName('  Jo  '), isNull);
    });

    test('rejects name over max length', () {
      expect(validateDisplayName('a' * 101), isNotNull);
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

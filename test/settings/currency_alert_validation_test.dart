import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/settings/currency_alert_settings.dart';

void main() {
  group('validateCurrencyAlertDays', () {
    test('empty is invalid', () {
      expect(validateCurrencyAlertDays(''), isNotNull);
      expect(validateCurrencyAlertDays(null), isNotNull);
      expect(validateCurrencyAlertDays('   '), isNotNull);
    });

    test('zero is invalid', () {
      expect(validateCurrencyAlertDays('0'), isNotNull);
    });

    test('negative sign rejected', () {
      expect(validateCurrencyAlertDays('-1'), isNotNull);
    });

    test('non-numeric rejected', () {
      expect(validateCurrencyAlertDays('abc'), isNotNull);
      expect(validateCurrencyAlertDays('15.5'), isNotNull);
    });

    test('above maximum rejected', () {
      expect(validateCurrencyAlertDays('366'), isNotNull);
    });

    test('1 and 365 are valid', () {
      expect(validateCurrencyAlertDays('1'), isNull);
      expect(validateCurrencyAlertDays('365'), isNull);
      expect(parseCurrencyAlertDays('21'), 21);
    });
  });
}

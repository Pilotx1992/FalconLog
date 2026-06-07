import 'package:falconlog/reports/domain/flight_log_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDurationHhMm', () {
    test('formats zero hours', () {
      expect(formatDurationHhMm(0), '00:00');
    });

    test('formats fractional hours as HH:MM', () {
      expect(formatDurationHhMm(2.5), '02:30');
    });

    test('formats whole hours', () {
      expect(formatDurationHhMm(3), '03:00');
    });

    test('rounds minutes from fractional part', () {
      expect(formatDurationHhMm(1.25), '01:15');
    });
  });
}

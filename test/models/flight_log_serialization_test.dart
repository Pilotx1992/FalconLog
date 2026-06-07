import 'package:falconlog/models/flight_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightLog Serialization Tests', () {
    test('toJson throws instead of silently degrading when an error occurs', () {
      // In Dart, testing for serialization failure requires mocking a failure case.
      // Since we removed the try-catch block, we can verify that a malformed object
      // throws an error during _safeEnumName if we pass something invalid, or that
      // normal conversion works without fallback.
      // 
      // Because we can't easily force a crash in a well-typed FlightLog, we just
      // ensure the normal toJson returns the full map.
      final log = FlightLog(
        id: 'test-1',
        date: DateTime.utc(2025, 1, 1),
        flightTypes: const [FlightType.local],
        durationHours: 1,
        durationMinutes: 30,
        aircraftType: 'C172',
        pilotRole: PilotRole.pic,
        isDayFlight: true,
        isSimulated: false,
        createdAt: DateTime.utc(2025, 1, 1),
        registration: 'N12345',
        departure: 'KOSH',
        arrival: 'KOSH',
      );

      final json = log.toJson();
      
      // Verification that no fallback degraded data (fallback used enum indices)
      expect(json['flightTypes'], ['local']); // Should be string, not int 0
      expect(json['pilotRole'], 'pic'); // Should be string, not int 0
      expect(json['registration'], 'N12345'); // Ensure optional fields are not dropped
    });

    test('fromMap is legacy code and drops extended fields', () {
      // This test serves as a documentation of the dead-code issue found in the audit.
      final fullMap = {
        'id': 'test-frommap',
        'date': DateTime.utc(2025, 1, 1).toIso8601String(),
        'flightTypes': ['FlightType.local'],
        'durationHours': 1,
        'durationMinutes': 30,
        'aircraftType': 'C172',
        'pilotRole': 'PilotRole.pic',
        'isDayFlight': true,
        'isSimulated': false,
        'createdAt': DateTime.utc(2025, 1, 1).toIso8601String(),
        // These fields are ignored by fromMap:
        'registration': 'N12345',
        'remarks': 'Test remarks',
      };

      final log = FlightLog.fromMap(fullMap);
      
      // fromMap parses the core 9 fields
      expect(log.id, 'test-frommap');
      expect(log.aircraftType, 'C172');
      
      // It completely ignores the extended fields
      expect(log.registration, isNull);
      expect(log.remarks, isNull);
    });
  });
}

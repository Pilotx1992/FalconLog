import 'package:falconlog/models/flight_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flight_log_from_json_accepts_legacy_minimal_payload', () {
    final restored = FlightLog.fromJson({
      'id': 'legacy-flight-1',
      'date': '2024-01-15T06:30:00.000Z',
      'flightTypes': ['FlightType.local'],
      'durationHours': 1,
      'durationMinutes': 25,
      'aircraftType': 'T-6',
      'pilotRole': 'PilotRole.pic',
    });

    expect(restored.id, 'legacy-flight-1');
    expect(restored.date, DateTime.utc(2024, 1, 15, 6, 30));
    expect(restored.flightTypes, const [FlightType.local]);
    expect(restored.durationHours, 1);
    expect(restored.durationMinutes, 25);
    expect(restored.aircraftType, 'T-6');
    expect(restored.pilotRole, PilotRole.pic);
    expect(restored.isDayFlight, isTrue);
    expect(restored.isSimulated, isFalse);
    expect(restored.createdAt, isA<DateTime>());
    expect(restored.dateUpdated, isNull);
    expect(restored.registration, isNull);
    expect(restored.departure, isNull);
    expect(restored.arrival, isNull);
    expect(restored.flightTime, isNull);
    expect(restored.picTime, isNull);
    expect(restored.sicTime, isNull);
    expect(restored.nightTime, isNull);
    expect(restored.ifrTime, isNull);
    expect(restored.crossCountry, isNull);
    expect(restored.dayLandings, isNull);
    expect(restored.nightLandings, isNull);
    expect(restored.remarks, isNull);
    expect(restored.updatedAt, isNull);
    expect(restored.safeFlightTime, 0);
    expect(restored.safeDayLandings, 0);
  });

  test('flight_log_from_json_handles_null_optional_fields', () {
    final restored = FlightLog.fromJson({
      'id': 'legacy-null-optionals',
      'date': '2024-02-01T00:00:00.000Z',
      'flightTypes': ['local'],
      'durationHours': 0,
      'durationMinutes': 30,
      'aircraftType': 'UH-60',
      'pilotRole': 'pic',
      'isDayFlight': true,
      'isSimulated': false,
      'createdAt': '2024-02-01T00:00:00.000Z',
      'registration': null,
      'departure': null,
      'arrival': null,
      'remarks': null,
      'updatedAt': null,
    });

    expect(restored.registration, isNull);
    expect(restored.departure, isNull);
    expect(restored.arrival, isNull);
    expect(restored.remarks, isNull);
    expect(restored.updatedAt, isNull);
  });
}

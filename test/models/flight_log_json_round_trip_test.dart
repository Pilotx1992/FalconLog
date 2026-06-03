import 'package:falconlog/models/flight_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flight_log_json_round_trip_preserves_extended_fields', () {
    final original = FlightLog(
      id: 'flight-full-1',
      date: DateTime.utc(2025, 6, 1, 8, 30),
      flightTypes: const [
        FlightType.local,
        FlightType.mission,
        FlightType.lowLevel,
      ],
      durationHours: 2,
      durationMinutes: 45,
      aircraftType: 'AH-64E',
      pilotRole: PilotRole.ip,
      isDayFlight: false,
      isSimulated: true,
      createdAt: DateTime.utc(2025, 5, 20, 10, 11, 12),
      dateUpdated: DateTime.utc(2025, 5, 21, 9, 8, 7),
      registration: 'EG-1234',
      departure: 'HECA',
      arrival: 'HEGN',
      flightTime: 2.75,
      picTime: 1.5,
      sicTime: 1.25,
      nightTime: 0.8,
      ifrTime: 0.4,
      crossCountry: 1.1,
      dayLandings: 2,
      nightLandings: 1,
      remarks: 'NVG currency check with tactical arrival.',
      updatedAt: DateTime.utc(2025, 5, 22, 12, 13, 14),
    );

    final restored = FlightLog.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.date, original.date);
    expect(restored.flightTypes, original.flightTypes);
    expect(restored.durationHours, original.durationHours);
    expect(restored.durationMinutes, original.durationMinutes);
    expect(restored.aircraftType, original.aircraftType);
    expect(restored.pilotRole, original.pilotRole);
    expect(restored.isDayFlight, original.isDayFlight);
    expect(restored.isSimulated, original.isSimulated);
    expect(restored.createdAt, original.createdAt);
    expect(restored.dateUpdated, original.dateUpdated);
    expect(restored.registration, original.registration);
    expect(restored.departure, original.departure);
    expect(restored.arrival, original.arrival);
    expect(restored.flightTime, original.flightTime);
    expect(restored.picTime, original.picTime);
    expect(restored.sicTime, original.sicTime);
    expect(restored.nightTime, original.nightTime);
    expect(restored.ifrTime, original.ifrTime);
    expect(restored.crossCountry, original.crossCountry);
    expect(restored.dayLandings, original.dayLandings);
    expect(restored.nightLandings, original.nightLandings);
    expect(restored.remarks, original.remarks);
    expect(restored.updatedAt, original.updatedAt);
  });
}

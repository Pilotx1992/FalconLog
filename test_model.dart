import 'lib/models/flight_log.dart';

void main() {
  // Test if FlightLog.fromJson works
  final testJson = {
    'id': 'test123',
    'date': '2025-07-22T10:00:00Z',
    'flightTypes': ['local'],
    'durationHours': 1,
    'durationMinutes': 30,
    'aircraftType': 'F-16',
    'pilotRole': 'PIC',
    'isDayFlight': true,
    'isSimulated': false,
    'createdAt': '2025-07-22T10:00:00Z',
  };
  
  final log = FlightLog.fromJson(testJson);
  print('Flight log created: ${log.id}');
}

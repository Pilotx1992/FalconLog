import 'dart:math';
import '../models/flight_log.dart';

/// Service for generating sample flight logs and managing flight data
class SampleFlightsService {
  static final Random _random = Random();

  // Sample data arrays
  static const List<String> _aircraftTypes = [
    'F-16C Block 50',
    'F-16C Block 52',
    'F-16D Block 50',
    'F-16D Block 52',
    'F-16AM',
    'F-16BM',
    'F-16A',
    'F-16B',
    'F-16C Block 30',
    'F-16C Block 40',
    'F-16C Block 42',
    'F-16C Block 50+',
    'F-16C Block 52+',
    'F-16D Block 30',
    'F-16D Block 40',
    'F-16D Block 42',
    'F-16D Block 50+',
    'F-16D Block 52+',
  ];

  static const List<String> _registrations = [
    '88-0001', '88-0002', '88-0003', '88-0004', '88-0005',
    '88-0101', '88-0102', '88-0103', '88-0104', '88-0105',
    '88-0201', '88-0202', '88-0203', '88-0204', '88-0205',
    '89-0001', '89-0002', '89-0003', '89-0004', '89-0005',
    '90-0001', '90-0002', '90-0003', '90-0004', '90-0005',
    '91-0001', '91-0002', '91-0003', '91-0004', '91-0005',
  ];

  static const List<String> _departures = [
    'Aviano AB', 'Spangdahlem AB', 'Ramstein AB', 'Lakenheath AB',
    'Mildenhall AB', 'Incirlik AB', 'Al Dhafra AB', 'Kunsan AB',
    'Osan AB', 'Misawa AB', 'Kadena AB', 'Luke AFB',
    'Hill AFB', 'Shaw AFB', 'Moody AFB', 'Holloman AFB',
    'Nellis AFB', 'Tyndall AFB', 'Eglin AFB', 'MacDill AFB',
  ];

  static const List<String> _arrivals = [
    'Aviano AB', 'Spangdahlem AB', 'Ramstein AB', 'Lakenheath AB',
    'Mildenhall AB', 'Incirlik AB', 'Al Dhafra AB', 'Kunsan AB',
    'Osan AB', 'Misawa AB', 'Kadena AB', 'Luke AFB',
    'Hill AFB', 'Shaw AFB', 'Moody AFB', 'Holloman AFB',
    'Nellis AFB', 'Tyndall AFB', 'Eglin AFB', 'MacDill AFB',
  ];

  static const List<String> _remarks = [
    'Standard training mission',
    'Combat training exercise',
    'Formation flight training',
    'Navigation training',
    'Weapons training',
    'Air-to-air combat training',
    'Air-to-ground training',
    'Low level navigation',
    'Cross country flight',
    'Currency check flight',
    'Instructor pilot training',
    'Mission qualification training',
    'Combat readiness training',
    'Tactical training mission',
    'Defensive counter air training',
    'Offensive counter air training',
    'Close air support training',
    'Interdiction training',
    'Reconnaissance training',
    'Electronic warfare training',
    'Night vision goggle training',
    'Instrument flight training',
    'Weather avoidance training',
    'Emergency procedures training',
    'Systems training',
  ];

  /// Generate 100 diverse sample flight logs
  static List<FlightLog> generateSampleFlights() {
    final flights = <FlightLog>[];
    final now = DateTime.now();

    for (int i = 0; i < 100; i++) {
      // Generate random date within the last 2 years
      final daysAgo = _random.nextInt(730); // 2 years
      final flightDate = now.subtract(Duration(days: daysAgo));

      // Generate random flight types (1-3 types per flight)
      final numTypes = _random.nextInt(3) + 1;
      final flightTypes = <FlightType>[];
      for (int j = 0; j < numTypes; j++) {
        final type = FlightType.values[_random.nextInt(FlightType.values.length)];
        if (!flightTypes.contains(type)) {
          flightTypes.add(type);
        }
      }

      // Generate random duration (30 minutes to 3 hours)
      final totalMinutes = 30 + _random.nextInt(150); // 30-180 minutes
      final durationHours = totalMinutes ~/ 60;
      final durationMinutes = totalMinutes % 60;

      // Generate random aircraft type
      final aircraftType = _aircraftTypes[_random.nextInt(_aircraftTypes.length)];

      // Generate random pilot role
      final pilotRole = PilotRole.values[_random.nextInt(PilotRole.values.length)];

      // Generate random day/night flight (80% day, 20% night)
      final isDayFlight = _random.nextDouble() < 0.8;

      // Generate random simulated flight (10% simulated)
      final isSimulated = _random.nextDouble() < 0.1;

      // Generate random registration
      final registration = _registrations[_random.nextInt(_registrations.length)];

      // Generate random departure and arrival (can be same for local flights)
      final departure = _departures[_random.nextInt(_departures.length)];
      final arrival = flightTypes.contains(FlightType.local) 
          ? departure 
          : _arrivals[_random.nextInt(_arrivals.length)];

      // Generate flight time (same as duration for simplicity)
      final flightTime = durationHours + (durationMinutes / 60.0);

      // Generate PIC/SIC time based on pilot role
      double picTime = 0.0;
      double sicTime = 0.0;
      switch (pilotRole) {
        case PilotRole.pic:
          picTime = flightTime;
          break;
        case PilotRole.ip:
          picTime = flightTime * 0.7; // IP gets most PIC time
          sicTime = flightTime * 0.3;
          break;
        case PilotRole.mtp:
          picTime = flightTime * 0.5;
          sicTime = flightTime * 0.5;
          break;
        case PilotRole.cpgGunner:
        case PilotRole.wzo:
          sicTime = flightTime;
          break;
      }

      // Generate night time (if night flight)
      final nightTime = isDayFlight ? 0.0 : flightTime;

      // Generate IFR time (20% of flights have IFR time)
      final ifrTime = _random.nextDouble() < 0.2 ? flightTime * _random.nextDouble() : 0.0;

      // Generate cross country time (if not local flight)
      final crossCountry = flightTypes.contains(FlightType.local) 
          ? 0.0 
          : flightTime * (0.3 + _random.nextDouble() * 0.7);

      // Generate landings
      final dayLandings = isDayFlight ? 1 + _random.nextInt(3) : 0;
      final nightLandings = isDayFlight ? 0 : 1 + _random.nextInt(2);

      // Generate random remarks
      final remarks = _remarks[_random.nextInt(_remarks.length)];

      final flight = FlightLog(
        date: flightDate,
        flightTypes: flightTypes,
        durationHours: durationHours,
        durationMinutes: durationMinutes,
        aircraftType: aircraftType,
        pilotRole: pilotRole,
        isDayFlight: isDayFlight,
        isSimulated: isSimulated,
        registration: registration,
        departure: departure,
        arrival: arrival,
        flightTime: flightTime,
        picTime: picTime,
        sicTime: sicTime,
        nightTime: nightTime,
        ifrTime: ifrTime,
        crossCountry: crossCountry,
        dayLandings: dayLandings,
        nightLandings: nightLandings,
        remarks: remarks,
      );

      flights.add(flight);
    }

    // Sort by date (newest first)
    flights.sort((a, b) => b.date.compareTo(a.date));

    return flights;
  }

  /// Generate a single sample flight log
  static FlightLog generateSingleFlight() {
    return generateSampleFlights().first;
  }

  /// Get flight statistics from a list of flights
  static Map<String, dynamic> getFlightStatistics(List<FlightLog> flights) {
    if (flights.isEmpty) {
      return {
        'totalFlights': 0,
        'totalHours': 0.0,
        'dayFlights': 0,
        'nightFlights': 0,
        'simulatedFlights': 0,
        'totalPicTime': 0.0,
        'totalSicTime': 0.0,
        'totalNightTime': 0.0,
        'totalIfrTime': 0.0,
        'totalCrossCountry': 0.0,
        'totalDayLandings': 0,
        'totalNightLandings': 0,
        'aircraftTypes': <String>{},
        'pilotRoles': <PilotRole>{},
        'flightTypes': <FlightType>{},
      };
    }

    double totalHours = 0.0;
    int dayFlights = 0;
    int nightFlights = 0;
    int simulatedFlights = 0;
    double totalPicTime = 0.0;
    double totalSicTime = 0.0;
    double totalNightTime = 0.0;
    double totalIfrTime = 0.0;
    double totalCrossCountry = 0.0;
    int totalDayLandings = 0;
    int totalNightLandings = 0;
    final aircraftTypes = <String>{};
    final pilotRoles = <PilotRole>{};
    final flightTypes = <FlightType>{};

    for (final flight in flights) {
      final flightHours = flight.durationHours + (flight.durationMinutes / 60.0);
      totalHours += flightHours;

      if (flight.isDayFlight) {
        dayFlights++;
      } else {
        nightFlights++;
      }

      if (flight.isSimulated) {
        simulatedFlights++;
      }

      totalPicTime += flight.safePicTime;
      totalSicTime += flight.safeSicTime;
      totalNightTime += flight.safeNightTime;
      totalIfrTime += flight.safeIfrTime;
      totalCrossCountry += flight.safeCrossCountry;
      totalDayLandings += flight.safeDayLandings;
      totalNightLandings += flight.safeNightLandings;

      aircraftTypes.add(flight.aircraftType);
      pilotRoles.add(flight.pilotRole);
      flightTypes.addAll(flight.flightTypes);
    }

    return {
      'totalFlights': flights.length,
      'totalHours': totalHours,
      'dayFlights': dayFlights,
      'nightFlights': nightFlights,
      'simulatedFlights': simulatedFlights,
      'totalPicTime': totalPicTime,
      'totalSicTime': totalSicTime,
      'totalNightTime': totalNightTime,
      'totalIfrTime': totalIfrTime,
      'totalCrossCountry': totalCrossCountry,
      'totalDayLandings': totalDayLandings,
      'totalNightLandings': totalNightLandings,
      'aircraftTypes': aircraftTypes,
      'pilotRoles': pilotRoles,
      'flightTypes': flightTypes,
    };
  }
}


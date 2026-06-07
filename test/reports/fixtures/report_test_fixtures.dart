import 'package:falconlog/models/flight_log.dart';

FlightLog buildTestLog({
  String? id,
  required DateTime date,
  List<FlightType>? flightTypes,
  int durationHours = 1,
  int durationMinutes = 0,
  String aircraftType = 'AH-64D',
  PilotRole pilotRole = PilotRole.pic,
  bool isDayFlight = true,
  bool isSimulated = false,
  String? registration,
  String? departure,
  String? arrival,
  String? remarks,
  int? dayLandings,
  int? nightLandings,
  DateTime? createdAt,
}) {
  return FlightLog(
    id: id ?? 'log-${date.millisecondsSinceEpoch}',
    date: date,
    flightTypes: flightTypes ?? [FlightType.local],
    durationHours: durationHours,
    durationMinutes: durationMinutes,
    aircraftType: aircraftType,
    pilotRole: pilotRole,
    isDayFlight: isDayFlight,
    isSimulated: isSimulated,
    registration: registration,
    departure: departure,
    arrival: arrival,
    remarks: remarks,
    dayLandings: dayLandings,
    nightLandings: nightLandings,
    createdAt: createdAt ?? DateTime(2020, 1, 1),
  );
}

List<FlightLog> buildLogs(int count, {DateTime? startDate}) {
  final base = startDate ?? DateTime(2026, 1, 1);
  return List.generate(count, (i) {
    return buildTestLog(
      id: 'stress-$i',
      date: base.add(Duration(days: i % 365)),
      flightTypes: [
        FlightType.values[i % FlightType.values.length],
        if (i % 3 == 0) FlightType.mission,
      ],
      durationHours: 1 + (i % 3),
      durationMinutes: (i * 7) % 60,
      aircraftType: 'Type-${i % 20}',
      pilotRole: PilotRole.values[i % PilotRole.values.length],
      isDayFlight: i.isEven,
      isSimulated: i % 5 == 0,
      registration: 'REG-${i % 50}',
      remarks: i % 10 == 0 ? 'Remark ' * 50 : null,
      dayLandings: i % 4 == 0 ? 1 : 0,
      nightLandings: i % 7 == 0 ? 1 : 0,
    );
  });
}

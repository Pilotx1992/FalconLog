import 'package:intl/intl.dart';

import '../../models/flight_log.dart';
import '../../notifications/domain/currency_daily_notification.dart';
import '../domain/aircraft_breakdown.dart';
import '../domain/flight_condition_breakdown.dart';
import '../domain/flight_log_duration.dart';
import '../domain/flight_log_labels.dart';
import '../domain/flight_mode_breakdown.dart';
import '../domain/flight_report_summary.dart';
import '../domain/flight_type_breakdown.dart';
import '../domain/period_bucket.dart';
import '../domain/pilot_role_breakdown.dart';
import '../domain/report_date_range.dart';

class FlightReportService {
  const FlightReportService();

  List<FlightLog> filterByDateRange(
    List<FlightLog> logs,
    ReportDateRange range,
  ) {
    final filtered = logs.where((log) => range.contains(log.date)).toList();
    filtered.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return filtered;
  }

  FlightReportSummary buildSummary(List<FlightLog> inRange, ReportDateRange range) {
    if (inRange.isEmpty) return FlightReportSummary.empty(range);

    double totalHours = 0;
    double dayHours = 0;
    double nightHours = 0;
    var totalLandings = 0;
    final aircraftTypes = <String>{};
    DateTime? first;
    DateTime? last;

    for (final log in inRange) {
      final h = durationInHours(log);
      totalHours += h;
      if (log.isDayFlight) {
        dayHours += h;
      } else {
        nightHours += h;
      }
      totalLandings += log.safeDayLandings + log.safeNightLandings;
      if (log.aircraftType.trim().isNotEmpty) {
        aircraftTypes.add(log.aircraftType.trim());
      }
      final d = dateOnly(log.date);
      if (first == null || d.isBefore(first)) first = d;
      if (last == null || d.isAfter(last)) last = d;
    }

    return FlightReportSummary(
      range: range,
      totalFlights: inRange.length,
      totalHours: totalHours,
      dayHours: dayHours,
      nightHours: nightHours,
      totalLandings: totalLandings,
      aircraftCount: aircraftTypes.length,
      firstFlightDate: first,
      lastFlightDate: last,
      isEmpty: false,
    );
  }

  FlightTypeBreakdown buildFlightTypeBreakdown(List<FlightLog> inRange) {
    if (inRange.isEmpty) return FlightTypeBreakdown.empty;

    final counts = <String, int>{};
    final hours = <String, double>{};
    final day = <String, double>{};
    final night = <String, double>{};

    for (final log in inRange) {
      final types = log.flightTypes;
      if (types.isEmpty) continue;
      final h = durationInHours(log);
      final split = h / types.length;
      final dayPart = log.isDayFlight ? split : 0.0;
      final nightPart = log.isDayFlight ? 0.0 : split;

      for (final t in types) {
        final label = flightTypeLabel(t);
        counts[label] = (counts[label] ?? 0) + 1;
        hours[label] = (hours[label] ?? 0) + split;
        day[label] = (day[label] ?? 0) + dayPart;
        night[label] = (night[label] ?? 0) + nightPart;
      }
    }

    final totalTagFlights =
        counts.values.fold<int>(0, (sum, c) => sum + c);
    final totalHours = hours.values.fold<double>(0, (sum, h) => sum + h);

    final rows = counts.entries.map((e) {
      final label = e.key;
      return FlightTypeBreakdownRow(
        label: label,
        flights: e.value,
        hours: hours[label] ?? 0,
        dayHours: day[label] ?? 0,
        nightHours: night[label] ?? 0,
        percentOfFlights: totalTagFlights == 0
            ? 0
            : (e.value * 100.0 / totalTagFlights),
      );
    }).toList()
      ..sort((a, b) => b.hours.compareTo(a.hours));

    return FlightTypeBreakdown(
      rows: rows,
      totalFlights: inRange.length,
      totalHours: totalHours,
    );
  }

  PilotRoleBreakdown buildPilotRoleBreakdown(List<FlightLog> inRange) {
    if (inRange.isEmpty) return PilotRoleBreakdown.empty;

    final flights = <String, int>{};
    final hours = <String, double>{};
    final day = <String, double>{};
    final night = <String, double>{};

    for (final log in inRange) {
      final label = pilotRoleLabel(log.pilotRole);
      final h = durationInHours(log);
      flights[label] = (flights[label] ?? 0) + 1;
      hours[label] = (hours[label] ?? 0) + h;
      if (log.isDayFlight) {
        day[label] = (day[label] ?? 0) + h;
      } else {
        night[label] = (night[label] ?? 0) + h;
      }
    }

    final rows = flights.entries
        .map((e) => PilotRoleBreakdownRow(
              label: e.key,
              flights: e.value,
              hours: hours[e.key] ?? 0,
              dayHours: day[e.key] ?? 0,
              nightHours: night[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.hours.compareTo(a.hours));

    return PilotRoleBreakdown(rows: rows);
  }

  FlightConditionBreakdown buildFlightConditionBreakdown(
    List<FlightLog> inRange,
  ) {
    if (inRange.isEmpty) return FlightConditionBreakdown.empty;

    final flights = <String, int>{'Day': 0, 'Night': 0};
    final hours = <String, double>{'Day': 0, 'Night': 0};

    for (final log in inRange) {
      final label = flightConditionLabel(log.isDayFlight);
      final h = durationInHours(log);
      flights[label] = (flights[label] ?? 0) + 1;
      hours[label] = (hours[label] ?? 0) + h;
    }

    final rows = ['Day', 'Night']
        .where((l) => (flights[l] ?? 0) > 0)
        .map((l) => FlightConditionBreakdownRow(
              label: l,
              flights: flights[l]!,
              hours: hours[l]!,
            ))
        .toList();

    return FlightConditionBreakdown(rows: rows);
  }

  FlightModeBreakdown buildFlightModeBreakdown(List<FlightLog> inRange) {
    if (inRange.isEmpty) return FlightModeBreakdown.empty;

    final flights = <String, int>{};
    final hours = <String, double>{};

    for (final log in inRange) {
      final label = flightModeLabel(log.isSimulated);
      final h = durationInHours(log);
      flights[label] = (flights[label] ?? 0) + 1;
      hours[label] = (hours[label] ?? 0) + h;
    }

    final rows = flights.entries
        .map((e) => FlightModeBreakdownRow(
              label: e.key,
              flights: e.value,
              hours: hours[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.hours.compareTo(a.hours));

    return FlightModeBreakdown(rows: rows);
  }

  AircraftBreakdown buildAircraftBreakdown(List<FlightLog> inRange) {
    if (inRange.isEmpty) return AircraftBreakdown.empty;

    final byType = <String, _Agg>{};
    final byReg = <String, _Agg>{};
    var hasReg = false;

    for (final log in inRange) {
      final h = durationInHours(log);
      final landings = log.safeDayLandings + log.safeNightLandings;
      final typeKey = log.aircraftType.trim().isEmpty
          ? 'Unknown'
          : log.aircraftType.trim();

      _addAgg(byType, typeKey, log, h, landings, aircraftType: typeKey);

      final reg = log.registration?.trim();
      if (reg != null && reg.isNotEmpty) {
        hasReg = true;
        _addAgg(byReg, reg, log, h, landings,
            aircraftType: typeKey, registration: reg);
      }
    }

    List<AircraftBreakdownRow> toRows(Map<String, _Agg> map) {
      return map.entries
          .map((e) => AircraftBreakdownRow(
                key: e.key,
                aircraftType: e.value.aircraftType,
                registration: e.value.registration,
                flights: e.value.flights,
                hours: e.value.hours,
                dayHours: e.value.dayHours,
                nightHours: e.value.nightHours,
                landings: e.value.landings,
              ))
          .toList()
        ..sort((a, b) => b.hours.compareTo(a.hours));
    }

    return AircraftBreakdown(
      byAircraftType: toRows(byType),
      byRegistration: toRows(byReg),
      hasRegistrationData: hasReg,
    );
  }

  void _addAgg(
    Map<String, _Agg> map,
    String key,
    FlightLog log,
    double h,
    int landings, {
    required String aircraftType,
    String? registration,
  }) {
    final agg = map.putIfAbsent(
      key,
      () => _Agg(aircraftType: aircraftType, registration: registration),
    );
    agg.flights++;
    agg.hours += h;
    if (log.isDayFlight) {
      agg.dayHours += h;
    } else {
      agg.nightHours += h;
    }
    agg.landings += landings;
  }

  List<PeriodBucket> buildTrendBuckets(
    List<FlightLog> inRange,
    ReportDateRange range,
  ) {
    if (inRange.isEmpty) return [];

    switch (range.kind) {
      case ReportPeriodKind.allTime:
      case ReportPeriodKind.thisYear:
        return _monthlyBuckets(inRange, range);
      case ReportPeriodKind.thisMonth:
        return _weeklyBuckets(inRange, range);
      case ReportPeriodKind.custom:
        return _dailyBuckets(inRange, range);
    }
  }

  List<PeriodBucket> _dailyBuckets(
    List<FlightLog> inRange,
    ReportDateRange range,
  ) {
    final fmt = DateFormat('d MMM yyyy');
    final buckets = <DateTime, _BucketAgg>{};
    for (var d = range.start;
        !d.isAfter(range.end);
        d = d.add(const Duration(days: 1))) {
      buckets[dateOnly(d)] = _BucketAgg();
    }

    for (final log in inRange) {
      final d = dateOnly(log.date);
      final agg = buckets[d];
      if (agg == null) continue;
      _accumulateBucket(agg, log);
    }

    return buckets.entries
        .where((e) => e.value.flights > 0)
        .map((e) => _toBucket(fmt.format(e.key), e.value))
        .toList();
  }

  List<PeriodBucket> _monthlyBuckets(
    List<FlightLog> inRange,
    ReportDateRange range,
  ) {
    final fmt = DateFormat('MMM yyyy');
    final buckets = <int, _BucketAgg>{};
    for (var m = 1; m <= 12; m++) {
      buckets[m] = _BucketAgg();
    }

    for (final log in inRange) {
      if (log.date.year != range.start.year) continue;
      _accumulateBucket(buckets[log.date.month]!, log);
    }

    return List.generate(12, (i) {
      final m = i + 1;
      final agg = buckets[m]!;
      return _toBucket(fmt.format(DateTime(range.start.year, m)), agg);
    }).where((b) => b.flights > 0 || b.hours > 0).toList();
  }

  List<PeriodBucket> _weeklyBuckets(
    List<FlightLog> inRange,
    ReportDateRange range,
  ) {
    final fmt = DateFormat('d MMM');
    final weekStarts = <DateTime>[];
    var cursor = range.start;
    while (!cursor.isAfter(range.end)) {
      weekStarts.add(dateOnly(cursor));
      cursor = cursor.add(const Duration(days: 7));
    }

    final buckets = {for (final w in weekStarts) w: _BucketAgg()};

    for (final log in inRange) {
      final d = dateOnly(log.date);
      DateTime weekStart = weekStarts.first;
      for (final w in weekStarts) {
        if (!d.isBefore(w)) weekStart = w;
      }
      final agg = buckets[weekStart];
      if (agg != null) _accumulateBucket(agg, log);
    }

    return buckets.entries
        .map((e) => _toBucket('Week of ${fmt.format(e.key)}', e.value))
        .where((b) => b.flights > 0)
        .toList();
  }

  void _accumulateBucket(_BucketAgg agg, FlightLog log) {
    final h = durationInHours(log);
    agg.flights++;
    agg.hours += h;
    if (log.isDayFlight) {
      agg.dayHours += h;
    } else {
      agg.nightHours += h;
    }
  }

  PeriodBucket _toBucket(String label, _BucketAgg agg) {
    return PeriodBucket(
      label: label,
      flights: agg.flights,
      hours: agg.hours,
      dayHours: agg.dayHours,
      nightHours: agg.nightHours,
    );
  }
}

class _Agg {
  _Agg({required this.aircraftType, this.registration});

  final String aircraftType;
  final String? registration;
  int flights = 0;
  double hours = 0;
  double dayHours = 0;
  double nightHours = 0;
  int landings = 0;
}

class _BucketAgg {
  int flights = 0;
  double hours = 0;
  double dayHours = 0;
  double nightHours = 0;
}

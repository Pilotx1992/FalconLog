import 'package:flutter/material.dart';
import 'models.dart';
import 'dart:collection';

class FlightLogProvider extends ChangeNotifier {
  final List<FlightLog> _logs = [];
  final List<String> _aircraftTypes = [];
  FlightDataSummary _summary = FlightDataSummary(totalFlightHours: 0, totalFlights: 0, dayTimeHours: 0, nightTimeHours: 0);
  CurrencyStatus _currencyStatus = CurrencyStatus(isDue: false, message: 'Currency is up to date.');

  UnmodifiableListView<FlightLog> get logs => UnmodifiableListView(_logs);
  UnmodifiableListView<String> get aircraftTypes => UnmodifiableListView(_aircraftTypes);
  FlightDataSummary get summary => _summary;
  CurrencyStatus get currencyStatus => _currencyStatus;

  void addFlightLog(FlightLog log) {
    _logs.insert(0, log);
    if (!_aircraftTypes.contains(log.aircraftType)) {
      _aircraftTypes.add(log.aircraftType);
      _aircraftTypes.sort();
    }
    _refreshCalculations();
    notifyListeners();
  }

  void updateFlightLog(FlightLog updatedLog) {
    final idx = _logs.indexWhere((l) => l.id == updatedLog.id);
    if (idx != -1) {
      _logs[idx] = updatedLog;
      if (!_aircraftTypes.contains(updatedLog.aircraftType)) {
        _aircraftTypes.add(updatedLog.aircraftType);
        _aircraftTypes.sort();
      }
      _refreshCalculations();
      notifyListeners();
    }
  }

  void deleteFlightLog(String id) {
    _logs.removeWhere((l) => l.id == id);
    _refreshCalculations();
    notifyListeners();
  }

  void addAircraftType(String type) {
    if (type.isNotEmpty && !_aircraftTypes.contains(type)) {
      _aircraftTypes.add(type);
      _aircraftTypes.sort();
      notifyListeners();
    }
  }

  void _refreshCalculations() {
    double total = 0;
    double day = 0;
    double night = 0;
    for (var log in _logs) {
      final duration = log.durationHours + (log.durationMinutes / 60.0);
      total += duration;
      if (log.isDayFlight) {
        day += duration;
      } else {
        night += duration;
      }
    }
    _summary = FlightDataSummary(
      totalFlightHours: total,
      totalFlights: _logs.length,
      dayTimeHours: day,
      nightTimeHours: night,
    );
    _currencyStatus = _checkCurrency();
  }

  CurrencyStatus _checkCurrency() {
    final now = DateTime.now();
    final totalHours = _summary.totalFlightHours;
    final dayFlights = _logs.where((l) => l.isDayFlight && !l.isSimulated).toList();
    final nightFlights = _logs.where((l) => !l.isDayFlight && !l.isSimulated).toList();
    dayFlights.sort((a, b) => b.date.compareTo(a.date));
    nightFlights.sort((a, b) => b.date.compareTo(a.date));
    final lastDay = dayFlights.isNotEmpty ? dayFlights.first.date : null;
    final lastNight = nightFlights.isNotEmpty ? nightFlights.first.date : null;
    int dayInterval = 15;
    int nightInterval = 7;
    if (totalHours >= 800) {
      dayInterval = 30;
      nightInterval = 21;
    } else if (totalHours >= 600) {
      dayInterval = 21;
      nightInterval = 15;
    }
    if (lastDay != null && now.difference(lastDay).inDays > dayInterval) {
      final daysSinceLastFlight = now.difference(lastDay).inDays;
      return CurrencyStatus(
        isDue: true,
        alertType: 'Day',
        lastFlightDate: lastDay,
        requiredInterval: dayInterval,
        message: 'Last day flight: $daysSinceLastFlight days ago',
      );
    }
    if (lastNight != null && now.difference(lastNight).inDays > nightInterval) {
      final daysSinceLastFlight = now.difference(lastNight).inDays;
      return CurrencyStatus(
        isDue: true,
        alertType: 'Night',
        lastFlightDate: lastNight,
        requiredInterval: nightInterval,
        message: 'Last night flight: $daysSinceLastFlight days ago',
      );
    }
    return CurrencyStatus(isDue: false, message: 'Currency is up to date.');
  }
}

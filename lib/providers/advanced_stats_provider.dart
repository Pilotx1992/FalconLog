import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/flight_log.dart';
import 'flight_logs_provider.dart';

// Data class to hold all advanced stats
class AdvancedStats {
  final double currentMonthHours;
  final double currentYearHours;
  final Map<String, double> hoursByAircraft;
  final Map<PilotRole, double> hoursByRole;
  final Map<String, double> last3MonthsHours;

  AdvancedStats({
    this.currentMonthHours = 0.0,
    this.currentYearHours = 0.0,
    this.hoursByAircraft = const {},
    this.hoursByRole = const {},
    this.last3MonthsHours = const {},
  });
}

// Provider to calculate the advanced stats
final advancedStatsProvider = Provider<AdvancedStats>((ref) {
  final logsAsyncValue = ref.watch(flightLogsProvider);

  return logsAsyncValue.when(
    data: (logs) {
      if (logs.isEmpty) {
        return AdvancedStats();
      }

      final now = DateTime.now();

      // 1. Current Month Statistics (25th of last month to 24th of this month)
      final monthStart = DateTime(now.year, now.month - 1, 25);
      final monthEnd = DateTime(now.year, now.month, 25);
      final currentMonthLogs = logs.where((log) {
        return !log.date.isBefore(monthStart) && log.date.isBefore(monthEnd);
      }).toList();
      final currentMonthHours = _calculateTotalHours(currentMonthLogs);

      // 2. Current Year Statistics (May 25th this year to May 24th next year)
      int year = now.year;
      if (now.month < 5 || (now.month == 5 && now.day < 25)) {
        year = now.year - 1;
      }
      final yearStart = DateTime(year, 5, 25);
      final yearEnd = DateTime(year + 1, 5, 25);
      final currentYearLogs = logs.where((log) {
        return !log.date.isBefore(yearStart) && log.date.isBefore(yearEnd);
      }).toList();
      final currentYearHours = _calculateTotalHours(currentYearLogs);

      // 3. Total Flight Hours by Aircraft Type
      final hoursByAircraft = <String, double>{};
      for (var log in logs) {
        final hours = log.durationHours + (log.durationMinutes / 60.0);
        hoursByAircraft.update(log.aircraftType, (value) => value + hours,
            ifAbsent: () => hours);
      }

      // 4. Flight Hours by Pilot Role
      final hoursByRole = <PilotRole, double>{};
      for (var log in logs) {
        final hours = log.durationHours + (log.durationMinutes / 60.0);
        hoursByRole.update(log.pilotRole, (value) => value + hours,
            ifAbsent: () => hours);
      }

      // 5. Last 3 Months Statistics
      final last3MonthsHours = <String, double>{};
      for (int i = 0; i < 3; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthStart = DateTime(month.year, month.month, 1);
        final monthEnd = DateTime(month.year, month.month + 1, 1);
        final monthLogs = logs.where((log) {
          return !log.date.isBefore(monthStart) && log.date.isBefore(monthEnd);
        }).toList();
        final monthName = DateFormat('MMMM yyyy').format(month);
        last3MonthsHours[monthName] = _calculateTotalHours(monthLogs);
      }

      return AdvancedStats(
        currentMonthHours: currentMonthHours,
        currentYearHours: currentYearHours,
        hoursByAircraft: hoursByAircraft,
        hoursByRole: hoursByRole,
        last3MonthsHours: last3MonthsHours,
      );
    },
    loading: () => AdvancedStats(),
    error: (_, __) => AdvancedStats(),
  );
});

double _calculateTotalHours(List<FlightLog> logList) {
  return logList.fold(
      0.0, (sum, log) => sum + log.durationHours + (log.durationMinutes / 60.0));
}

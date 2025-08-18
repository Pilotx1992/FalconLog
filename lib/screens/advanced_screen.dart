import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flight_logs_provider.dart';
import '../models/flight_log.dart';

class AdvancedScreen extends ConsumerWidget {
  const AdvancedScreen({super.key});



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ...existing code...
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Advanced Statistics',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 22,
            fontFamily: 'Roboto',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a237e), Color(0xFF3949ab), Color(0xFF5e35b1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 2: Current Period Statistics
              const _CurrentPeriodSection(),
              const SizedBox(height: 28),
              // Section 3: Statistics by Flight Type
              const _FlightTypeStatsSection(),
              const SizedBox(height: 28),
              // Section 4: Flight Hours by Aircraft Type
              const _AircraftTypeStatsSection(),
              const SizedBox(height: 28),
              // Section 5: Flight Hours by Pilot Role
              const _PilotRoleStatsSection(),
              const SizedBox(height: 28),
              // Section 6: Last 3 Months Statistics
              const _Last3MonthsSection(),
              const SizedBox(height: 28),
              // Section 7: Recent Activity
              const _RecentActivitySection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

// --- Section 1: Overview Grid ---
}

// --- Section 2: Current Period Statistics ---
class _CurrentPeriodSection extends StatelessWidget {
  const _CurrentPeriodSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final logs = ref.watch(flightLogsProvider).maybeWhen(data: (l) => l, orElse: () => []);
      // Sort logs by date (newest first) for consistent data processing
      final sortedLogs = logs.toList()..sort((a, b) => b.date.compareTo(a.date));
      
      String format(double hours) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
  // فترة الشهر الحالي (من 1 إلى آخر يوم في الشهر)
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1); // بداية الشهر القادم (حد علوي غير شامل)
  final monthLogs = sortedLogs.where((log) => !log.date.isBefore(monthStart) && log.date.isBefore(monthEnd)).toList();
      double monthDay = 0, monthNight = 0;
      for (final log in monthLogs) {
        final h = log.durationHours + (log.durationMinutes / 60.0);
        if (log.isDayFlight) {
          monthDay += h;
        } else {
          monthNight += h;
        }
      }
      // السنة: من 25/5 الحالي إلى 24/5 القادم
      int year = now.month < 5 || (now.month == 5 && now.day < 25) ? now.year - 1 : now.year;
      final yearStart = DateTime(year, 5, 25);
      final yearEnd = DateTime(year + 1, 5, 25);
      final yearLogs = sortedLogs.where((log) => !log.date.isBefore(yearStart) && log.date.isBefore(yearEnd)).toList();
      double yearDay = 0, yearNight = 0;
      for (final log in yearLogs) {
        final h = log.durationHours + (log.durationMinutes / 60.0);
        if (log.isDayFlight) {
          yearDay += h;
        } else {
          yearNight += h;
        }
      }
      return Column(
        children: [
          _PeriodCard(
            title: 'Current Month',
            dateRange: '01/${monthStart.month.toString().padLeft(2, '0')} - ${monthEnd.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}/${monthStart.month.toString().padLeft(2, '0')}',
            backgroundColor: const Color(0xFFE0F4FF), // Sky blue background
            stats: [
              _PeriodStat(icon: Icons.wb_sunny_rounded, color: const Color(0xFFf59e0b), label: 'Day Hours', value: format(monthDay)),
              _PeriodStat(icon: Icons.nights_stay_rounded, color: const Color(0xFF7c3aed), label: 'Night Hours', value: format(monthNight)),
              _PeriodStat(icon: Icons.access_time_rounded, color: const Color(0xFF38bdf8), label: 'Total Hours', value: format(monthDay + monthNight)),
              _PeriodStat(icon: Icons.flight_rounded, color: const Color(0xFF34d399), label: 'Flights', value: monthLogs.length.toString()),
            ],
          ),
          const SizedBox(height: 16),
          _PeriodCard(
            title: 'Current Year',
            dateRange: '${yearStart.day.toString().padLeft(2, '0')}/${yearStart.month.toString().padLeft(2, '0')} - ${yearEnd.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}/${yearEnd.subtract(const Duration(days: 1)).month.toString().padLeft(2, '0')}',
            backgroundColor: const Color(0xFFE8F5E8), // Light pistachio green background
            stats: [
              _PeriodStat(icon: Icons.wb_sunny_rounded, color: const Color(0xFFf59e0b), label: 'Day Hours', value: format(yearDay)),
              _PeriodStat(icon: Icons.nights_stay_rounded, color: const Color(0xFF7c3aed), label: 'Night Hours', value: format(yearNight)),
              _PeriodStat(icon: Icons.access_time_rounded, color: const Color(0xFF38bdf8), label: 'Total Hours', value: format(yearDay + yearNight)),
              _PeriodStat(icon: Icons.flight_rounded, color: const Color(0xFF34d399), label: 'Flights', value: yearLogs.length.toString()),
            ],
          ),
        ],
      );
    });
  }
}

class _PeriodCard extends StatelessWidget {
  final String title;
  final String dateRange;
  final List<_PeriodStat> stats;
  final Color? backgroundColor;
  const _PeriodCard({required this.title, required this.dateRange, required this.stats, this.backgroundColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: backgroundColor != null 
          ? Border.all(
              color: backgroundColor == const Color(0xFFE0F4FF) 
                ? const Color(0xFF87CEEB) // Darker sky blue border for month
                : const Color(0xFF90EE90), // Darker pistachio green border for year
              width: 2,
            )
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                flex: 0,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    dateRange,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = stats.length;
              final spacing = 12.0;
              final totalSpacing = spacing * (count - 1);
              final itemWidth = count == 0
                  ? constraints.maxWidth
                  : (constraints.maxWidth - totalSpacing) / count;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final s in stats)
                    SizedBox(
                      width: itemWidth,
                      child: s,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _PeriodStat({required this.icon, required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }
}

// --- Section 3: Statistics by Flight Type ---
class _FlightTypeStatsSection extends StatelessWidget {
  const _FlightTypeStatsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final logs = ref.watch(flightLogsProvider).maybeWhen(data: (l) => l, orElse: () => []);
      // Sort logs by date (newest first) for consistent data processing
      final sortedLogs = logs.toList()..sort((a, b) => b.date.compareTo(a.date));
      
      // Collect all types from flightTypes list
      final Map<String, int> typeCounts = {};
      int total = sortedLogs.length;
      for (final log in sortedLogs) {
        // Process each flight type in the flightTypes list
        for (final flightType in log.flightTypes) {
          String typeName = _getFlightTypeName(flightType);
          typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;
        }
      }
      final sortedTypes = typeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By Flight Type',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1E293B),
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 18),
            ...sortedTypes.map((e) => _FlightTypeProgress(
                  name: e.key,
                  percent: total == 0 ? 0 : (e.value * 100.0 / total),
                )),
          ],
        ),
      );
    });
  }

  String _getFlightTypeName(FlightType type) {
    switch (type) {
      case FlightType.local:
        return 'Local';
      case FlightType.mission:
        return 'Mission';
      case FlightType.xc:
        return 'Cross Country';
      case FlightType.zone:
        return 'Zone';
      case FlightType.range:
        return 'Range';
      case FlightType.formation:
        return 'Formation';
      case FlightType.currencyFlight:
        return 'Currency';
      case FlightType.landingGround:
        return 'Landing Ground';
      case FlightType.navalOps:
        return 'Naval OPS';
      case FlightType.lowLevel:
        return 'Low Level';
    }
  }
}

class _FlightTypeProgress extends StatelessWidget {
  final String name;
  final double percent;
  const _FlightTypeProgress({required this.name, required this.percent});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFe0f2fe),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38bdf8)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF38bdf8),
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}

// --- Section 4: Flight Hours by Aircraft Type ---
class _AircraftTypeStatsSection extends StatelessWidget {
  const _AircraftTypeStatsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final logs = ref.watch(flightLogsProvider).maybeWhen(data: (l) => l, orElse: () => []);
      // Sort logs by date (newest first) for consistent data processing
      final sortedLogs = logs.toList()..sort((a, b) => b.date.compareTo(a.date));
      
      final Map<String, double> aircraftHours = {};
      final Map<String, DateTime> aircraftLastFlight = {};
      String format(double hours) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
      for (final log in sortedLogs) {
        final type = log.aircraftType ?? 'Unknown';
        final h = log.durationHours + (log.durationMinutes / 60.0);
        aircraftHours[type] = (aircraftHours[type] ?? 0) + h;
        // Track the most recent flight date for each aircraft type
        if (!aircraftLastFlight.containsKey(type) || log.date.isAfter(aircraftLastFlight[type]!)) {
          aircraftLastFlight[type] = log.date;
        }
      }
      final sortedAircrafts = aircraftHours.entries.toList()
        ..sort((a, b) {
          final dateA = aircraftLastFlight[a.key] ?? DateTime(1900);
          final dateB = aircraftLastFlight[b.key] ?? DateTime(1900);
          return dateB.compareTo(dateA); // Sort by most recent flight date
        });
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By Aircraft Type',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1E293B),
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 18),
            ...sortedAircrafts.map((a) => _AircraftTypeRow(
                  name: a.key,
                  hours: format(a.value),
                )),
          ],
        ),
      );
    });
  }
}

class _AircraftTypeRow extends StatelessWidget {
  final String name;
  final String hours;
  const _AircraftTypeRow({required this.name, required this.hours});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.airplanemode_active_rounded, color: Color(0xFF7c3aed), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          Text(
            hours,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}

// --- Section 5: Flight Hours by Pilot Role ---
class _PilotRoleStatsSection extends StatelessWidget {
  const _PilotRoleStatsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final logs = ref.watch(flightLogsProvider).maybeWhen(data: (l) => l, orElse: () => []);
      // Sort logs by date (newest first) for consistent data processing
      final sortedLogs = logs.toList()..sort((a, b) => b.date.compareTo(a.date));
      
      final Map<String, double> roleHours = {};
      String format(double hours) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
      for (final log in sortedLogs) {
        final role = log.pilotRole != null ? log.pilotRole.toString().split('.').last : 'Unknown';
        final h = log.durationHours + (log.durationMinutes / 60.0);
        roleHours[role] = (roleHours[role] ?? 0) + h;
      }
      final sortedRoles = roleHours.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By Pilot Role',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1E293B),
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 18),
            ...sortedRoles.map((r) => _PilotRoleRow(
                  name: r.key,
                  hours: format(r.value),
                )),
          ],
        ),
      );
    });
  }
}

class _PilotRoleRow extends StatelessWidget {
  final String name;
  final String hours;
  const _PilotRoleRow({required this.name, required this.hours});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          Text(
            hours,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}

// --- Section 6: Last 3 Months Statistics ---
class _Last3MonthsSection extends StatelessWidget {
  const _Last3MonthsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final logs = ref.watch(flightLogsProvider).maybeWhen(data: (l) => l, orElse: () => []);
      // Sort logs by date (newest first) before processing
      final sortedLogs = logs.toList()..sort((a, b) => b.date.compareTo(a.date));
      
      String format(double hours) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
      final now = DateTime.now();
      List<Map<String, dynamic>> months = [];
      for (int i = 0; i <= 2; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(month.year, month.month + 1, 1);
        final monthLogs = sortedLogs.where((log) => !log.date.isBefore(month) && log.date.isBefore(nextMonth)).toList();
        double hours = 0;
        for (final log in monthLogs) {
          hours += log.durationHours + (log.durationMinutes / 60.0);
        }
        months.add({
          'month': _monthName(month.month),
          'flights': monthLogs.length,
          'hours': format(hours),
        });
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last 3 Months',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1E293B),
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 18),
            ...months.map((m) => _MonthStatRow(
                  month: m['month'] as String,
                  flights: m['flights'] as int,
                  hours: m['hours'] as String,
                )),
          ],
        ),
      );
    });
  }

  String _monthName(int month) {
    const names = [
      '',
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month];
  }
}

class _MonthStatRow extends StatelessWidget {
  final String month;
  final int flights;
  final String hours;
  const _MonthStatRow({required this.month, required this.flights, required this.hours});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF0284c7), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                month,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            Text(
              '$flights flights',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF38bdf8),
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(width: 10),
            Text(
              hours,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        const Divider(height: 18, thickness: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }
}

// --- Section 7: Recent Activity ---
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final logs = ref.watch(flightLogsProvider).maybeWhen(data: (l) => l, orElse: () => []);
      String format(double hours) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
      // Sort by date (newest first) and take the most recent 5 flights
      final recent = logs.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final last = recent.take(5).toList();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1E293B),
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 18),
            ...last.map((r) => _RecentFlightRow(
                  aircraft: r.aircraftType ?? 'Unknown',
                  date: '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}',
                  duration: format(r.durationHours + (r.durationMinutes / 60.0)),
                  isDay: r.isDayFlight,
                )),
          ],
        ),
      );
    });
  }
}

class _RecentFlightRow extends StatelessWidget {
  final String aircraft;
  final String date;
  final String duration;
  final bool isDay;
  const _RecentFlightRow({required this.aircraft, required this.date, required this.duration, required this.isDay});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$aircraft - $date',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          Text(
            duration,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDay ? const Color(0xFFf59e0b).withOpacity(0.12) : const Color(0xFF7c3aed).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              size: 16,
              color: isDay ? const Color(0xFFf59e0b) : const Color(0xFF7c3aed),
            ),
          ),
        ],
      ),
    );
  }
}

// ...existing code...

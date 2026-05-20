import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flight_logs_provider.dart';
import '../models/flight_log.dart';
import '../utils/user_safe_message.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsyncValue = ref.watch(flightLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Flight Summary',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 22,
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
      body: logsAsyncValue.when(
        data: (logs) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Aircraft Hours Table
                if (logs.isNotEmpty) _buildAircraftHoursTable(logs),

                const SizedBox(height: 24),

                // Recent Activity
                if (logs.isNotEmpty) _buildRecentActivity(logs),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3949ab)),
          ),
        ),
        error: (error, stack) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading data',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userSafeErrorMessage(error),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(flightLogsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3949ab),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(List<FlightLog> logs) {
    // Sort logs by date (newest first) and take the most recent 2
    final sortedLogs = logs.toList()..sort((a, b) => b.date.compareTo(a.date));
    final recentLogs = sortedLogs.take(2).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recentLogs.map((log) => _buildActivityItem(log)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(FlightLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: log.isDayFlight
                  ? const Color(0xFFEA580C).withValues(alpha: 0.1)
                  : const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              log.isDayFlight
                  ? Icons.wb_sunny_rounded
                  : Icons.nights_stay_rounded,
              color: log.isDayFlight
                  ? const Color(0xFFEA580C)
                  : const Color(0xFF7C3AED),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.aircraftType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${log.durationHours}h ${log.durationMinutes}m • ${log.flightTypes.map(_getFlightTypeName).join(', ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${log.date.day}/${log.date.month}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
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

  Widget _buildAircraftHoursTable(List<FlightLog> logs) {
    // Sort logs by date (newest first) for consistent processing
    final sortedLogs = logs.toList()..sort((a, b) => b.date.compareTo(a.date));

    // Group flights by aircraft type and calculate hours
    final aircraftStats = <String, Map<String, dynamic>>{};

    for (final log in sortedLogs) {
      final aircraftType = log.aircraftType;
      final totalHours = log.durationHours + (log.durationMinutes / 60.0);

      if (!aircraftStats.containsKey(aircraftType)) {
        aircraftStats[aircraftType] = {
          'day': 0.0,
          'night': 0.0,
          'total': 0.0,
          'lastFlightDate': log.date, // Track the most recent flight date
        };
      }

      aircraftStats[aircraftType]!['total'] =
          aircraftStats[aircraftType]!['total']! + totalHours;

      // Update the most recent flight date for this aircraft type
      if (log.date.isAfter(aircraftStats[aircraftType]!['lastFlightDate'])) {
        aircraftStats[aircraftType]!['lastFlightDate'] = log.date;
      }

      // Check if flight is day or night using isDayFlight property
      if (log.isDayFlight) {
        aircraftStats[aircraftType]!['day'] =
            aircraftStats[aircraftType]!['day']! + totalHours;
      } else {
        aircraftStats[aircraftType]!['night'] =
            aircraftStats[aircraftType]!['night']! + totalHours;
      }
    }

    // Sort aircraft by most recent flight date (newest first)
    final sortedAircraft = aircraftStats.entries.toList()
      ..sort((a, b) =>
          b.value['lastFlightDate'].compareTo(a.value['lastFlightDate']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Section
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flight_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Aircraft Hours Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),

        // Table Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a237e), Color(0xFF3949ab)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Type',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Day',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Night',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Table Body
        Column(
          children: sortedAircraft.asMap().entries.map((entry) {
            final index = entry.key;
            final aircraftEntry = entry.value;
            final aircraftType = aircraftEntry.key;
            final stats = aircraftEntry.value;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: index % 2 == 0 ? const Color(0xFFF8FAFC) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      aircraftType,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatHours(stats['day']!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFEA580C),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatHours(stats['night']!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatHours(stats['total']!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        if (sortedAircraft.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flight_land_rounded,
                  color: Colors.grey[400],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'No flight data available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

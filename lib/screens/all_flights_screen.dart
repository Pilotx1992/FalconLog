import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flight_logs_provider.dart';
import 'package:intl/intl.dart';
import '../models/flight_log.dart';
import '../utils/performance_optimizer.dart';

String _getTypeName(FlightType type) {
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

class FlightFilter {
  final DateTime? date;
  final String? aircraftType;
  final FlightType? flightType;

  FlightFilter({this.date, this.aircraftType, this.flightType});

  bool get isApplied => date != null || aircraftType != null || flightType != null;

  FlightFilter copyWith({
    DateTime? date,
    String? aircraftType,
    FlightType? flightType,
    bool clearDate = false,
    bool clearAircraft = false,
    bool clearFlightType = false,
  }) {
    return FlightFilter(
      date: clearDate ? null : date ?? this.date,
      aircraftType: clearAircraft ? null : aircraftType ?? this.aircraftType,
      flightType: clearFlightType ? null : flightType ?? this.flightType,
    );
  }
}

final flightFilterProvider = StateProvider<FlightFilter>((ref) => FlightFilter());

class AllFlightsScreen extends ConsumerStatefulWidget {
  const AllFlightsScreen({super.key});

  @override
  ConsumerState<AllFlightsScreen> createState() => _AllFlightsScreenState();
}

class _AllFlightsScreenState extends ConsumerState<AllFlightsScreen> {
  @override
  Widget build(BuildContext context) {
    final logsAsyncValue = ref.watch(flightLogsProvider);
    final filter = ref.watch(flightFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'All Flights',
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
        actions: [
          IconButton(
            icon: Icon(
              filter.isApplied
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_off_rounded,
              color: Colors.white,
            ),
            onPressed: () => _showFilterDialog(context, ref),
          ),
        ],
      ),
      body: logsAsyncValue.when(
        data: (logs) {
          final filteredLogs = _applyFilter(logs, filter);
          return filteredLogs.isEmpty
              ? _buildEmptyState(isFiltered: filter.isApplied)
              : _buildFlightsList(context, ref, filteredLogs);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  List<FlightLog> _applyFilter(List<FlightLog> logs, FlightFilter filter) {
    return logs.where((log) {
      if (filter.date != null) {
        if (log.date.year != filter.date!.year ||
            log.date.month != filter.date!.month ||
            log.date.day != filter.date!.day) {
          return false;
        }
      }
      if (filter.aircraftType != null &&
          log.aircraftType != filter.aircraftType) {
        return false;
      }
      if (filter.flightType != null &&
          !log.flightTypes.contains(filter.flightType)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _showFilterDialog(BuildContext context, WidgetRef ref) async {
    final flightLogs = ref.read(flightLogsProvider).asData?.value ?? [];
    final allAircraftTypes =
        flightLogs.map((e) => e.aircraftType).toSet().toList();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return FilterDialog(
          allAircraftTypes: allAircraftTypes,
        );
      },
    );
  }

  Widget _buildEmptyState({bool isFiltered = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered
                  ? Icons.filter_alt_off_rounded
                  : Icons.flight_takeoff_rounded,
              size: 80,
              color: const Color(0xFF3949ab),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'No Matching Flights' : 'No Flights Yet',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1a202c),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered
                  ? 'Try adjusting your filters'
                  : 'Start logging your flights',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightsList(
      BuildContext context, WidgetRef ref, List<FlightLog> logs) {
    // Sort logs from newest to oldest
    final sortedLogs = List<FlightLog>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Use a provider or callback to collapse all expanded cards
        // For now, do nothing (needs state management for all cards)
      },
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1a237e), Color(0xFF3949ab)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3949ab).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.flight_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Text(
                  '${sortedLogs.length} Flight${sortedLogs.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Flights list
          Expanded(
            child: PerformanceOptimizer.optimizedListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: sortedLogs.length,
              itemBuilder: (context, i) {
                final log = sortedLogs[i];
                return _buildFlightCard(context, ref, log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightCard(BuildContext context, WidgetRef ref, FlightLog log) {
    return RepaintBoundary(
      child: _FlightCardWithExpansion(log: log, ref: ref),
    );
  }
}

class _FlightCardWithExpansion extends StatefulWidget {
  final FlightLog log;
  final WidgetRef ref;

  const _FlightCardWithExpansion({required this.log, required this.ref});

  @override
  State<_FlightCardWithExpansion> createState() => _FlightCardWithExpansionState();
}

class _FlightCardWithExpansionState extends State<_FlightCardWithExpansion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_isExpanded) {
            setState(() {
              _isExpanded = false;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3949ab).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.log.isDayFlight
                          ? Icons.wb_sunny_rounded
                          : Icons.nights_stay_rounded,
                      color: const Color(0xFF3949ab),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy').format(widget.log.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1a202c),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.log.aircraftType,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  IgnorePointer(
                    ignoring: false,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteDialog(context, widget.ref, widget.log),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Basic flight info (always visible)
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.schedule,
                    label: '${widget.log.durationHours}:${widget.log.durationMinutes.toString().padLeft(2, '0')}',
                    color: Colors.green,
                  ),
                  const Spacer(),
                  IgnorePointer(
                    ignoring: false,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3949ab).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded ? 'Less details' : 'More details',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF3949ab),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: const Color(0xFF3949ab),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Expandable details
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                // Flight details
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      icon: Icons.person,
                      label: _getRoleName(widget.log.pilotRole),
                      color: Colors.blue,
                    ),
                    _buildInfoChip(
                      icon: widget.log.isSimulated ? Icons.computer : Icons.flight,
                      label: widget.log.isSimulated ? 'Sim' : 'Real',
                      color: widget.log.isSimulated ? Colors.purple : Colors.orange,
                    ),
                  ],
                ),

                // Flight types
                if (widget.log.flightTypes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.log.flightTypes.map<Widget>((type) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a237e).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getTypeName(type),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1a237e),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ], // Close the main children array of Column
          ), // Column
        ), // Padding
      ), // GestureDetector
    ); // Container
}

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleName(PilotRole role) {
    switch (role) {
      case PilotRole.IP:
        return 'IP';
      case PilotRole.MTP:
        return 'MTP';
      case PilotRole.PIC:
        return 'PIC';
      case PilotRole.CPG_GUNNER:
        return 'CPG GUNNER';
    }
  }

  Future<void> _showDeleteDialog(
      BuildContext context, WidgetRef ref, FlightLog log) async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Flight'),
          content: Text('Delete flight from ${DateFormat('MMM dd, yyyy').format(log.date)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref.read(flightLogsProvider.notifier).deleteFlightLog(log.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Flight deleted')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class FilterDialog extends ConsumerStatefulWidget {
  final List<String> allAircraftTypes;
  const FilterDialog({super.key, required this.allAircraftTypes});

  @override
  ConsumerState<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends ConsumerState<FilterDialog> {
  late FlightFilter _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = ref.read(flightFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Flights'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter
            _buildDateFilter(context),
            const SizedBox(height: 20),

            // Aircraft Type Filter
            _buildAircraftFilter(),
            const SizedBox(height: 20),

            // Flight Type Filter
            _buildFlightTypeFilter(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(flightFilterProvider.notifier).state = FlightFilter();
            Navigator.of(context).pop();
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(flightFilterProvider.notifier).state = _currentFilter;
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _currentFilter.date ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null && mounted) {
              setState(() {
                _currentFilter = _currentFilter.copyWith(date: picked);
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _currentFilter.date == null
                        ? 'Any Date'
                        : DateFormat('MMM dd, yyyy').format(_currentFilter.date!),
                  ),
                ),
                if (_currentFilter.date != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _currentFilter = _currentFilter.copyWith(clearDate: true);
                    }),
                  )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAircraftFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aircraft Type', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _currentFilter.aircraftType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
          hint: const Text('Any Aircraft'),
          isExpanded: true,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Any Aircraft'),
            ),
            ...widget.allAircraftTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }),
          ],
          onChanged: (value) {
            setState(() {
              _currentFilter = _currentFilter.copyWith(aircraftType: value, clearAircraft: value == null);
            });
          },
        ),
      ],
    );
  }

  Widget _buildFlightTypeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Flight Type', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<FlightType>(
          value: _currentFilter.flightType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
          hint: const Text('Any Type'),
          isExpanded: true,
          items: [
            const DropdownMenuItem<FlightType>(
              value: null,
              child: Text('Any Type'),
            ),
            ...FlightType.values.map((type) {
              return DropdownMenuItem(value: type, child: Text(_getTypeName(type)));
            }),
          ],
          onChanged: (value) {
            setState(() {
              _currentFilter = _currentFilter.copyWith(flightType: value, clearFlightType: value == null);
            });
          },
        ),
      ],
    );
  }
}

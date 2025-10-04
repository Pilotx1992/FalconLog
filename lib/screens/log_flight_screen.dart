import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/flight_log.dart';
import '../providers/flight_logs_provider.dart';
import '../providers/aircraft_types_provider.dart';

class LogFlightScreen extends ConsumerStatefulWidget {
  const LogFlightScreen({super.key});

  @override
  ConsumerState<LogFlightScreen> createState() => _LogFlightScreenState();
}

class _LogFlightScreenState extends ConsumerState<LogFlightScreen> {
  final _formKey = GlobalKey<FormState>();

  // State variables
  DateTime? _date = DateTime.now();
  final List<FlightType> _selectedTypes = [];
  int _hours = 0;
  int _minutes = 0;
  String? _aircraftType;
  PilotRole? _pilotRole;
  bool _isDay = true;
  bool _isSim = false;
  String _newAircraft = '';

  // Dialog helpers
  void _showAddAircraftDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Aircraft Type'),
          content: TextFormField(
            decoration: const InputDecoration(hintText: 'Aircraft Type'),
            onChanged: (v) => setState(() => _newAircraft = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_newAircraft.trim().isNotEmpty) {
                  await ref
                      .read(aircraftTypesProvider.notifier)
                      .addAircraftType(_newAircraft.trim());
                  if (!mounted) return;
                  setState(() {
                    _aircraftType = _newAircraft.trim();
                    _newAircraft = '';
                  });
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String type) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Aircraft Type'),
          content: Text('Are you sure you want to delete "$type"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(aircraftTypesProvider.notifier)
                    .removeAircraftType(type);
                if (!mounted) return;
                if (_aircraftType == type) {
                  setState(() => _aircraftType = null);
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showFlightTypesDialog() async {
    final List<FlightType> tempSelectedTypes = List.from(_selectedTypes);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Flight Types'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: FlightType.values.length,
                  itemBuilder: (context, index) {
                    final type = FlightType.values[index];
                    final typeInfo = _getFlightTypeInfo(type);
                    return CheckboxListTile(
                      title: Text(typeInfo.name),
                      secondary: Icon(typeInfo.icon),
                      value: tempSelectedTypes.contains(type),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelectedTypes.add(type);
                          } else {
                            tempSelectedTypes.remove(type);
                          }
                        });
                      },
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  _selectedTypes.clear();
                  _selectedTypes.addAll(tempSelectedTypes);
                });
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      _date = DateTime.now();
      _selectedTypes.clear();
      _hours = 0;
      _minutes = 0;
      _aircraftType = null;
      _pilotRole = null;
      _isDay = true;
      _isSim = false;
      _newAircraft = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final aircraftTypes = ref.watch(aircraftTypesProvider);

    return GestureDetector(
      onTap: () {
        // إخفاء الـ cursor عند الضغط في أي مكان
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Log New Flight',
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
                colors: [
                  Color(0xFF1a237e),
                  Color(0xFF3949ab),
                  Color(0xFF5e35b1)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF334155).withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Section
                      const Text(
                        'Flight Date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && mounted) {
                            setState(() => _date = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _date == null
                                    ? 'Select Date'
                                    : DateFormat('MMM dd, yyyy').format(_date!),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Flight Types Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF334155).withValues(alpha: 0.05),
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
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.label_rounded,
                              color: Color(0xFF059669),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Flight Type(s)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _showFlightTypesDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.label_outline_rounded,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedTypes.isEmpty
                                      ? 'Select Flight Type(s)'
                                      : _selectedTypes
                                          .map(
                                              (t) => _getFlightTypeInfo(t).name)
                                          .join(', '),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedTypes.isEmpty
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF334155),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Duration and Aircraft Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF334155).withValues(alpha: 0.05),
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
                              color: const Color(0xFFDC2626)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.schedule_rounded,
                              color: Color(0xFFDC2626),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Flight Duration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: 'Hours',
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _hours = int.tryParse(v) ?? 0,
                              validator: (v) => (int.tryParse(v ?? '') ?? 0) < 0
                                  ? 'Invalid'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              label: 'Minutes',
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _minutes = int.tryParse(v) ?? 0,
                              validator: (v) => (int.tryParse(v ?? '') ?? 0) < 0
                                  ? 'Invalid'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Aircraft Type
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.airplanemode_active_rounded,
                              color: Color(0xFF7C3AED),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Aircraft Type',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: aircraftTypes.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      child: const Text(
                                        'No aircraft available.',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    )
                                  : DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        hintText: 'Select Aircraft',
                                        hintStyle: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      dropdownColor: Colors.white,
                                      initialValue: aircraftTypes.isNotEmpty &&
                                              aircraftTypes
                                                  .contains(_aircraftType)
                                          ? _aircraftType
                                          : null,
                                      items: aircraftTypes
                                          .map(
                                            (type) => DropdownMenuItem(
                                              value: type,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      type,
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      // Prevent dropdown from closing immediately
                                                      Future.delayed(
                                                          const Duration(
                                                              milliseconds:
                                                                  100), () {
                                                        if (context.mounted) {
                                                          Navigator.of(context).pop();
                                                        }
                                                        if (mounted) {
                                                          _showDeleteConfirmationDialog(type);
                                                        }
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      child: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color:
                                                            Color(0xFFDC2626),
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _aircraftType = v),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3949ab),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add_rounded,
                                  color: Colors.white),
                              tooltip: 'Add Aircraft',
                              onPressed: _showAddAircraftDialog,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Role and Flight Type Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF334155).withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pilot Role
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Color(0xFFEA580C),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Pilot Role',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonFormField<PilotRole>(
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            hintText: 'Select Role',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          dropdownColor: Colors.white,
                          initialValue: _pilotRole,
                          items: PilotRole.values
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    _getPilotRoleName(role),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _pilotRole = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Day/Night and Simulation toggles
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0891B2)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.wb_sunny_rounded,
                              color: Color(0xFF0891B2),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Flight Conditions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Day/Night Toggle
                      Container(
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
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isDay = true),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _isDay
                                        ? const Color(0xFF3949ab)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wb_sunny_rounded,
                                        color: _isDay
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Day',
                                        style: TextStyle(
                                          color: _isDay
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isDay = false),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: !_isDay
                                        ? const Color(0xFF3949ab)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.nights_stay_rounded,
                                        color: !_isDay
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Night',
                                        style: TextStyle(
                                          color: !_isDay
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Simulation Toggle - New Design Like Day/Night
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.computer_rounded,
                              color: Color(0xFF059669),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Flight Mode',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
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
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isSim = false),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: !_isSim
                                        ? const Color(0xFF3949ab)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.flight_takeoff_rounded,
                                        color: !_isSim
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Real',
                                        style: TextStyle(
                                          color: !_isSim
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isSim = true),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _isSim
                                        ? const Color(0xFF3949ab)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.computer_rounded,
                                        color: _isSim
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Simulator',
                                        style: TextStyle(
                                          color: _isSim
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3949ab), Color(0xFF5e35b1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3949ab).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        if (_date == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            _buildSnackBar('Please select a date',
                                isError: true),
                          );
                          return;
                        }
                        if (_selectedTypes.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            _buildSnackBar(
                                'Please select at least one flight type',
                                isError: true),
                          );
                          return;
                        }
                        if (_hours == 0 && _minutes == 0) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            _buildSnackBar('Please enter flight duration',
                                isError: true),
                          );
                          return;
                        }
                        if (_aircraftType == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            _buildSnackBar('Please select an aircraft type',
                                isError: true),
                          );
                          return;
                        }
                        if (_pilotRole == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            _buildSnackBar('Please select a pilot role',
                                isError: true),
                          );
                          return;
                        }

                        final log = FlightLog(
                          date: _date!,
                          flightTypes: List<FlightType>.from(_selectedTypes),
                          durationHours: _hours,
                          durationMinutes: _minutes,
                          aircraftType: _aircraftType!,
                          pilotRole: _pilotRole!,
                          isDayFlight: _isDay,
                          isSimulated: _isSim,
                        );

                        try {
                          await ref
                              .read(flightLogsProvider.notifier)
                              .addFlightLog(log);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            _buildSnackBar('Flight saved successfully'),
                          );
                          _resetForm();
                          Navigator.pop(context);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            _buildSnackBar(
                                'Error saving flight: ${e.toString()}',
                                isError: true),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.save_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Save Flight',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 50, // تقليل الارتفاع
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8, // تقليل الـ padding العمودي
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
            fontSize: 14, // تقليل حجم النص
          ),
        ),
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
    );
  }

  FlightTypeInfo _getFlightTypeInfo(FlightType type) {
    switch (type) {
      case FlightType.local:
        return FlightTypeInfo('Local', Icons.location_on_outlined);
      case FlightType.mission:
        return FlightTypeInfo('Mission', Icons.military_tech_outlined);
      case FlightType.xc:
        return FlightTypeInfo('Cross Country', Icons.flight_takeoff_rounded);
      case FlightType.zone:
        return FlightTypeInfo('Zone', Icons.radar_outlined);
      case FlightType.range:
        return FlightTypeInfo('Range', Icons.gps_fixed_outlined);
      case FlightType.formation:
        return FlightTypeInfo('Formation', Icons.group_work_outlined);
      case FlightType.currencyFlight:
        return FlightTypeInfo('Currency', Icons.schedule_outlined);
      case FlightType.landingGround:
        return FlightTypeInfo('Landing Ground', Icons.flight_land_outlined);
      case FlightType.navalOps:
        return FlightTypeInfo('Naval OPS', Icons.directions_boat_outlined);
      case FlightType.lowLevel:
        return FlightTypeInfo('Low Level', Icons.trending_down_outlined);
    }
  }

  String _getPilotRoleName(PilotRole role) {
    switch (role) {
      case PilotRole.ip:
        return 'IP';
      case PilotRole.mtp:
        return 'MTP';
      case PilotRole.pic:
        return 'PIC';
      case PilotRole.cpgGunner:
        return 'CPG GUNNER';
    }
  }

  SnackBar _buildSnackBar(String message, {bool isError = false}) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor:
          isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
    );
  }
}

class FlightTypeInfo {
  final String name;
  final IconData icon;

  FlightTypeInfo(this.name, this.icon);
}

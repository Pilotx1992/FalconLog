import 'package:flutter/material.dart';
import 'models.dart';
import 'package:provider/provider.dart';
import 'flight_log_provider.dart';

class LogFlightScreen extends StatefulWidget {
  const LogFlightScreen({super.key});

  @override
  State<LogFlightScreen> createState() => _LogFlightScreenState();
}

class _LogFlightScreenState extends State<LogFlightScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _date;
  final List<FlightType> _selectedTypes = [];
  int _hours = 0;
  int _minutes = 0;
  String _aircraftType = '';
  PilotRole? _pilotRole;
  String _base = '';
  bool _isDay = true;
  bool _isSim = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FlightLogProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Log New Flight')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Date
              ListTile(
                title: Text(
                  _date == null
                      ? 'Select Date'
                      : _date!.toLocal().toString().split(' ')[0],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              // Flight Types (multi-select)
              Text(
                'Flight Type(s)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: FlightType.values.map((type) {
                  return FilterChip(
                    label: Text(type.name),
                    selected: _selectedTypes.contains(type),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTypes.add(type);
                        } else {
                          _selectedTypes.remove(type);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Duration
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Hours'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _hours = int.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Minutes'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _minutes = int.tryParse(v) ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Aircraft Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Aircraft Type'),
                value: provider.aircraftTypes.isNotEmpty ? _aircraftType : null,
                items: provider.aircraftTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _aircraftType = v ?? ''),
              ),
              const SizedBox(height: 12),
              // Pilot Role
              DropdownButtonFormField<PilotRole>(
                decoration: const InputDecoration(labelText: 'Pilot Role'),
                value: _pilotRole,
                items: PilotRole.values
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _pilotRole = v),
              ),
              const SizedBox(height: 12),
              // Base
              TextFormField(
                decoration: const InputDecoration(labelText: 'Base'),
                onChanged: (v) => _base = v,
              ),
              const SizedBox(height: 12),
              // Day/Night Toggle
              SwitchListTile(
                title: Text(_isDay ? 'Day Flight' : 'Night Flight'),
                value: _isDay,
                onChanged: (v) => setState(() => _isDay = v),
              ),
              // Simulated/Real Toggle
              SwitchListTile(
                title: Text(_isSim ? 'Simulated Flight' : 'Real Flight'),
                value: _isSim,
                onChanged: (v) => setState(() => _isSim = v),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() &&
                      _date != null &&
                      _selectedTypes.isNotEmpty &&
                      _aircraftType.isNotEmpty &&
                      _pilotRole != null) {
                    provider.addFlightLog(
                      FlightLog(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        date: _date!,
                        flightTypes: _selectedTypes,
                        durationHours: _hours,
                        durationMinutes: _minutes,
                        aircraftType: _aircraftType,
                        pilotRole: _pilotRole!,
                        base: _base,
                        isDayFlight: _isDay,
                        isSimulated: _isSim,
                        createdAt: DateTime.now(),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save Flight'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

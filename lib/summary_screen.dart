import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'flight_log_provider.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = Provider.of<FlightLogProvider>(context).summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Time Summary'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(
                    label: 'Total Flight Time',
                    value: summary.totalFlightHours.toStringAsFixed(1),
                    icon: Icons.access_time),
                _StatCard(
                    label: 'Day Time Flight',
                    value: summary.dayTimeHours.toStringAsFixed(1),
                    icon: Icons.wb_sunny),
                _StatCard(
                    label: 'Night Time Flight',
                    value: summary.nightTimeHours.toStringAsFixed(1),
                    icon: Icons.nights_stay),
              ],
            ),
            const SizedBox(height: 32),
            Center(
                child: Text('Breakdown and charts can be added here.',
                    style: Theme.of(context).textTheme.titleMedium)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

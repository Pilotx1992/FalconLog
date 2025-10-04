import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../backup/models/backup_provider_enum.dart';
import '../providers/backup_service_provider.dart';

class _StatusInfo {
  final Color color;
  final IconData icon;
  final String text;

  const _StatusInfo({
    required this.color,
    required this.icon,
    required this.text,
  });
}

/// Auto Backup Configuration Widget
/// Use this in your settings screen to configure auto backup options
class AutoBackupConfigWidget extends ConsumerWidget {
  const AutoBackupConfigWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(autoBackupConfigProvider);
    final autoBackupStatus = ref.watch(autoBackupStatusProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.backup_rounded,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Auto Backup Configuration',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Status indicator
            _buildStatusIndicator(context, autoBackupStatus),
            
            const SizedBox(height: 20),
            
            // Enable/Disable toggle
            SwitchListTile(
              title: const Text('Enable Auto Backup'),
              subtitle: const Text('Automatically backup flight data'),
              value: config.enabled,
              onChanged: null, // TODO: Implement state management
            ),
            
            if (config.enabled) ...[
              const Divider(),
              
              // Backup Interval
              ListTile(
                title: const Text('Backup Frequency'),
                subtitle: Text(config.interval.displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showIntervalPicker(context, ref, config),
              ),
              
              // Backup Trigger
              ListTile(
                title: const Text('Backup Trigger'),
                subtitle: Text(config.trigger.displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTriggerPicker(context, ref, config),
              ),
              
              // WiFi requirement
              SwitchListTile(
                title: const Text('Require WiFi'),
                subtitle: const Text('Only backup when connected to WiFi'),
                value: config.requiresWifi,
                onChanged: null, // TODO: Implement state management
              ),
              
              // Preferred Provider
              ListTile(
                title: const Text('Preferred Provider'),
                subtitle: Text(config.preferredProvider == BackupProvider.firebase 
                    ? 'Cloud Backup' 
                    : 'Local Backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showProviderPicker(context, ref, config),
              ),
              
              // Max backups
              ListTile(
                title: const Text('Max Backups to Keep'),
                subtitle: Text('${config.maxBackups} backups'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showMaxBackupsPicker(context, ref, config),
              ),
              
              const Divider(),
              
              // Manual trigger button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement backup trigger
                  },
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('Backup Now'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, String status) {
    final statusInfo = _getStatusInfo(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusInfo.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusInfo.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusInfo.icon, color: statusInfo.color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusInfo.text,
              style: TextStyle(
                color: statusInfo.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(String status) {
    return _StatusInfo(
      color: Colors.green,
      icon: Icons.backup_rounded,
      text: status,
    );
  }


  void _showIntervalPicker(BuildContext context, WidgetRef ref, AutoBackupConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Frequency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AutoBackupInterval.values.map((interval) {
            return RadioListTile<AutoBackupInterval>(
              title: Text(interval.displayName),
              subtitle: Text(_getIntervalDescription(interval)),
              value: interval,
              groupValue: config.interval,
              onChanged: null, // TODO: Implement state management
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTriggerPicker(BuildContext context, WidgetRef ref, AutoBackupConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Trigger'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AutoBackupTrigger.values.map((trigger) {
            return RadioListTile<AutoBackupTrigger>(
              title: Text(trigger.displayName),
              subtitle: Text(_getTriggerDescription(trigger)),
              value: trigger,
              groupValue: config.trigger,
              onChanged: (value) {
                // TODO: Implement state management
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showProviderPicker(BuildContext context, WidgetRef ref, AutoBackupConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preferred Backup Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<BackupProvider>(
              title: const Text('Cloud Backup'),
              subtitle: const Text('Secure cloud storage'),
              value: BackupProvider.firebase,
              groupValue: config.preferredProvider,
              onChanged: (value) {
                // TODO: Implement state management
              },
            ),
            RadioListTile<BackupProvider>(
              title: const Text('Local Backup'),
              subtitle: const Text('Store on device'),
              value: BackupProvider.local,
              groupValue: config.preferredProvider,
              onChanged: (value) {
                // TODO: Implement state management
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMaxBackupsPicker(BuildContext context, WidgetRef ref, AutoBackupConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Max Backups to Keep'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 20, 30].map((count) {
            return RadioListTile<int>(
              title: Text('$count backups'),
              value: count,
              groupValue: config.maxBackups,
              onChanged: (value) {
                // TODO: Implement state management
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getIntervalDescription(AutoBackupInterval interval) {
    switch (interval) {
      case AutoBackupInterval.daily:
        return 'Backup once per day';
      case AutoBackupInterval.weekly:
        return 'Backup once per week';
      case AutoBackupInterval.afterEachFlight:
        return 'Backup after each flight';
      case AutoBackupInterval.manual:
        return 'No automatic backups';
    }
  }

  String _getTriggerDescription(AutoBackupTrigger trigger) {
    switch (trigger) {
      case AutoBackupTrigger.timeInterval:
        return 'Based on time interval only';
      case AutoBackupTrigger.flightAdded:
        return 'When a new flight is added';
      case AutoBackupTrigger.appClose:
        return 'When the app is closed';
      case AutoBackupTrigger.combined:
        return 'Multiple trigger conditions';
    }
  }
}

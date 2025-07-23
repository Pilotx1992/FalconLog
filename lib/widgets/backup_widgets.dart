import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight_log.dart';
import '../providers/backup_provider.dart';
import '../services/backup_service.dart';

/// Professional backup management UI components
class BackupOptionsBottomSheet extends ConsumerWidget {
  const BackupOptionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupStatus = ref.watch(backupStatusProvider);
    final recommendation = ref.watch(backupRecommendationProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final currentProvider = ref.watch(backupProviderProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // تحديد الحد الأقصى للارتفاع
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Smart Backup',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _getStatusMessage(backupStatus, recommendation),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Provider Options
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup Provider',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Firebase option
                        _buildProviderOption(
                          context: context,
                          ref: ref,
                          provider: BackupProvider.firebase,
                          title: 'Cloud Backup',
                          subtitle: isOnline ? 'Secure cloud storage' : 'Requires internet connection',
                          icon: Icons.cloud_outlined,
                          iconColor: Colors.orange,
                          isSelected: currentProvider == BackupProvider.firebase,
                          isEnabled: isOnline,
                          disabledReason: !isOnline ? 'No internet connection' : null,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Local option
                        _buildProviderOption(
                          context: context,
                          ref: ref,
                          provider: BackupProvider.local,
                          title: 'Local Backup',
                          subtitle: 'Store on device',
                          icon: Icons.phone_android_rounded,
                          iconColor: Colors.blue,
                          isSelected: currentProvider == BackupProvider.local,
                          isEnabled: true,
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Manual Backup Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _performManualBackup(ref),
                            icon: const Icon(Icons.backup_rounded),
                            label: const Text('Create Backup Now'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Restore Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRestoreConfirmation(context, ref),
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('Restore from Backup'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom safe area
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOption({
    required BuildContext context,
    required WidgetRef ref,
    required BackupProvider provider,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required bool isEnabled,
    String? disabledReason,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled 
          ? () {
              // Show feedback to user
              if (provider == BackupProvider.firebase) {
                if (ref.read(isOnlineProvider)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to Cloud Backup'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Switched to Local Backup'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? iconColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? iconColor.withOpacity(0.05) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isEnabled ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? iconColor : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? Colors.black87 : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      disabledReason ?? subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isEnabled 
                          ? Colors.grey[600]
                          : Colors.grey[500],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected) 
                Icon(
                  Icons.check_circle_rounded,
                  color: iconColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getStatusMessage(BackupStatus status, BackupRecommendation recommendation) {
    if (status.toString().contains('Error')) {
      return 'Last backup failed. Please try again.';
    }
    if (status.toString().contains('Success')) {
      return 'Last backup completed successfully.';
    }
    if (recommendation.toString().contains('FirstBackup')) {
      return 'Create your first backup to secure your flight data.';
    }
    if (recommendation.toString().contains('Overdue')) {
      return 'Your backup is overdue. Regular backups help protect your data.';
    }
    if (recommendation.toString().contains('Recommended')) {
      return 'A backup is recommended to keep your data safe.';
    }
    return 'Your flight data is ready for backup.';
  }
  
  void _performManualBackup(WidgetRef ref) async {
    // TODO: Get actual flight logs from provider
    final List<FlightLog> logs = []; // ref.read(flightLogsProvider).valueOrNull ?? [];
    final provider = ref.read(backupProviderProvider);
    
    await ref.read(backupStatusProvider.notifier).performBackup(logs, provider);
  }
  
  void _showRestoreConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'This will replace all current flight data with the backup. '
          'This action cannot be undone. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // For general restore, we'll need to implement backup selection
              // TODO: Show backup selection dialog first
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

/// Backup history management bottom sheet
class BackupHistoryBottomSheet extends ConsumerWidget {
  const BackupHistoryBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupHistory = ref.watch(backupHistoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // تحديد الحد الأقصى للارتفاع
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Backup History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // History List - القابل للتمرير
          Expanded(
            child: backupHistory.when(
              data: (history) {
                if (history.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.backup_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No backups yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first backup to see it here',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final backup = history[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: backup.provider == BackupProvider.firebase 
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          backup.provider == BackupProvider.firebase 
                            ? Icons.cloud_outlined
                            : Icons.phone_android_rounded,
                          color: backup.provider == BackupProvider.firebase 
                            ? Colors.orange
                            : Colors.blue,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        backup.provider == BackupProvider.firebase ? 'Cloud Backup' : 'Local Backup',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${backup.logsCount} flights • ${backup.formattedSize}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            backup.formattedDate,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          switch (action) {
                            case 'restore':
                              _showRestoreConfirmation(context, ref, backup);
                              break;
                            case 'delete':
                              _showDeleteConfirmation(context, ref, backup);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(Icons.restore_rounded, size: 20),
                                SizedBox(width: 12),
                                Text('Restore'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load backup history',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.red[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }

  void _showRestoreConfirmation(BuildContext context, WidgetRef ref, BackupInfo backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Text(
          'Restore ${backup.logsCount} flights from ${backup.formattedDate}? '
          'This will replace all current data.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(backupStatusProvider.notifier).performRestore(backup);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, BackupInfo backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text(
          'Delete backup from ${backup.formattedDate}? '
          'This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement backup deletion
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

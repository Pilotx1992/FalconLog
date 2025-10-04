import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backup_service_provider.dart';
import '../backup/models/backup_provider_enum.dart';

/// Professional backup management UI components
class BackupOptionsBottomSheet extends ConsumerWidget {
  const BackupOptionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupStatus = ref.watch(backupStatusProvider);
    final recommendation = ref.watch(backupRecommendationProvider);
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final isOnline = isOnlineAsync.when(
      data: (value) => value,
      loading: () => false,
      error: (_, __) => false,
    );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Switched to Cloud Backup'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
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
            color: isSelected ? iconColor.withValues(alpha: 0.05) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isEnabled ? 0.1 : 0.05),
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
    // Manual backup implementation
    // final backupService = ref.read(backupServiceProvider);
    // await backupService.startBackup();
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
              // Show backup selection dialog first
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
            child: backupHistory.isEmpty
                ? Padding(
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
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: backupHistory.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final backup = backupHistory[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: backup.provider == BackupProvider.firebase
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.2),
                            child: Icon(
                              backup.provider == BackupProvider.firebase
                                  ? Icons.cloud_outlined
                                  : Icons.phone_android_rounded,
                              color: backup.provider == BackupProvider.firebase
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                          title: Text(
                            backup.provider == BackupProvider.firebase
                                ? 'Cloud Backup'
                                : 'Local Backup',
                          ),
                          subtitle: Text(
                            '${backup.logsCount} logs • ${backup.formattedSize}\n${backup.formattedDate}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'restore') {
                                _showRestoreConfirmation(context, ref, backup);
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(context, ref, backup);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'restore',
                                child: Text('Restore'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
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
          'Restore backup from ${backup.formattedDate}? '
          'This will replace your current flight logs. '
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
              // Implement restore
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
              // Implement backup deletion
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

// Removed duplicate helper methods - they were defined earlier in the file

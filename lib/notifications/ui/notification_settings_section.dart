import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/app_snack_bar.dart';
import '../notification_preferences_provider.dart';
import '../schedulers/backup_notification_dispatcher.dart';
import '../services/local_notification_service.dart';
import '../services/notification_permission_service.dart';

/// Notification settings rows for [SettingsScreen].
class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({
    super.key,
    required this.buildTile,
    required this.buildDivider,
  });

  final Widget Function({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool bareTrailing,
  }) buildTile;

  final Widget Function() buildDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return prefsAsync.when(
      loading: () => buildTile(
        icon: Icons.notifications_rounded,
        title: 'Notifications',
        onTap: () {},
      ),
      error: (_, __) => buildTile(
        icon: Icons.notifications_rounded,
        title: 'Notifications',
        onTap: () {},
      ),
      data: (prefs) => FutureBuilder<bool>(
        future: NotificationPermissionService.areNotificationsEnabled(),
        builder: (context, permissionSnapshot) {
          final systemNotificationsEnabled =
              permissionSnapshot.data ?? true;
          final showPermissionHint = prefs.enableNotifications &&
              !systemNotificationsEnabled;

          return Column(
        children: [
          buildTile(
            icon: Icons.notifications_active_rounded,
            title: 'Enable Notifications',
            subtitle: showPermissionHint
                ? 'Blocked in system settings — open Settings to allow'
                : null,
            onTap: showPermissionHint
                ? () => NotificationPermissionService
                    .openNotificationSettings()
                : null,
            trailing: Switch(
              value: prefs.enableNotifications,
              onChanged: (value) => _onMasterToggle(context, ref, value),
            ),
            bareTrailing: true,
          ),
          buildDivider(),
          buildTile(
            icon: Icons.backup_rounded,
            title: 'Backup Notifications',
            trailing: Switch(
              value: prefs.backupNotificationsEnabled,
              onChanged: prefs.enableNotifications
                  ? (value) => ref
                      .read(notificationPreferencesProvider.notifier)
                      .setBackupNotificationsEnabled(value)
                  : null,
            ),
            bareTrailing: true,
          ),
          buildDivider(),
          buildTile(
            icon: Icons.schedule_rounded,
            title: 'Currency Reminder',
            trailing: Switch(
              value: prefs.currencyExpiryNotificationsEnabled,
              onChanged: prefs.enableNotifications
                  ? (value) => ref
                      .read(notificationPreferencesProvider.notifier)
                      .setCurrencyExpiryNotificationsEnabled(value)
                  : null,
            ),
            bareTrailing: true,
          ),
          if (kDebugMode) ...[
            buildDivider(),
            buildTile(
              icon: Icons.bug_report_rounded,
              title: 'Send test backup notification',
              onTap: () async {
                await BackupNotificationDispatcher.onBackupSuccess();
              },
            ),
          ],
        ],
          );
        },
      ),
    );
  }

  Future<void> _onMasterToggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (!enabled) {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setEnableNotifications(false);
      return;
    }

    final granted = await NotificationPermissionService.requestPermission();
    if (!granted) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message:
              'Notification permission is required. Open Settings to allow notifications.',
          isError: true,
        );
        await _showPermissionDeniedSheet(context);
      }
      return;
    }

    await ref
        .read(notificationPreferencesProvider.notifier)
        .setEnableNotifications(true);
    await LocalNotificationService.initialize(isBackground: false);
  }

  Future<void> _showPermissionDeniedSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Notifications unavailable',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Allow notifications for FalconLog in system settings to use backup and currency alerts.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  NotificationPermissionService.openNotificationSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

import '../../backup/ui/backup_settings_page.dart';
import '../../helpers/auth_state_helper.dart';
import '../../screens/settings_screen.dart';
import '../../services/navigation_service.dart';
import '../../settings/currency_alert_settings_repository.dart';
import '../../settings/ui/currency_alert_setup_screen.dart';
import '../domain/notification_payload.dart';
import '../domain/pending_notification_route_store.dart';

/// Routes notification taps to the correct FalconLog screen.
class NotificationRouteHandler {
  NotificationRouteHandler._();

  static final _logger = Logger('NotificationRouteHandler');

  static void onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    unawaited(handlePayload(payload));
  }

  static Future<void> handlePayload(String payload) async {
    try {
      final navigated = await _tryNavigate(payload);
      if (navigated) {
        await PendingNotificationRouteStore.clear();
        return;
      }
      await PendingNotificationRouteStore.savePayload(payload);
    } catch (e, stackTrace) {
      _logger.warning('handlePayload failed', e, stackTrace);
    }
  }

  /// Attempts pending payload from cold start (bounded retries).
  static Future<void> processPendingPayloadOnStartup() async {
    try {
      final payload =
          await PendingNotificationRouteStore.takePayloadIfUnderAttemptLimit();
      if (payload == null) return;

      final navigated = await _tryNavigate(payload);
      if (navigated) {
        await PendingNotificationRouteStore.clear();
        return;
      }
      await PendingNotificationRouteStore.recordFailedNavigationAttempt();
    } catch (e, stackTrace) {
      _logger.warning('processPendingPayloadOnStartup failed', e, stackTrace);
    }
  }

  static Future<bool> _tryNavigate(String payload) async {
    final context = NavigationService.context;
    if (context == null || !context.mounted) {
      return false;
    }
    if (!AuthStateHelper.isLoggedIn) {
      return false;
    }

    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return false;

    switch (payload) {
      case NotificationPayload.backupSettings:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const BackupSettingsPage(),
          ),
        );
        return true;
      case NotificationPayload.currencyAlertSettings:
        final settings = await CurrencyAlertSettingsRepository().load();
        if (!settings.hasCompletedSetup) {
          await navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const CurrencyAlertSetupScreen(),
            ),
          );
        } else {
          await navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const SettingsScreen(),
            ),
          );
        }
        return true;
      default:
        return false;
    }
  }
}

/// Background isolate entry point for notification taps.
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  unawaited(PendingNotificationRouteStore.savePayload(payload));
}

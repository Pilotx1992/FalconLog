import 'package:falconlog/notifications/domain/notification_payload.dart';
import 'package:falconlog/notifications/domain/pending_notification_route_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('clear removes pending payload', () async {
    await PendingNotificationRouteStore.savePayload(
      NotificationPayload.backupSettings,
    );
    await PendingNotificationRouteStore.clear();
    final payload =
        await PendingNotificationRouteStore.takePayloadIfUnderAttemptLimit();
    expect(payload, isNull);
  });

  test('max attempts stops returning payload', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      NotificationPayload.pendingPayloadKey,
      NotificationPayload.currencyAlertSettings,
    );
    await prefs.setInt(
      NotificationPayload.pendingAttemptCountKey,
      NotificationPayload.maxPendingNavigationAttempts,
    );

    final payload =
        await PendingNotificationRouteStore.takePayloadIfUnderAttemptLimit();
    expect(payload, isNull);
  });

  test('failed attempt increments counter', () async {
    await PendingNotificationRouteStore.savePayload(
      NotificationPayload.backupSettings,
    );
    await PendingNotificationRouteStore.recordFailedNavigationAttempt();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(NotificationPayload.pendingAttemptCountKey),
      1,
    );
  });
}

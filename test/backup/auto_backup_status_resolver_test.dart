import 'package:falconlog/backup/models/backup_provider_enum.dart';
import 'package:falconlog/backup/utils/auto_backup_status_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoBackupStatusResolver', () {
    test('wifi-only + no network shows waiting for Wi-Fi', () {
      expect(
        AutoBackupStatusResolver.resolvePendingMessage(
          const AutoBackupPendingContext(
            wifiOnly: true,
            provider: BackupProvider.googleDrive,
            networkSatisfied: false,
            driveReady: true,
            operationLockFree: true,
          ),
        ),
        AutoBackupStatusResolver.waitingForWifi,
      );
    });

    test('stale waiting_for_wifi is not used — wifi available shows scheduled',
        () {
      expect(
        AutoBackupStatusResolver.resolvePendingMessage(
          const AutoBackupPendingContext(
            wifiOnly: true,
            provider: BackupProvider.googleDrive,
            networkSatisfied: true,
            driveReady: true,
            operationLockFree: true,
          ),
        ),
        AutoBackupStatusResolver.scheduledWithAndroid,
      );
    });

    test('drive auth blocks pending message', () {
      expect(
        AutoBackupStatusResolver.resolvePendingMessage(
          const AutoBackupPendingContext(
            wifiOnly: true,
            provider: BackupProvider.googleDrive,
            networkSatisfied: true,
            driveReady: false,
            operationLockFree: true,
          ),
        ),
        AutoBackupStatusResolver.waitingForDriveAuth,
      );
    });

    test('operation lock blocks pending message', () {
      expect(
        AutoBackupStatusResolver.resolvePendingMessage(
          const AutoBackupPendingContext(
            wifiOnly: false,
            provider: BackupProvider.local,
            networkSatisfied: true,
            driveReady: true,
            operationLockFree: false,
          ),
        ),
        AutoBackupStatusResolver.waitingForConditions,
      );
    });

    test('cellular On with mobile network does not show waiting for Wi-Fi', () {
      expect(
        AutoBackupStatusResolver.resolvePendingMessage(
          const AutoBackupPendingContext(
            wifiOnly: false,
            provider: BackupProvider.googleDrive,
            networkSatisfied: true,
            driveReady: true,
            operationLockFree: true,
          ),
        ),
        isNot(AutoBackupStatusResolver.waitingForWifi),
      );
    });

    test(
        'cellular On without any network shows scheduled not waiting for Wi-Fi',
        () {
      expect(
        AutoBackupStatusResolver.resolvePendingMessage(
          const AutoBackupPendingContext(
            wifiOnly: false,
            provider: BackupProvider.googleDrive,
            networkSatisfied: false,
            driveReady: true,
            operationLockFree: true,
          ),
        ),
        AutoBackupStatusResolver.scheduledWithAndroid,
      );
    });
  });
}

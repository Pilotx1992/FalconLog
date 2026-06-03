import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/backup/utils/backup_account_identity_guard.dart';

BackupAccountIdentitySnapshot _snap({
  String? firebaseEmail,
  List<String> firebaseProviderIds = const [],
  String? googleDriveEmail,
  String? keyOwnerEmail,
}) {
  return BackupAccountIdentitySnapshot(
    firebaseEmail: firebaseEmail,
    firebaseProviderIds: firebaseProviderIds,
    googleDriveEmail: googleDriveEmail,
    keyOwnerEmail: keyOwnerEmail,
  );
}

void main() {
  group('checkCloudBackup', () {
    test('aligned Firebase, Drive, and key owner allows backup', () {
      final result = BackupAccountIdentityGuard.checkCloudBackup(
        _snap(
          firebaseEmail: 'Pilot@Example.com',
          firebaseProviderIds: ['google.com'],
          googleDriveEmail: 'pilot@example.com',
          keyOwnerEmail: 'pilot@example.com',
        ),
      );
      expect(result.allowed, isTrue);
    });

    test('Firebase email differs from Drive blocks backup', () {
      final result = BackupAccountIdentityGuard.checkCloudBackup(
        _snap(
          firebaseEmail: 'user@gmail.com',
          googleDriveEmail: 'other@gmail.com',
          keyOwnerEmail: 'user@gmail.com',
        ),
      );
      expect(result.allowed, isFalse);
      expect(result.message, BackupAccountIdentityGuard.accountMismatchMessage);
    });

    test('key owner differs from Drive blocks backup', () {
      final result = BackupAccountIdentityGuard.checkCloudBackup(
        _snap(
          firebaseEmail: 'owner@gmail.com',
          googleDriveEmail: 'other@gmail.com',
          keyOwnerEmail: 'owner@gmail.com',
        ),
      );
      expect(result.allowed, isFalse);
      expect(result.message, BackupAccountIdentityGuard.accountMismatchMessage);
    });

    test('no Google Drive account blocks cloud backup', () {
      final result = BackupAccountIdentityGuard.checkCloudBackup(
        _snap(
          firebaseEmail: 'user@gmail.com',
          firebaseProviderIds: ['password'],
          keyOwnerEmail: 'user@gmail.com',
        ),
      );
      expect(result.allowed, isFalse);
      expect(result.message, contains('Google Drive sign-in is required'));
    });

    test('email/password Firebase user without Drive cannot cloud backup', () {
      final result = BackupAccountIdentityGuard.checkCloudBackup(
        _snap(
          firebaseEmail: 'pilot@example.com',
          firebaseProviderIds: ['password'],
        ),
      );
      expect(result.allowed, isFalse);
    });
  });

  group('checkCloudRestore', () {
    test('wrong Google account cannot restore owned key backup', () {
      final result = BackupAccountIdentityGuard.checkCloudRestore(
        _snap(
          firebaseEmail: 'owner@gmail.com',
          googleDriveEmail: 'wrong@gmail.com',
          keyOwnerEmail: 'owner@gmail.com',
        ),
      );
      expect(result.allowed, isFalse);
      expect(result.message, BackupAccountIdentityGuard.accountMismatchMessage);
    });

    test('matching identities allow restore', () {
      final result = BackupAccountIdentityGuard.checkCloudRestore(
        _snap(
          googleDriveEmail: 'owner@gmail.com',
          keyOwnerEmail: 'owner@gmail.com',
        ),
      );
      expect(result.allowed, isTrue);
    });
  });
}

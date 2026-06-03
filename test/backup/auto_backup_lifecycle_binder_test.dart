import 'package:falconlog/backup/services/backup_service.dart';
import 'package:falconlog/backup/ui/auto_backup_lifecycle_binder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoBackupLifecycleBinder', () {
    testWidgets('resume calls reconciler once after debounce', (tester) async {
      var reconcileCount = 0;
      BackupService.startBackupForTesting = null;

      await tester.pumpWidget(
        MaterialApp(
          home: AutoBackupLifecycleBinder(
            debounceDuration: const Duration(seconds: 2),
            onResumeReconcile: () async {
              reconcileCount++;
            },
            child: const SizedBox.shrink(),
          ),
        ),
      );

      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump(const Duration(seconds: 1));
      expect(reconcileCount, 0);

      await tester.pump(const Duration(seconds: 2));
      expect(reconcileCount, 1);
    });

    testWidgets('rapid resume events trigger single reconcile after debounce',
        (tester) async {
      var reconcileCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AutoBackupLifecycleBinder(
            debounceDuration: const Duration(seconds: 2),
            onResumeReconcile: () async {
              reconcileCount++;
            },
            child: const SizedBox.shrink(),
          ),
        ),
      );

      final binding = tester.binding;
      for (var i = 0; i < 5; i++) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 200));
      }

      await tester.pump(const Duration(seconds: 1));
      expect(reconcileCount, 0);

      await tester.pump(const Duration(seconds: 2));
      expect(reconcileCount, 1);
    });

    testWidgets('resume does not invoke BackupService.startBackup', (tester) async {
      var backupInvoked = false;
      BackupService.startBackupForTesting =
          ({bool interactive = true, providerOverride}) async {
        backupInvoked = true;
        return true;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: AutoBackupLifecycleBinder(
            debounceDuration: const Duration(milliseconds: 100),
            onResumeReconcile: () async {},
            child: const SizedBox.shrink(),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 150));

      expect(backupInvoked, isFalse);
      BackupService.startBackupForTesting = null;
    });
  });
}

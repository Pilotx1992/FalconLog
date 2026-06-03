import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:falconlog/backup/utils/auto_backup_debug_qa.dart';
import 'package:falconlog/backup/utils/auto_backup_due_engine.dart';
import 'package:falconlog/backup/utils/auto_backup_reconciler.dart';
import 'package:falconlog/backup/utils/auto_backup_state_store.dart';
import 'package:falconlog/backup/utils/backup_scheduler.dart';
import 'package:falconlog/backup/utils/cleanup_old_workers.dart';
import 'package:falconlog/core/services/hive_initialization_service.dart';
import 'package:falconlog/firebase_options.dart';
import 'package:falconlog/models/flight_log.dart';

/// On-device KB2003 auto backup QA (debug builds only).
///
/// Host script disables/enables Wi-Fi when it sees [qaSignal] lines on stdout.
const qaSignalPrefix = 'KB2003_QA_SIGNAL:';

void qaSignal(String step) {
  // ignore: avoid_print
  print('$qaSignalPrefix$step');
}

Future<void> _bootstrap() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await HiveInitializationService.initialize();
  await HiveInitializationService.openBox<FlightLog>('flightLogsBox');
  await BackupScheduler.initialize();
  await WorkManagerCleanup.cleanupOldTasks();
}

Future<Map<String, String>> _snapshot() => AutoBackupDebugQa.snapshotState();

Future<void> _dump(String label) async {
  qaSignal('DUMP_$label');
  await AutoBackupDebugQa.dumpStateToLog();
  final snap = await _snapshot();
  for (final e in snap.entries) {
    // ignore: avoid_print
    print('KB2003_QA_STATE:${e.key}=${e.value}');
  }
}

Future<void> _pollUntil(
  bool Function(Map<String, String> snap) done, {
  Duration timeout = const Duration(minutes: 3),
  Duration interval = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final snap = await _snapshot();
    if (done(snap)) return;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException('pollUntil timed out after ${timeout.inSeconds}s');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('KB2003 daily auto backup QA protocol', () async {
    if (!kDebugMode) {
      fail('KB2003 QA runs on debug builds only');
    }

    qaSignal('BOOTSTRAP_START');
    await _bootstrap();

    // 1–4: Daily auto backup ON, Wi-Fi only ON
    qaSignal('SETUP_DAILY');
    final scheduler = BackupScheduler();
    final scheduled = await scheduler.scheduleBackup(
      frequency: 'daily',
      wifiOnly: true,
    );
    expect(scheduled, isTrue);

    // 5: Clear daily state
    await AutoBackupDebugQa.clearDailyAutoBackupState();

    // 6: Due = now + 2 minutes
    final dueAt = await AutoBackupDebugQa.setDueTimeToNowPlusMinutes(2);
    qaSignal('DUE_AT=${dueAt.toIso8601String()}');

    // 7–8: Simulate Wi-Fi unavailable (wireless ADB drops if Wi-Fi is disabled).
    await AutoBackupDebugQa.setSimulateWifiUnavailable(true);
    qaSignal('SIMULATE_WIFI_OFF');
    final waitUntil = dueAt.add(const Duration(seconds: 15));
    final waitMs = waitUntil.difference(DateTime.now()).inMilliseconds;
    if (waitMs > 0) {
      qaSignal('WAITING_${waitMs}ms');
      await Future<void>.delayed(Duration(milliseconds: waitMs));
    }

    // Phase A: reconcile sets pending; catch-up blocked (no startBackup).
    qaSignal('PHASE_A_RECONCILE');
    await AutoBackupDebugQa.runReconcileNow();
    await AutoBackupDebugQa.runCatchupNow();
    await _dump('PHASE_A');

    final phaseA = await _snapshot();
    expect(phaseA['frequency'], 'daily');
    expect(phaseA['wifi_only'], 'true');
    expect(phaseA['pending_due_day'], isNot('(none)'));
    expect(phaseA['qa_simulate_wifi_unavailable'], 'true');
    expect(
      phaseA['last_failure_reason'],
      anyOf('waiting_for_wifi', contains('wifi')),
    );
    expect(phaseA['wm_daily_evaluator'], 'true');
    expect(phaseA['wm_interval_periodic'], 'false');

    final lastSuccessBefore = phaseA['last_success_due_day'];
    final lastSuccessAtBefore = phaseA['last_success_at'];
    final pendingDueDay = phaseA['pending_due_day']!;

    // Phase B: restore network and run catch-up once.
    await AutoBackupDebugQa.setSimulateWifiUnavailable(false);
    qaSignal('SIMULATE_WIFI_ON');
    await Future<void>.delayed(const Duration(seconds: 2));
    qaSignal('PHASE_B_RECONCILE');
    await AutoBackupDebugQa.runReconcileNow();
    await AutoBackupDebugQa.runCatchupNow();

    await _pollUntil(
      (snap) =>
          snap['pending_due_day'] == '(none)' &&
          snap['last_success_due_day'] == pendingDueDay &&
          snap['last_failure_reason'] == '(none)',
      timeout: const Duration(minutes: 5),
    );

    await _dump('PHASE_B');
    final phaseB = await _snapshot();
    expect(phaseB['pending_due_day'], '(none)');
    expect(phaseB['last_success_due_day'], pendingDueDay);
    expect(phaseB['last_success_at'], isNot('(none)'));
    expect(phaseB['last_failure_reason'], '(none)');

    if (lastSuccessBefore != '(none)') {
      expect(phaseB['last_success_due_day'], isNot(lastSuccessBefore));
    }
    if (lastSuccessAtBefore != '(none)') {
      expect(phaseB['last_success_at'], isNot(lastSuccessAtBefore));
    }

    // Resume simulation: reconcile 3× — must not re-backup same due day
    qaSignal('RESUME_SIMULATION');
    for (var i = 0; i < 3; i++) {
      await AutoBackupReconciler().reconcile();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    final afterResume = await _snapshot();
    expect(afterResume['last_success_due_day'], pendingDueDay);
    expect(afterResume['pending_due_day'], '(none)');

    // Weekly mutual exclusion
    qaSignal('WEEKLY_CHECK');
    await scheduler.scheduleBackup(frequency: 'weekly', wifiOnly: true);
    final weekly = await _snapshot();
    expect(weekly['frequency'], 'weekly');
    expect(weekly['wm_interval_periodic'], 'true');
    expect(weekly['wm_daily_evaluator'], 'false');
    expect(weekly['wm_catchup'], 'false');

    // Monthly mutual exclusion
    qaSignal('MONTHLY_CHECK');
    await scheduler.scheduleBackup(frequency: 'monthly', wifiOnly: true);
    final monthly = await _snapshot();
    expect(monthly['frequency'], 'monthly');
    expect(monthly['wm_interval_periodic'], 'true');
    expect(monthly['wm_daily_evaluator'], 'false');
    expect(monthly['wm_catchup'], 'false');

    // Restore daily + reset due + clear QA simulation
    qaSignal('RESTORE_DAILY');
    await AutoBackupDebugQa.setSimulateWifiUnavailable(false);
    await scheduler.scheduleBackup(frequency: 'daily', wifiOnly: true);
    await AutoBackupDebugQa.resetDueToProductionDefault();
    final dueMinute = await AutoBackupStateStore().getDueMinuteOfDay();
    expect(dueMinute, AutoBackupDueEngine.defaultDueMinuteOfDay);

    qaSignal('PASS');
  }, timeout: const Timeout(Duration(minutes: 12)));
}

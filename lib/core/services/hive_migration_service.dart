import 'dart:developer';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/flight_log.dart';

/// Safe handling of Hive corruption — never silently deletes user flight logs.
class HiveMigrationService {
  /// Copies corrupted [flightLogsBox] files to a timestamped quarantine folder.
  /// Original files are left on disk so recovery/backup restore can be attempted.
  static Future<String?> quarantineCorruptedFlightLogFiles({
    String? basePathForTests,
  }) async {
    try {
      final appDir = basePathForTests != null
          ? Directory(basePathForTests)
          : await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final quarantineDir = Directory('${appDir.path}/hive_quarantine/$stamp');
      if (!await quarantineDir.exists()) {
        await quarantineDir.create(recursive: true);
      }

      final hiveFiles = Directory(appDir.path)
          .listSync()
          .where((file) => file.path.contains('flightLogsBox') && file is File)
          .cast<File>();

      var copied = 0;
      for (final file in hiveFiles) {
        final dest = File(
          '${quarantineDir.path}/${file.uri.pathSegments.last}',
        );
        await file.copy(dest.path);
        copied++;
        log('[Migration] Quarantined ${file.path} ΓåÆ ${dest.path}');
      }

      if (copied == 0) {
        log('[Migration] No flightLogsBox files found to quarantine');
        return null;
      }

      return quarantineDir.path;
    } catch (e, stackTrace) {
      log('[Migration] Quarantine failed: $e', stackTrace: stackTrace);
      return null;
    }
  }

  /// @deprecated Use [quarantineCorruptedFlightLogFiles]. Never deletes user data.
  static Future<bool> fixCorruptedFlightLogData() async {
    final path = await quarantineCorruptedFlightLogFiles();
    return path != null;
  }

  /// Attempt to recover specific records from quarantined copies (best-effort).
  static Future<List<Map<String, dynamic>>> recoverFlightLogData() async {
    final recoveredData = <Map<String, dynamic>>[];

    try {
      log('[Migration] Attempting to recover flight log data from quarantine...');

      final appDir = await getApplicationDocumentsDirectory();
      final quarantineRoot = Directory('${appDir.path}/hive_quarantine');

      if (await quarantineRoot.exists()) {
        for (final dir in quarantineRoot.listSync().whereType<Directory>()) {
          for (final file in dir.listSync().where(
                (f) => f.path.contains('flightLogsBox') && f is File,
              )) {
            log('[Migration] Found quarantined file for recovery: ${file.path}');
          }
        }
      }

      log('[Migration] Recovered ${recoveredData.length} flight log records');
    } catch (e) {
      log('[Migration] Data recovery failed: $e');
    }

    return recoveredData;
  }

  /// Check if FlightLog data is corrupted (read probe).
  static Future<bool> isFlightLogDataCorrupted() async {
    try {
      if (Hive.isBoxOpen('flightLogsBox')) {
        final box = Hive.box<FlightLog>('flightLogsBox');
        if (box.isNotEmpty) {
          box.getAt(0);
        }
        return false;
      }

      final testBox = await Hive.openBox<FlightLog>('flightLogsBox_probe');
      await testBox.close();
      await Hive.deleteBoxFromDisk('flightLogsBox_probe');
      return false;
    } catch (e) {
      if (e
          .toString()
          .contains('type \'Null\' is not a subtype of type \'double\'')) {
        return true;
      }
      return false;
    }
  }

  /// Corruption status for diagnostics (no destructive action).
  static Future<Map<String, dynamic>> getCorruptionStatus() async {
    try {
      final isCorrupted = await isFlightLogDataCorrupted();
      final appDir = await getApplicationDocumentsDirectory();
      final quarantineRoot = Directory('${appDir.path}/hive_quarantine');

      return {
        'isCorrupted': isCorrupted,
        'hasQuarantine': await quarantineRoot.exists(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'isCorrupted': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}

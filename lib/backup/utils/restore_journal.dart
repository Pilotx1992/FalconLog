import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted marker for an in-progress Replace restore (crash recovery).
class RestoreJournalEntry {
  final String snapshotPath;
  final String restoreMode;
  final String backupTargetId;
  final int createdAtMs;
  final int originalFlightCount;

  const RestoreJournalEntry({
    required this.snapshotPath,
    required this.restoreMode,
    required this.backupTargetId,
    required this.createdAtMs,
    required this.originalFlightCount,
  });

  Map<String, dynamic> toJson() => {
        'snapshot_path': snapshotPath,
        'restore_mode': restoreMode,
        'backup_target_id': backupTargetId,
        'created_at_ms': createdAtMs,
        'original_flight_count': originalFlightCount,
      };

  factory RestoreJournalEntry.fromJson(Map<String, dynamic> json) {
    return RestoreJournalEntry(
      snapshotPath: json['snapshot_path'] as String,
      restoreMode: json['restore_mode'] as String? ?? 'replace',
      backupTargetId: json['backup_target_id'] as String? ?? '',
      createdAtMs: json['created_at_ms'] as int? ?? 0,
      originalFlightCount: json['original_flight_count'] as int? ?? 0,
    );
  }
}

/// Read/write pending-restore journal in SharedPreferences.
class RestoreJournal {
  RestoreJournal._();

  static const String prefsKey = 'falconlog_pending_restore_journal';

  static Future<void> write(RestoreJournalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, json.encode(entry.toJson()));
  }

  static Future<RestoreJournalEntry?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return RestoreJournalEntry.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}

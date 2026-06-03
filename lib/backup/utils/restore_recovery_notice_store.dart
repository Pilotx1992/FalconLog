import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'replace_restore_transaction.dart';

class RestoreRecoveryNotice {
  const RestoreRecoveryNotice({
    required this.rollbackSucceeded,
    required this.message,
    required this.createdAt,
    this.journalId,
  });

  final bool rollbackSucceeded;
  final String message;
  final DateTime createdAt;
  final String? journalId;

  Map<String, dynamic> toJson() {
    return {
      'rollbackSucceeded': rollbackSucceeded,
      'message': message,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (journalId != null) 'journalId': journalId,
    };
  }

  static RestoreRecoveryNotice? fromJson(Map<String, dynamic> json) {
    final rollbackSucceeded = json['rollbackSucceeded'];
    final message = json['message'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (rollbackSucceeded is! bool || message is! String || createdAt == null) {
      return null;
    }
    return RestoreRecoveryNotice(
      rollbackSucceeded: rollbackSucceeded,
      message: message,
      createdAt: createdAt,
      journalId: json['journalId'] as String?,
    );
  }
}

class RestoreRecoveryNoticeStore {
  RestoreRecoveryNoticeStore._();

  static const String prefsKey = 'falconlog_restore_recovery_notice_v1';
  static const String emittedJournalIdsPrefsKey =
      'falconlog_restore_recovery_notice_emitted_journal_ids_v1';
  static const int maxEmittedJournalIds = 20;

  static Future<bool> save(PendingRestoreRecoveryResult result) async {
    if (!result.hadPendingJournal) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final journalId = result.journalId;
    if (journalId != null && journalId.isNotEmpty) {
      final emitted = prefs.getStringList(emittedJournalIdsPrefsKey) ?? [];
      if (emitted.contains(journalId)) {
        return false;
      }
    }

    final notice = RestoreRecoveryNotice(
      rollbackSucceeded: result.rollbackSucceeded,
      message: result.message ??
          (result.rollbackSucceeded
              ? 'Recovered from an interrupted restore.'
              : 'Interrupted restore recovery failed.'),
      createdAt: DateTime.now().toUtc(),
      journalId: journalId,
    );
    await prefs.setString(prefsKey, jsonEncode(notice.toJson()));
    if (journalId != null && journalId.isNotEmpty) {
      final emitted = prefs.getStringList(emittedJournalIdsPrefsKey) ?? [];
      final next = [...emitted.where((id) => id != journalId), journalId];
      final trimmed = next.length > maxEmittedJournalIds
          ? next.sublist(next.length - maxEmittedJournalIds)
          : next;
      await prefs.setStringList(emittedJournalIdsPrefsKey, trimmed);
    }
    return true;
  }

  static Future<RestoreRecoveryNotice?> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return RestoreRecoveryNotice.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<RestoreRecoveryNotice?> takeLatest() async {
    final prefs = await SharedPreferences.getInstance();
    final notice = await peek();
    if (notice != null) {
      await prefs.remove(prefsKey);
    }
    return notice;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    await prefs.remove(emittedJournalIdsPrefsKey);
  }
}

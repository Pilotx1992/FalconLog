import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_operation_lock.dart';

enum BackupOperationResultState {
  verified('verified'),
  failed('failed'),
  cancelled('cancelled'),
  unverified('unverified');

  const BackupOperationResultState(this.wireName);

  final String wireName;

  static BackupOperationResultState fromWireName(String value) {
    return BackupOperationResultState.values.firstWhere(
      (state) => state.wireName == value,
      orElse: () => BackupOperationResultState.unverified,
    );
  }
}

class BackupOperationHistoryRecord {
  const BackupOperationHistoryRecord({
    required this.id,
    required this.operationType,
    required this.state,
    required this.startedAt,
    required this.completedAt,
    required this.message,
    this.redactedError,
    this.backupId,
  });

  final String id;
  final BackupOperationType operationType;
  final BackupOperationResultState state;
  final DateTime startedAt;
  final DateTime completedAt;
  final String message;
  final String? redactedError;
  final String? backupId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operationType': operationType.wireName,
      'state': state.wireName,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'completedAt': completedAt.toUtc().toIso8601String(),
      'message': message,
      if (redactedError != null) 'redactedError': redactedError,
      if (backupId != null) 'backupId': backupId,
    };
  }

  static BackupOperationHistoryRecord? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final operationType = json['operationType'];
    final state = json['state'];
    final startedAt = DateTime.tryParse('${json['startedAt']}');
    final completedAt = DateTime.tryParse('${json['completedAt']}');
    final message = json['message'];
    if (id is! String ||
        operationType is! String ||
        state is! String ||
        startedAt == null ||
        completedAt == null ||
        message is! String) {
      return null;
    }

    return BackupOperationHistoryRecord(
      id: id,
      operationType: BackupOperationType.fromWireName(operationType),
      state: BackupOperationResultState.fromWireName(state),
      startedAt: startedAt,
      completedAt: completedAt,
      message: message,
      redactedError: json['redactedError'] as String?,
      backupId: json['backupId'] as String?,
    );
  }
}

class BackupOperationHistory {
  BackupOperationHistory._();

  static const String prefsKey = 'falconlog_backup_operation_history_v1';
  static const int maxRecords = 50;

  static Future<void> record({
    required BackupOperationType operationType,
    required BackupOperationResultState state,
    required DateTime startedAt,
    required String message,
    Object? error,
    String? backupId,
    DateTime? completedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await readAll();
    final now = (completedAt ?? DateTime.now()).toUtc();
    final record = BackupOperationHistoryRecord(
      id: '${now.microsecondsSinceEpoch}_${operationType.wireName}',
      operationType: operationType,
      state: state,
      startedAt: startedAt.toUtc(),
      completedAt: now,
      message: message,
      redactedError: error == null ? null : redactError(error),
      backupId: backupId,
    );

    final next = [...records, record];
    final trimmed = next.length > maxRecords
        ? next.sublist(next.length - maxRecords)
        : next;
    await prefs.setString(
      prefsKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
  }

  static Future<List<BackupOperationHistoryRecord>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => BackupOperationHistoryRecord.fromJson(
                item.cast<String, dynamic>(),
              ))
          .whereType<BackupOperationHistoryRecord>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @visibleForTesting
  static Future<void> clearForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  @visibleForTesting
  static String redactError(Object error) {
    return error
        .toString()
        .replaceAll(
          RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),
          '[email]',
        )
        .replaceAll(
          RegExp(r'[A-Za-z]:[\\/][^\s]+'),
          '[path]',
        )
        .replaceAll(
          RegExp(r'/(?:[^\s/]+/){2,}[^\s]+'),
          '[path]',
        );
  }
}

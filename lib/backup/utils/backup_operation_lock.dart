import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum BackupOperationType {
  manualBackup('manual_backup'),
  scheduledBackup('scheduled_backup'),
  restore('restore');

  const BackupOperationType(this.wireName);

  final String wireName;

  static BackupOperationType fromWireName(String value) {
    return BackupOperationType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => BackupOperationType.manualBackup,
    );
  }

  String get displayName {
    switch (this) {
      case BackupOperationType.manualBackup:
        return 'manual backup';
      case BackupOperationType.scheduledBackup:
        return 'scheduled backup';
      case BackupOperationType.restore:
        return 'restore';
    }
  }
}

class BackupOperationLockRecord {
  const BackupOperationLockRecord({
    required this.ownerToken,
    required this.operationType,
    required this.createdAt,
    required this.updatedAt,
  });

  final String ownerToken;
  final BackupOperationType operationType;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isStale(DateTime now, Duration staleTimeout) {
    return now.difference(updatedAt) >= staleTimeout;
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerToken': ownerToken,
      'operationType': operationType.wireName,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static BackupOperationLockRecord? fromJson(Map<String, dynamic> json) {
    final ownerToken = json['ownerToken'];
    final operationType = json['operationType'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final updatedAt = DateTime.tryParse('${json['updatedAt']}');
    if (ownerToken is! String ||
        ownerToken.isEmpty ||
        operationType is! String ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return BackupOperationLockRecord(
      ownerToken: ownerToken,
      operationType: BackupOperationType.fromWireName(operationType),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class BackupOperationLockAcquisition {
  const BackupOperationLockAcquisition._({
    required this.acquired,
    required this.ownerToken,
    required this.operationType,
    this.activeLock,
    this.message,
  });

  factory BackupOperationLockAcquisition.acquired({
    required String ownerToken,
    required BackupOperationType operationType,
  }) {
    return BackupOperationLockAcquisition._(
      acquired: true,
      ownerToken: ownerToken,
      operationType: operationType,
    );
  }

  factory BackupOperationLockAcquisition.blocked({
    required String ownerToken,
    required BackupOperationType operationType,
    required BackupOperationLockRecord activeLock,
  }) {
    return BackupOperationLockAcquisition._(
      acquired: false,
      ownerToken: ownerToken,
      operationType: operationType,
      activeLock: activeLock,
      message:
          'Another ${activeLock.operationType.displayName} is already running. Please wait for it to finish.',
    );
  }

  final bool acquired;
  final String ownerToken;
  final BackupOperationType operationType;
  final BackupOperationLockRecord? activeLock;
  final String? message;
}

class BackupOperationLeaseLostException implements Exception {
  const BackupOperationLeaseLostException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupOperationLockLease {
  BackupOperationLockLease({
    required this.ownerToken,
    required this.operationType,
    Duration? heartbeatInterval,
  }) : heartbeatInterval =
            heartbeatInterval ?? BackupOperationLock._heartbeatInterval();

  final String ownerToken;
  final BackupOperationType operationType;
  final Duration heartbeatInterval;

  Timer? _heartbeatTimer;
  bool _stopped = false;
  bool _lost = false;
  bool _touchInProgress = false;
  int _completedHeartbeatCount = 0;
  String? _lostMessage;

  bool get isLost => _lost;

  @visibleForTesting
  int get completedHeartbeatCount => _completedHeartbeatCount;

  void start() {
    if (_stopped || _heartbeatTimer != null) {
      return;
    }
    _heartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (_) => unawaited(_touchHeartbeat()),
    );
  }

  Future<void> stop() async {
    _stopped = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    while (_touchInProgress) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  void throwIfLost() {
    if (!_lost) {
      return;
    }
    throw BackupOperationLeaseLostException(
      _lostMessage ??
          'The backup operation lock was lost before the operation completed.',
    );
  }

  @visibleForTesting
  Future<void> heartbeatNowForTesting() => _touchHeartbeat();

  Future<void> _touchHeartbeat() async {
    if (_stopped || _lost || _touchInProgress) {
      return;
    }

    _touchInProgress = true;
    try {
      final touched = await BackupOperationLock.touch(ownerToken: ownerToken);
      if (!touched) {
        _markLost(
          'The backup operation lock changed owner before the operation completed.',
        );
      } else {
        _completedHeartbeatCount++;
      }
    } catch (e) {
      _markLost('The backup operation lock heartbeat failed: $e');
    } finally {
      _touchInProgress = false;
    }
  }

  void _markLost(String message) {
    if (_lost || _stopped) {
      return;
    }
    _lost = true;
    _lostMessage = message;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}

class BackupOperationLock {
  BackupOperationLock._();

  static const String _recordFileName = 'falconlog_backup_operation_lock.json';
  static const String _mutexFileName = 'falconlog_backup_operation_lock.mutex';
  static const Duration defaultStaleTimeout = Duration(minutes: 45);
  static const Duration defaultHeartbeatInterval = Duration(seconds: 90);
  static const Duration _mutexLockRetryDelay = Duration(milliseconds: 10);
  static const Duration _mutexLockRetryTimeout = Duration(seconds: 5);

  @visibleForTesting
  static Directory? baseDirectoryForTesting;

  @visibleForTesting
  static DateTime Function()? nowForTesting;

  @visibleForTesting
  static Duration? heartbeatIntervalForTesting;

  static DateTime _now() =>
      nowForTesting?.call().toUtc() ?? DateTime.now().toUtc();

  static Duration _heartbeatInterval() =>
      heartbeatIntervalForTesting ?? defaultHeartbeatInterval;

  static Future<BackupOperationLockAcquisition> acquire({
    required BackupOperationType operationType,
    required String ownerToken,
    Duration staleTimeout = defaultStaleTimeout,
  }) {
    return _withExclusiveLock((recordFile) async {
      final now = _now();
      final existing = await _readRecordUnlocked(recordFile);
      if (existing != null && !existing.isStale(now, staleTimeout)) {
        return BackupOperationLockAcquisition.blocked(
          ownerToken: ownerToken,
          operationType: operationType,
          activeLock: existing,
        );
      }

      final record = BackupOperationLockRecord(
        ownerToken: ownerToken,
        operationType: operationType,
        createdAt: now,
        updatedAt: now,
      );
      await recordFile.writeAsString(jsonEncode(record.toJson()), flush: true);
      return BackupOperationLockAcquisition.acquired(
        ownerToken: ownerToken,
        operationType: operationType,
      );
    });
  }

  static Future<bool> touch({
    required String ownerToken,
    DateTime? updatedAt,
  }) {
    return _withExclusiveLock((recordFile) async {
      final existing = await _readRecordUnlocked(recordFile);
      if (existing == null || existing.ownerToken != ownerToken) {
        return false;
      }

      final touched = BackupOperationLockRecord(
        ownerToken: existing.ownerToken,
        operationType: existing.operationType,
        createdAt: existing.createdAt,
        updatedAt: (updatedAt ?? _now()).toUtc(),
      );
      await recordFile.writeAsString(jsonEncode(touched.toJson()), flush: true);
      return true;
    });
  }

  static Future<bool> release({required String ownerToken}) {
    return _withExclusiveLock((recordFile) async {
      final existing = await _readRecordUnlocked(recordFile);
      if (existing == null || existing.ownerToken != ownerToken) {
        return false;
      }
      if (await recordFile.exists()) {
        await recordFile.delete();
      }
      return true;
    });
  }

  static Future<BackupOperationLockRecord?> read() {
    return _withExclusiveLock(_readRecordUnlocked);
  }

  @visibleForTesting
  static Future<void> clearForTesting() async {
    await _withExclusiveLock((recordFile) async {
      if (await recordFile.exists()) {
        await recordFile.delete();
      }
    });
  }

  @visibleForTesting
  static void resetTestOverrides() {
    baseDirectoryForTesting = null;
    nowForTesting = null;
    heartbeatIntervalForTesting = null;
  }

  static Future<BackupOperationLockRecord?> _readRecordUnlocked(
    File recordFile,
  ) async {
    if (!await recordFile.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await recordFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return BackupOperationLockRecord.fromJson(decoded);
    } catch (_) {
      await recordFile.delete();
      return null;
    }
  }

  static Future<T> _withExclusiveLock<T>(
    Future<T> Function(File recordFile) action,
  ) async {
    final dir = await _lockDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final mutexFile = File(p.join(dir.path, _mutexFileName));
    final recordFile = File(p.join(dir.path, _recordFileName));
    final mutex = await mutexFile.open(mode: FileMode.append);
    try {
      await _lockMutex(mutex);
      return await action(recordFile);
    } finally {
      try {
        await mutex.unlock(0, 1);
      } on FileSystemException catch (e) {
        if (kDebugMode) {
          debugPrint('BACKUP_OPERATION_MUTEX_UNLOCK_SKIPPED: $e');
        }
      } finally {
        await mutex.close();
      }
    }
  }

  static Future<void> _lockMutex(RandomAccessFile mutex) async {
    final deadline = DateTime.now().add(_mutexLockRetryTimeout);
    while (true) {
      try {
        await mutex.lock(FileLock.exclusive, 0, 1);
        return;
      } on FileSystemException {
        if (DateTime.now().isAfter(deadline)) {
          rethrow;
        }
        await Future<void>.delayed(_mutexLockRetryDelay);
      }
    }
  }

  static Future<Directory> _lockDirectory() async {
    final testDir = baseDirectoryForTesting;
    if (testDir != null) {
      return testDir;
    }
    return getApplicationSupportDirectory();
  }
}

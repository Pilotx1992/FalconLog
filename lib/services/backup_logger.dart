import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum BackupLogType {
  backup,
  restore,
  delete,
  error,
  maintenance,
}

class BackupLogEntry {
  final DateTime timestamp;
  final BackupLogType type;
  final String provider;
  final String message;
  final Map<String, dynamic>? details;

  const BackupLogEntry({
    required this.timestamp,
    required this.type,
    required this.provider,
    required this.message,
    this.details,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'provider': provider,
    'message': message,
    'details': details,
  };

  factory BackupLogEntry.fromJson(Map<String, dynamic> json) => BackupLogEntry(
    timestamp: DateTime.parse(json['timestamp']),
    type: BackupLogType.values.firstWhere((e) => e.name == json['type']),
    provider: json['provider'],
    message: json['message'],
    details: json['details'],
  );

  String get formattedTimestamp {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String get icon {
    switch (type) {
      case BackupLogType.backup:
        return '📤';
      case BackupLogType.restore:
        return '📥';
      case BackupLogType.delete:
        return '🗑️';
      case BackupLogType.error:
        return '❌';
      case BackupLogType.maintenance:
        return '🔧';
    }
  }
}

class BackupLogger {
  static const int maxEntries = 50;
  static const String logFileName = 'backup_log.json';
  
  static List<BackupLogEntry> _cache = [];
  static bool _loaded = false;

  static Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, 'falconlog_backups', logFileName));
  }

  static Future<void> _loadLog() async {
    if (_loaded) return;
    
    try {
      final logFile = await _getLogFile();
      if (await logFile.exists()) {
        final content = await logFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _cache = jsonList.map((json) => BackupLogEntry.fromJson(json)).toList();
      }
      _loaded = true;
    } catch (e) {
      // If log file is corrupted, start fresh
      _cache = [];
      _loaded = true;
    }
  }

  static Future<void> _saveLog() async {
    try {
      final logFile = await _getLogFile();
      await logFile.parent.create(recursive: true);
      
      // Keep only last maxEntries
      if (_cache.length > maxEntries) {
        _cache = _cache.sublist(_cache.length - maxEntries);
      }
      
      final jsonList = _cache.map((entry) => entry.toJson()).toList();
      await logFile.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      // Fail silently - logging shouldn't break backup operations
    }
  }

  static Future<void> log({
    required BackupLogType type,
    required String provider,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await _loadLog();
    
    final entry = BackupLogEntry(
      timestamp: DateTime.now(),
      type: type,
      provider: provider,
      message: message,
      details: details,
    );
    
    _cache.add(entry);
    await _saveLog();
  }

  static Future<List<BackupLogEntry>> getLog() async {
    await _loadLog();
    return List.from(_cache.reversed); // Most recent first
  }

  static Future<void> clearLog() async {
    _cache.clear();
    _loaded = true;
    await _saveLog();
  }

  // Convenience methods
  static Future<void> logBackup({
    required String provider,
    required int flightCount,
    required int size,
  }) => log(
    type: BackupLogType.backup,
    provider: provider,
    message: 'Backed up $flightCount flights',
    details: {
      'flight_count': flightCount,
      'size_bytes': size,
    },
  );

  static Future<void> logRestore({
    required String provider,
    required int flightCount,
  }) => log(
    type: BackupLogType.restore,
    provider: provider,
    message: 'Restored $flightCount flights',
    details: {
      'flight_count': flightCount,
    },
  );

  static Future<void> logError({
    required String provider,
    required String operation,
    required String error,
  }) => log(
    type: BackupLogType.error,
    provider: provider,
    message: '$operation failed: $error',
    details: {
      'operation': operation,
      'error': error,
    },
  );

  static Future<void> logMaintenance({
    required String operation,
    Map<String, dynamic>? details,
  }) => log(
    type: BackupLogType.maintenance,
    provider: 'system',
    message: operation,
    details: details,
  );
}

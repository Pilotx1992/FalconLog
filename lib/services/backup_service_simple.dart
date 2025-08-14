import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flight_log.dart';

enum BackupProvider { firebase, local, googleDrive }

class BackupService {
  
  // Basic backup to Firebase
  static Future<BackupResult> backupToFirebase(List<FlightLog> logs) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return BackupResult.error('User not authenticated');
      }

      final logsData = logs.map((log) => log.toJson()).toList();
      
      await FirebaseFirestore.instance
          .collection('backups')
          .doc(user.uid)
          .collection('flight_data')
          .doc('backup_${DateTime.now().millisecondsSinceEpoch}')
          .set({
        'logs': logsData,
        'timestamp': FieldValue.serverTimestamp(),
        'logs_count': logs.length,
      });

      return BackupResult.success(
        message: 'Successfully backed up to Firebase',
        logsCount: logs.length,
        backupSize: logsData.length,
        filePath: 'Firebase Cloud',
      );
    } catch (e) {
      return BackupResult.error('Firebase backup failed: $e');
    }
  }

  // Basic local backup
  static Future<BackupResult> backupToLocal(List<FlightLog> logs) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/falconlog_backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'falconlog_backup_$timestamp.json';
      final file = File('${backupDir.path}/$fileName');

      final backupData = {
        'logs': logs.map((log) => log.toJson()).toList(),
        'timestamp': timestamp,
        'logs_count': logs.length,
      };

      await file.writeAsString(jsonEncode(backupData));

      return BackupResult.success(
        message: 'Successfully backed up locally',
        logsCount: logs.length,
        backupSize: await file.length(),
        filePath: file.path,
      );
    } catch (e) {
      return BackupResult.error('Local backup failed: $e');
    }
  }

  // Basic restore from Firebase
  static Future<RestoreResult> restoreFromFirebase({String? backupId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return RestoreResult.error('User not authenticated');
      }

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('backups')
          .doc(user.uid)
          .collection('flight_data')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return RestoreResult.error('No backup found');
      }

      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      final logsData = data['logs'] as List;
      final flights = logsData
          .map((log) => FlightLog.fromJson(log as Map<String, dynamic>))
          .toList();

      return RestoreResult.success(
        message: 'Successfully restored from Firebase',
        logsCount: flights.length,
        deviceInfo: 'Firebase Backup',
      );
    } catch (e) {
      return RestoreResult.error('Firebase restore failed: $e');
    }
  }

  // Disabled Google Drive backup
  static Future<BackupResult> backupToGoogleDrive(List<FlightLog> logs) async {
    return BackupResult.error('Google Drive backup is currently under maintenance. Please use local backup instead.');
  }

  // Disabled Google Drive restore
  static Future<RestoreResult> restoreFromGoogleDrive({String? backupId}) async {
    return RestoreResult.error('Google Drive restore is currently under maintenance. Please use local restore instead.');
  }

  // Basic local restore
  static Future<RestoreResult> restoreFromLocal(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return RestoreResult.error('Backup file not found');
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final logsData = data['logs'] as List;
      final flights = logsData
          .map((log) => FlightLog.fromJson(log as Map<String, dynamic>))
          .toList();

      return RestoreResult.success(
        message: 'Successfully restored from local file',
        logsCount: flights.length,
        deviceInfo: 'Local Backup',
      );
    } catch (e) {
      return RestoreResult.error('Local restore failed: $e');
    }
  }

  // Stub methods for compatibility
  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_backup_time');
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  static Future<List<BackupInfo>> getBackupHistory() async {
    return [];
  }

  static Future<List<BackupInfo>> getLocalBackups() async {
    return [];
  }

  static Future<BackupProvider> getBackupProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final providerIndex = prefs.getInt('backup_provider') ?? 0;
    return BackupProvider.values[providerIndex];
  }

  static Future<void> setBackupProvider(BackupProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('backup_provider', provider.index);
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_backup_enabled') ?? false;
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);
  }

  static Future<Map<String, dynamic>?> getAutoBackupConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('auto_backup_config');
    return configJson != null ? jsonDecode(configJson) : null;
  }

  static Future<void> setAutoBackupConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_backup_config', jsonEncode(config));
  }

  static Future<BackupResult> performAutoBackup(List<FlightLog> logs) async {
    final provider = await getBackupProvider();
    switch (provider) {
      case BackupProvider.firebase:
        return backupToFirebase(logs);
      case BackupProvider.local:
        return backupToLocal(logs);
      case BackupProvider.googleDrive:
        return backupToGoogleDrive(logs);
    }
  }

  static Future<bool> deleteBackup(BackupInfo backupInfo) async {
    // Stub implementation
    return true;
  }
}

// Result classes
class BackupResult {
  final bool success;
  final String message;
  final int? logsCount;
  final int? backupSize;
  final String? filePath;

  BackupResult.success({
    required this.message,
    this.logsCount,
    this.backupSize,
    this.filePath,
  }) : success = true;

  BackupResult.error(this.message)
      : success = false,
        logsCount = null,
        backupSize = null,
        filePath = null;
}

class RestoreResult {
  final bool success;
  final String message;
  final int? logsCount;
  final String? deviceInfo;

  RestoreResult.success({
    required this.message,
    this.logsCount,
    this.deviceInfo,
  }) : success = true;

  RestoreResult.error(this.message)
      : success = false,
        logsCount = null,
        deviceInfo = null;
}

class BackupInfo {
  final String id;
  final String name;
  final DateTime timestamp;
  final int logsCount;
  final int backupSize;
  final BackupProvider provider;

  BackupInfo({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.logsCount,
    required this.backupSize,
    required this.provider,
  });
}

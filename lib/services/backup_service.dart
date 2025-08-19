import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/flight_log.dart';
import 'encryption_service.dart';

enum BackupProvider { firebase, local, googleDrive }

extension BackupProviderExtension on BackupProvider {
  String get displayName {
    switch (this) {
      case BackupProvider.firebase:
        return 'Firebase';
      case BackupProvider.local:
        return 'Local Storage';
      case BackupProvider.googleDrive:
        return 'Google Drive';
    }
  }
}

class BackupService {
  // =====================
  // Internal helpers
  // =====================
  static Future<void> _updateLastBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_backup_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<Directory> _ensureLocalBackupDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(directory.path, 'falconlog_backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  // =====================
  // Firebase backup (plain JSON stored in Firestore)
  // =====================
  static Future<BackupResult> backupToFirebase(List<FlightLog> logs) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return BackupResult.error('User not authenticated');

      final logsData = logs.map((l) => l.toJson()).toList();
      final docId = 'backup_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance
          .collection('backups')
          .doc(user.uid)
          .collection('flight_data')
          .doc(docId)
          .set({
        'logs': logsData,
        'timestamp': FieldValue.serverTimestamp(),
        'logs_count': logs.length,
        'schema': 'falconlog.v1',
        'created_at': DateTime.now().toIso8601String(),
      });

      await _updateLastBackupTime();
      // Rough size estimation (JSON string length)
      final size = utf8.encode(jsonEncode({'logs': logsData})).length;
      return BackupResult.success(
        message: 'Successfully backed up to Firebase',
        logsCount: logs.length,
        backupSize: size,
        filePath: 'Firebase:$docId',
      );
    } catch (e) {
      return BackupResult.error('Firebase backup failed: $e');
    }
  }

  // =====================
  // Local backup (Step 1: compression + encryption)
  // Creates: <base>.enc (encrypted zip) + <base>.meta.json
  // =====================
  static Future<BackupResult> backupToLocal(List<FlightLog> logs) async {
    try {
      final backupDir = await _ensureLocalBackupDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = 'falconlog_backup_$timestamp';

      // 1. Build raw JSON file (temporary)
      final tempJsonFile = File(p.join(backupDir.path, '$baseName.json'));
      final logsList = logs.map((l) => l.toJson()).toList();
      final backupData = {
        'schema': 'falconlog.v1',
        'created_at': DateTime.now().toIso8601String(),
        'timestamp': timestamp,
        'logs_count': logs.length,
        'logs': logsList,
      };
      await tempJsonFile.writeAsString(jsonEncode(backupData), flush: true);

      // 2. Zip the JSON
      final zipPath = p.join(backupDir.path, '$baseName.zip');
      final zipFile = await EncryptionService.createZip(
        sources: [tempJsonFile],
        outputZipPath: zipPath,
      );

      // 3. Encrypt the zip
      final encPath = p.join(backupDir.path, '$baseName.enc');
      final encFile = await EncryptionService.encryptFile(zipFile, encryptedPath: encPath);
      final checksum = await EncryptionService.sha256OfFile(encFile);

      // 4. Metadata
      final meta = {
        'id': baseName,
        'encrypted_file': p.basename(encFile.path),
        'timestamp': timestamp,
        'logs_count': logs.length,
        'created_at': DateTime.now().toIso8601String(),
        'checksum': checksum,
        'provider': 'local',
        'version': 1,
        'zip_size': await zipFile.length(),
        'enc_size': await encFile.length(),
      };
      final metaFile = File(p.join(backupDir.path, '$baseName.meta.json'));
      await metaFile.writeAsString(jsonEncode(meta), flush: true);

      // 5. Clean temp
      try { await tempJsonFile.delete(); } catch (_) {}
      try { await zipFile.delete(); } catch (_) {}

      await _updateLastBackupTime();
      return BackupResult.success(
        message: 'Successfully backed up locally (encrypted)',
        logsCount: logs.length,
        backupSize: await encFile.length(),
        filePath: encFile.path,
      );
    } catch (e) {
      return BackupResult.error('Local backup failed: $e');
    }
  }

  // =====================
  // Restore from Firebase (latest or specific id)
  // =====================
  static Future<RestoreResult> restoreFromFirebase({String? backupId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return RestoreResult.error('User not authenticated');

      final collectionRef = FirebaseFirestore.instance
          .collection('backups')
          .doc(user.uid)
          .collection('flight_data');

      DocumentSnapshot<Map<String, dynamic>>? targetDoc;
      if (backupId != null) {
        final snap = await collectionRef.doc(backupId).get();
        if (!snap.exists) return RestoreResult.error('Backup not found');
        targetDoc = snap;
      } else {
        final latest = await collectionRef.orderBy('timestamp', descending: true).limit(1).get();
        if (latest.docs.isEmpty) return RestoreResult.error('No backup found');
        targetDoc = latest.docs.first;
      }

      final data = targetDoc.data() ?? {};
      final logsData = (data['logs'] as List?) ?? [];
      final flights = logsData
          .map((e) => FlightLog.fromJson(e as Map<String, dynamic>))
          .toList();

      return RestoreResult.success(
        message: 'Successfully restored from Firebase',
        logsCount: flights.length,
        logs: flights,
        timestamp: DateTime.now(),
        version: data['schema'] as String?,
      );
    } catch (e) {
      return RestoreResult.error('Firebase restore failed: $e');
    }
  }

  // =====================
  // Restore from local (.enc + meta) OR legacy .json
  // =====================
  static Future<RestoreResult> restoreFromLocal(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return RestoreResult.error('Backup file not found');

      Map<String, dynamic>? meta;
      File? encFile = file;
      // If user passed the encrypted file, load its meta
      if (file.path.endsWith('.enc')) {
        final base = p.basenameWithoutExtension(file.path); // falconlog_backup_<ts>
        final metaPath = p.join(file.parent.path, '$base.meta.json');
        final metaFile = File(metaPath);
        if (await metaFile.exists()) {
          meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        }
      } else if (file.path.endsWith('.meta.json')) {
        meta = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final encName = meta['encrypted_file'] as String?;
        if (encName != null) {
          final candidate = File(p.join(file.parent.path, encName));
            if (await candidate.exists()) {
              encFile = candidate;
            } else {
              return RestoreResult.error('Encrypted backup file missing');
            }
        }
      } else if (file.path.endsWith('.json')) {
        // Legacy plain JSON
        final jsonData = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final logsData = (jsonData['logs'] as List?) ?? [];
        final flights = logsData.map((e) => FlightLog.fromJson(e as Map<String, dynamic>)).toList();
        return RestoreResult.success(
          message: 'Successfully restored (legacy plain JSON)',
          logsCount: flights.length,
          logs: flights,
          timestamp: DateTime.fromMillisecondsSinceEpoch(jsonData['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
          version: jsonData['schema'] as String?,
        );
      }

      // Decrypt -> unzip
      final tempDir = await Directory(p.join((await _ensureLocalBackupDir()).path, 'restore_temp_${DateTime.now().millisecondsSinceEpoch}')).create();
      final decryptedZipPath = p.join(tempDir.path, 'decrypted_${DateTime.now().millisecondsSinceEpoch}.zip');
      final decryptedZip = await EncryptionService.decryptFile(encFile, outputPath: decryptedZipPath);
      final extractedPaths = await EncryptionService.unzip(decryptedZip, destination: tempDir.path);
      final jsonPath = extractedPaths.firstWhere((pth) => pth.endsWith('.json'), orElse: () => '');
      if (jsonPath.isEmpty) {
        try { await tempDir.delete(recursive: true); } catch (_) {}
        return RestoreResult.error('Invalid backup content');
      }
      final jsonData = jsonDecode(await File(jsonPath).readAsString()) as Map<String, dynamic>;
      final logsData = (jsonData['logs'] as List?) ?? [];
      final flights = logsData.map((e) => FlightLog.fromJson(e as Map<String, dynamic>)).toList();

      // Optional checksum verification
      if (meta != null) {
        final storedChecksum = meta['checksum'] as String?;
        if (storedChecksum != null && storedChecksum.isNotEmpty) {
          final actualChecksum = await EncryptionService.sha256OfFile(encFile);
          if (storedChecksum != actualChecksum) {
            debugPrint('Checksum mismatch: stored=$storedChecksum actual=$actualChecksum');
          }
        }
      }

      try { await tempDir.delete(recursive: true); } catch (_) {}
      return RestoreResult.success(
        message: 'Successfully restored from local encrypted backup',
        logsCount: flights.length,
        logs: flights,
        timestamp: DateTime.fromMillisecondsSinceEpoch(jsonData['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        version: jsonData['schema'] as String?,
      );
    } catch (e) {
      return RestoreResult.error('Local restore failed: $e');
    }
  }

  // =====================
  // Google Drive (fallback to Firebase) – placeholder
  // =====================
  static Future<BackupResult> backupToGoogleDrive(List<FlightLog> logs) async {
    try {
      debugPrint('[BACKUP] Google Drive temporarily unavailable, using Firebase cloud storage');
      return await backupToFirebase(logs);
    } catch (e) {
      return BackupResult.error('Cloud backup failed: $e');
    }
  }

  static Future<RestoreResult> restoreFromGoogleDrive({String? backupId}) async {
    debugPrint('[RESTORE] Google Drive temporarily unavailable, using Firebase cloud storage');
    return restoreFromFirebase(backupId: backupId);
  }

  // =====================
  // Metadata & history
  // =====================
  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('last_backup_time');
    return ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
  }

  static Future<List<BackupInfo>> getBackupHistory() async {
    final List<BackupInfo> history = [];
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('backups')
            .doc(user.uid)
            .collection('flight_data')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final ts = (data['timestamp'] is Timestamp)
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now();
          history.add(BackupInfo(
            id: doc.id,
            name: doc.id,
            timestamp: ts,
            logsCount: (data['logs_count'] as int?) ?? (data['logs'] as List?)?.length ?? 0,
            backupSize: (data['logs'] as List?)?.length ?? 0,
            provider: BackupProvider.firebase,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error loading firebase backup history: $e');
    }
    return history;
  }

  static Future<List<BackupInfo>> getLocalBackups() async {
    final List<BackupInfo> local = [];
    try {
      final backupDir = await _ensureLocalBackupDir();
      final metaFiles = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.meta.json'));
      for (final metaFile in metaFiles) {
        try {
          final data = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          final ts = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
          final encName = data['encrypted_file'] as String? ?? '';
          final encPath = p.join(backupDir.path, encName);
          final encFile = File(encPath);
          local.add(BackupInfo(
            id: encPath,
            name: data['id'] as String? ?? encName,
            timestamp: ts,
            logsCount: (data['logs_count'] as int?) ?? 0,
            backupSize: encFile.existsSync() ? await encFile.length() : (data['enc_size'] as int? ?? 0),
            provider: BackupProvider.local,
            checksum: data['checksum'] as String? ?? '',
          ));
        } catch (e) {
          debugPrint('Error parsing local backup meta ${metaFile.path}: $e');
        }
      }

      // Legacy plain JSON (only include if no meta file for that base)
      final jsonFiles = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json') && !f.path.endsWith('.meta.json'));
      for (final jsonFile in jsonFiles) {
        final base = p.basenameWithoutExtension(jsonFile.path);
        final metaCandidate = File(p.join(backupDir.path, '$base.meta.json'));
        if (await metaCandidate.exists()) continue; // already have encrypted version
        try {
          final content = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
          final ts = DateTime.fromMillisecondsSinceEpoch(content['timestamp'] as int? ?? jsonFile.lastModifiedSync().millisecondsSinceEpoch);
          final logsCount = (content['logs'] as List?)?.length ?? 0;
          local.add(BackupInfo(
            id: jsonFile.path,
            name: p.basename(jsonFile.path),
            timestamp: ts,
            logsCount: logsCount,
            backupSize: await jsonFile.length(),
            provider: BackupProvider.local,
          ));
        } catch (_) {}
      }
      local.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error loading local backups: $e');
    }
    return local;
  }

  // =====================
  // Settings helpers
  // =====================
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

  // =====================
  // Delete backup
  // =====================
  static Future<bool> deleteBackup(BackupInfo info) async {
    try {
      switch (info.provider) {
        case BackupProvider.local:
          final file = File(info.id);
          if (await file.exists()) await file.delete();
          // delete meta if exists
          final base = info.id.endsWith('.enc')
              ? p.basenameWithoutExtension(info.id)
              : p.basename(info.id).replaceAll('.json', '');
          final metaPath = p.join(File(info.id).parent.path, '$base.meta.json');
          final metaFile = File(metaPath);
            if (await metaFile.exists()) {
              try { await metaFile.delete(); } catch (_) {}
            }
          return true;
        case BackupProvider.firebase:
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return false;
          await FirebaseFirestore.instance
              .collection('backups')
              .doc(user.uid)
              .collection('flight_data')
              .doc(info.id)
              .delete();
          return true;
        case BackupProvider.googleDrive:
          // falls back to firebase path currently – nothing additional
          return false;
      }
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
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
  final List<FlightLog>? logs;
  final DateTime? timestamp;
  final String? version;

  RestoreResult.success({
    required this.message,
    this.logsCount,
    this.deviceInfo,
    this.logs,
    this.timestamp,
    this.version,
  }) : success = true;

  RestoreResult.error(this.message)
      : success = false,
        logsCount = null,
        deviceInfo = null,
        logs = null,
        timestamp = null,
        version = null;
}

class BackupInfo {
  final String id;
  final String name;
  final DateTime timestamp;
  final int logsCount;
  final int backupSize;
  final BackupProvider provider;
  final String checksum;

  BackupInfo({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.logsCount,
    required this.backupSize,
    required this.provider,
    this.checksum = '',
  });

  String get formattedSize {
    if (backupSize < 1024) return '${backupSize}B';
    if (backupSize < 1024 * 1024) return '${(backupSize / 1024).toStringAsFixed(1)}KB';
    return '${(backupSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

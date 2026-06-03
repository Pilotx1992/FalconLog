import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Canonical backup package manifest (stored inside decrypted payload).
class BackupPayloadManifest {
  /// Data/schema version for payload collections.
  static const String currentSchemaVersion = '4.0';

  /// Backup package format version (wrapper/manifest contract).
  static const String currentBackupFormatVersion = '2.0';

  /// Highest [backup_format_version] this app can restore.
  static const String supportedMaxBackupFormatVersion = '2.0';

  /// Highest [schema_version] this app can restore.
  static const String supportedMaxSchemaVersion = '4.0';

  static const String newerVersionErrorMessage =
      'This backup was created by a newer app version. Please update the app first.';

  final String backupId;
  final String schemaVersion;
  final String backupFormatVersion;
  final String appVersion;
  final DateTime createdAt;
  final String provider;
  final String location;
  final String? accountEmail;
  final String? deviceId;
  final String payloadSha256;
  final String? flightLogsSha256;
  final String? aircraftTypesSha256;
  final String? appSettingsSha256;
  final int flightLogCount;
  final int skippedLogCount;
  final int aircraftTypeCount;
  final int aircraftTypeSkippedCount;
  final int appSettingsCount;
  final int appSettingsSkippedCount;

  const BackupPayloadManifest({
    required this.backupId,
    required this.schemaVersion,
    required this.backupFormatVersion,
    required this.appVersion,
    required this.createdAt,
    required this.provider,
    required this.location,
    this.accountEmail,
    this.deviceId,
    required this.payloadSha256,
    this.flightLogsSha256,
    this.aircraftTypesSha256,
    this.appSettingsSha256,
    required this.flightLogCount,
    this.skippedLogCount = 0,
    this.aircraftTypeCount = 0,
    this.aircraftTypeSkippedCount = 0,
    this.appSettingsCount = 0,
    this.appSettingsSkippedCount = 0,
  });

  bool get isFullAppFormat =>
      BackupPayloadManifest.isFullAppFormatVersion(backupFormatVersion);

  Map<String, dynamic> toJson() => {
        'backup_id': backupId,
        'schema_version': schemaVersion,
        'backup_format_version': backupFormatVersion,
        'app_version': appVersion,
        'created_at': createdAt.toIso8601String(),
        'provider': provider,
        'location': location,
        if (accountEmail != null) 'account_email': accountEmail,
        if (deviceId != null) 'device_id': deviceId,
        'payload_sha256': payloadSha256,
        if (flightLogsSha256 != null) 'flight_logs_sha256': flightLogsSha256,
        if (aircraftTypesSha256 != null)
          'aircraft_types_sha256': aircraftTypesSha256,
        if (appSettingsSha256 != null) 'app_settings_sha256': appSettingsSha256,
        'flight_log_count': flightLogCount,
        'skipped_log_count': skippedLogCount,
        'aircraft_type_count': aircraftTypeCount,
        'aircraft_type_skipped_count': aircraftTypeSkippedCount,
        'app_settings_count': appSettingsCount,
        'app_settings_skipped_count': appSettingsSkippedCount,
      };

  factory BackupPayloadManifest.fromJson(Map<String, dynamic> json) {
    return BackupPayloadManifest(
      backupId: json['backup_id'] as String,
      schemaVersion: json['schema_version'] as String? ?? '2.0',
      backupFormatVersion:
          json['backup_format_version'] as String? ?? currentBackupFormatVersion,
      appVersion: json['app_version'] as String? ?? 'unknown',
      createdAt: DateTime.parse(json['created_at'] as String),
      provider: json['provider'] as String? ?? 'unknown',
      location: json['location'] as String? ?? 'unknown',
      accountEmail: json['account_email'] as String?,
      deviceId: json['device_id'] as String?,
      payloadSha256: json['payload_sha256'] as String? ?? '',
      flightLogsSha256: json['flight_logs_sha256'] as String?,
      aircraftTypesSha256: json['aircraft_types_sha256'] as String?,
      appSettingsSha256: json['app_settings_sha256'] as String?,
      flightLogCount: json['flight_log_count'] as int? ?? 0,
      skippedLogCount: json['skipped_log_count'] as int? ?? 0,
      aircraftTypeCount: json['aircraft_type_count'] as int? ?? 0,
      aircraftTypeSkippedCount: json['aircraft_type_skipped_count'] as int? ?? 0,
      appSettingsCount: json['app_settings_count'] as int? ?? 0,
      appSettingsSkippedCount: json['app_settings_skipped_count'] as int? ?? 0,
    );
  }

  /// `null` = OK to restore. Non-null = block restore before data changes.
  static String? validateBackupFormatVersion(Map<String, dynamic>? manifestJson) {
    if (manifestJson == null) {
      return null;
    }

    final raw = manifestJson['backup_format_version'];
    if (raw == null) {
      return null;
    }

    final version = raw.toString().trim();
    if (version.isEmpty) {
      return null;
    }

    if (isNewerThanSupported(version, supportedMaxBackupFormatVersion)) {
      return newerVersionErrorMessage;
    }

    return null;
  }

  static String? validateSchemaVersion(Map<String, dynamic>? manifestJson) {
    if (manifestJson == null) {
      return null;
    }

    final raw = manifestJson['schema_version'];
    if (raw == null) {
      return null;
    }

    final version = raw.toString().trim();
    if (version.isEmpty) {
      return null;
    }

    if (isNewerThanSupported(version, supportedMaxSchemaVersion)) {
      return newerVersionErrorMessage;
    }

    return null;
  }

  static bool isLegacyManifest(Map<String, dynamic>? manifestJson) {
    if (manifestJson == null) {
      return true;
    }
    final raw = manifestJson['backup_format_version'];
    if (raw == null) {
      return true;
    }
    return raw.toString().trim().isEmpty;
  }

  static bool isFullAppFormatVersion(String version) {
    return _compareVersions(version, '2.0') >= 0;
  }

  static bool isNewerThanSupported(String version, String supportedMax) {
    return _compareVersions(version, supportedMax) > 0;
  }

  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final bParts = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final length =
        aParts.length > bParts.length ? aParts.length : bParts.length;

    for (var i = 0; i < length; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) {
        return av.compareTo(bv);
      }
    }
    return 0;
  }

  /// SHA-256 of canonical collection JSON (sorted keys).
  static String computeCollectionHash(Map<String, dynamic> collection) {
    return sha256.convert(utf8.encode(_canonicalJson(collection))).toString();
  }

  /// Legacy flight-only hash (format 1.x).
  static String computePayloadHash(Map<String, dynamic> flightLogs) {
    return computeCollectionHash(flightLogs);
  }

  /// Full backup body hash (excludes manifest).
  static String computeFullPayloadHash(Map<String, dynamic> payloadBody) {
    return computeCollectionHash(payloadBody);
  }

  static String _canonicalJson(Map<String, dynamic> data) {
    final sortedKeys = data.keys.map((k) => k.toString()).toList()..sort();
    final ordered = <String, dynamic>{};
    for (final key in sortedKeys) {
      ordered[key] = data[key];
    }
    return json.encode(ordered);
  }

  /// Verifies checksums for full-app or legacy flight-only manifests.
  bool verifyPayload({
    required Map<String, dynamic> flightLogs,
    Map<String, dynamic>? aircraftTypes,
    Map<String, dynamic>? appSettings,
  }) {
    if (isLegacyManifest(toJson())) {
      if (payloadSha256.isEmpty) return true;
      return computePayloadHash(flightLogs) == payloadSha256;
    }

    if (isFullAppFormat) {
      if (flightLogsSha256 != null &&
          flightLogsSha256!.isNotEmpty &&
          computeCollectionHash(flightLogs) != flightLogsSha256) {
        return false;
      }
      final aircraft = aircraftTypes ?? {};
      if (aircraftTypesSha256 != null &&
          aircraftTypesSha256!.isNotEmpty &&
          computeCollectionHash(aircraft) != aircraftTypesSha256) {
        return false;
      }
      final settings = appSettings ?? {};
      if (appSettingsSha256 != null &&
          appSettingsSha256!.isNotEmpty &&
          computeCollectionHash(settings) != appSettingsSha256) {
        return false;
      }
      if (payloadSha256.isNotEmpty) {
        final body = <String, dynamic>{
          if (appSettings != null) 'app_settings': appSettings,
          if (aircraftTypes != null) 'aircraft_types': aircraftTypes,
          'flight_logs': flightLogs,
        };
        return computeFullPayloadHash(body) == payloadSha256;
      }
      return true;
    }

    if (payloadSha256.isEmpty) return true;
    return computePayloadHash(flightLogs) == payloadSha256;
  }
}

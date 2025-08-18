import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

/// Result returned from the isolate after building the raw (unencrypted) bundle.
class RawBackupBundleResult {
  final bool success;
  final String? zipPath; // Path to the produced zip (data + manifest)
  final String? dataSha256;
  final int logsCount;
  final String? error;
  final Map<String, dynamic>? manifest;
  RawBackupBundleResult.success({
    required this.zipPath,
    required this.dataSha256,
    required this.logsCount,
    required this.manifest,
  })  : success = true,
        error = null;
  RawBackupBundleResult.error(this.error)
      : success = false,
        zipPath = null,
        dataSha256 = null,
        logsCount = 0,
        manifest = null;
}

/// Builds the (unencrypted) backup bundle (data.json + manifest.json zipped) off the UI thread.
/// Encryption should be applied afterwards on the main isolate (because secure storage / plugins
/// are not usable inside a background isolate safely).
class BackupBundleService {
  /// Creates an encrypted-ready bundle. Steps performed in background isolate:
  /// 1. Serialize provided log maps to data.json
  /// 2. Compute SHA256 (pure Dart) for integrity
  /// 3. Build manifest.json with extended metadata
  /// 4. Zip (data.json + manifest.json)
  /// Returns [RawBackupBundleResult] containing the path to the zip.
  static Future<RawBackupBundleResult> buildRawBundle({
    required List<Map<String, dynamic>> logMaps,
    required String targetDirectoryPath,
    String prefix = 'backup',
    String? appVersion,
  }) async {
    try {
      final args = <String, dynamic>{
        'logs': logMaps,
        'dir': targetDirectoryPath,
        'prefix': prefix,
        'appVersion': appVersion ?? 'unknown',
      };
      final result = await compute<_BundleArgs, Map<String, dynamic>>(
        _bundleIsolateEntry,
        _BundleArgs.from(args),
      );
      if (result['success'] == true) {
        return RawBackupBundleResult.success(
          zipPath: result['zipPath'] as String,
          dataSha256: result['dataSha256'] as String,
          logsCount: result['logsCount'] as int,
          manifest: (result['manifest'] as Map).cast<String, dynamic>(),
        );
      }
      return RawBackupBundleResult.error(result['error'] as String? ?? 'Unknown bundle error');
    } catch (e) {
      return RawBackupBundleResult.error('Bundle isolate failed: $e');
    }
  }
}

class _BundleArgs {
  final List<Map<String, dynamic>> logs;
  final String dir;
  final String prefix;
  final String appVersion;
  _BundleArgs({required this.logs, required this.dir, required this.prefix, required this.appVersion});
  factory _BundleArgs.from(Map<String, dynamic> m) => _BundleArgs(
        logs: (m['logs'] as List).cast<Map<String, dynamic>>(),
        dir: m['dir'] as String,
        prefix: m['prefix'] as String,
        appVersion: m['appVersion'] as String,
      );
}

Map<String, dynamic> _bundleIsolateEntry(_BundleArgs args) {
  try {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final ts = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    final base = '${args.prefix}_$ts';
  // Create a temp working directory inside target dir
  final tempParent = Directory(p.join(args.dir, 'tmp_build')); tempParent.createSync(recursive: true);
  final workingDir = Directory(p.join(tempParent.path, base))..createSync(recursive: true);

    // Write data.json
    final dataFile = File(p.join(workingDir.path, 'data.json'));
    final dataContent = jsonEncode({
      'schema': 1,
      'format': 'flight_logs',
      'createdAt': now.toIso8601String(),
      'logsCount': args.logs.length,
      'logs': args.logs,
    });
    dataFile.writeAsStringSync(dataContent);

    // Compute sha256 manually (pure Dart) to avoid plugin usage
    final bytes = dataFile.readAsBytesSync();
    final dataSha = _sha256String(bytes);

    // Build manifest
  final manifest = <String, dynamic>{
      'schema': 1,
      'bundleVersion': 1,
      'app': 'FalconLog',
      'appVersion': args.appVersion,
      'createdAt': now.toIso8601String(),
      'logsCount': args.logs.length,
      'dataFile': 'data.json',
      'dataSha256': dataSha,
      'encryption': {
        'willEncrypt': true,
        'algorithm': 'AES-256-CBC',
        'keyVersion': 'v1',
      },
      'archive': {
        'format': 'zip',
        'filePattern': '$base.zip(.enc)',
      }
    };

    final manifestFile = File(p.join(workingDir.path, 'manifest.json'));
    manifestFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));

    // Create zip in parent dir
    final zipTempPath = p.join(workingDir.path, '$base.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipTempPath);
    encoder.addFile(dataFile, 'data.json');
    encoder.addFile(manifestFile, 'manifest.json');
    encoder.close();

    // (Optional) compute archiveSha256 (can be heavy for very large files, enabled here)
    String? archiveSha256;
    try {
      final zipBytes = File(zipTempPath).readAsBytesSync();
      archiveSha256 = _sha256String(zipBytes);
      manifest['archiveSha256'] = archiveSha256;
      // Rewrite manifest with archiveSha256 included
      manifestFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
    } catch (_) {}

    // Move final zip to target directory root
    final finalZipPath = p.join(args.dir, '$base.zip');
    File(zipTempPath).renameSync(finalZipPath);

    // Cleanup temp dir contents (keep zip outside temp)
    try { tempParent.deleteSync(recursive: true); } catch (_) {}

    return {
      'success': true,
      'zipPath': finalZipPath,
      'dataSha256': dataSha,
      'logsCount': args.logs.length,
      'manifest': manifest,
    };
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

String _sha256String(List<int> bytes) => sha256.convert(bytes).toString();

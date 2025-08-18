import 'dart:io';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
// import 'package:google_sign_in/google_sign_in.dart' as gsi; // Temporarily disabled (Google sign-in under maintenance)
import 'package:http/http.dart' as http;
import 'encryption_service.dart';
import '../models/flight_log.dart';
import 'backup_service.dart';
import 'package:path_provider/path_provider.dart';

class _AuthHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _AuthHttpClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
  @override
  void close() => _inner.close();
}

class DriveBackupService {
  static const _folderName = 'FalconLog Backups';
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];

  static Future<drive.DriveApi?> _getDriveApi() async {
    // TODO: Re-enable Google Sign-In flow when authentication service restored
    return null; // Returning null will surface a friendly error to caller
  }

  static Future<String?> _ensureFolder(drive.DriveApi api) async {
    final query = "mimeType='application/vnd.google-apps.folder' and name='$_folderName' and trashed=false";
    final res = await api.files.list(q: query, spaces: 'drive');
    if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id;
    final folderMeta = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folderMeta);
    return created.id;
  }

  static Future<BackupResult> uploadEncryptedLogs(List<FlightLog> logs) async {
    try {
  final api = await _getDriveApi();
  if (api == null) return BackupResult.error('Google Drive auth unavailable (Google Sign-In disabled)');
      final folderId = await _ensureFolder(api) ?? '';

      final dir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${dir.path}/drive_tmp');
      if (!await tempDir.exists()) await tempDir.create(recursive: true);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final base = 'falconlog_backup_$ts';
      final jsonFile = File('${tempDir.path}/$base.json');
      await jsonFile.writeAsString(jsonEncode({
        'schema': 1,
        'timestamp': ts,
        'logs_count': logs.length,
        'logs': logs.map((e) => e.toJson()).toList(),
      }));
      final zip = await EncryptionService.createZip(sources: [jsonFile], outputZipPath: '${tempDir.path}/$base.zip');
      final encFile = await EncryptionService.encryptFile(zip, encryptedPath: '${tempDir.path}/$base.zip.enc');

      final fileSize = await encFile.length();
      final media = drive.Media(encFile.openRead(), fileSize, contentType: 'application/octet-stream');
      final fileMeta = drive.File()
        ..name = '$base.enc'
        ..parents = [folderId]
        ..mimeType = 'application/octet-stream';

      final uploaded = await api.files.create(fileMeta, uploadMedia: media, supportsAllDrives: false); // resumable implicitly handled by googleapis

      // Cleanup temp
      try { if (await tempDir.exists()) await tempDir.delete(recursive: true); } catch (_) {}

      return BackupResult.success(
        message: 'Uploaded encrypted backup to Drive',
        logsCount: logs.length,
        backupSize: fileSize,
        filePath: uploaded.id,
      );
    } catch (e) {
      return BackupResult.error('Drive upload failed: $e');
    }
  }

  static Future<RestoreResult> listAndDownloadLatest() async {
    try {
  final api = await _getDriveApi();
  if (api == null) return RestoreResult.error('Google Drive auth unavailable (Google Sign-In disabled)');
      final folderQuery = "mimeType='application/vnd.google-apps.folder' and name='$_folderName' and trashed=false";
      final folderRes = await api.files.list(q: folderQuery, spaces: 'drive');
      if (folderRes.files == null || folderRes.files!.isEmpty) {
        return RestoreResult.error('Backup folder not found');
      }
      final folderId = folderRes.files!.first.id!;
      final fileList = await api.files.list(q: "'$folderId' in parents and name contains 'falconlog_backup_' and trashed=false", orderBy: 'createdTime desc');
      if (fileList.files == null || fileList.files!.isEmpty) return RestoreResult.error('No backups found');
      final latest = fileList.files!.first;
      final media = await api.files.get(latest.id!, downloadOptions: drive.DownloadOptions.fullMedia);
      if (media is! drive.Media) return RestoreResult.error('Failed downloading file');
      final bytes = <int>[];
      await for (final chunk in media.stream) { bytes.addAll(chunk); }
      final dir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${dir.path}/drive_restore');
      if (!await tempDir.exists()) await tempDir.create(recursive: true);
      final encPath = '${tempDir.path}/${latest.name}';
      final encFile = File(encPath)..writeAsBytesSync(bytes, flush: true);
      final zipOut = File('${tempDir.path}/${latest.name!.replaceAll('.enc', '')}');
      final decryptedZip = await EncryptionService.decryptFile(encFile, outputPath: zipOut.path);
      await EncryptionService.unzip(decryptedZip, destination: tempDir.path);
      final jsonFile = Directory(tempDir.path).listSync().firstWhere((e) => e.path.endsWith('.json')) as File;
      final data = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      final logs = (data['logs'] as List? ?? []).map((e) => FlightLog.fromJson(e as Map<String,dynamic>)).toList();
      try { if (await tempDir.exists()) await tempDir.delete(recursive: true); } catch (_) {}
      return RestoreResult.success(
        message: 'Restored ${logs.length} logs from Drive',
        logsCount: logs.length,
        deviceInfo: 'Google Drive',
        logs: logs,
      );
    } catch (e) {
      return RestoreResult.error('Drive restore failed: $e');
    }
  }
}

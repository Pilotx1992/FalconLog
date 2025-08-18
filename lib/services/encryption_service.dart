import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

/// Provides utilities to zip + encrypt backup bundles and decrypt + unzip them.
class EncryptionService {
  static const _keyStorage = FlutterSecureStorage();
  static const _keyName = 'backup_master_key_v1';
  static const _ivName = 'backup_master_iv_v1';

  /// Returns (key, iv) – creates & persists if missing.
  static Future<(enc.Key, enc.IV)> _getOrCreateKey() async {
    var base64Key = await _keyStorage.read(key: _keyName);
    var base64Iv = await _keyStorage.read(key: _ivName);

    if (base64Key == null || base64Iv == null) {
      final rand = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => rand.nextInt(256)); // 256-bit
      final ivBytes = List<int>.generate(16, (_) => rand.nextInt(256)); // 128-bit IV
      base64Key = base64Encode(keyBytes);
      base64Iv = base64Encode(ivBytes);
      await _keyStorage.write(key: _keyName, value: base64Key);
      await _keyStorage.write(key: _ivName, value: base64Iv);
    }

    return (enc.Key.fromBase64(base64Key), enc.IV.fromBase64(base64Iv));
  }

  /// Zips a list of files/directories into [outputZipPath].
  static Future<File> createZip({required List<FileSystemEntity> sources, required String outputZipPath}) async {
    final encoder = ZipFileEncoder();
    encoder.create(outputZipPath);
    for (final src in sources) {
      final entityName = p.basename(src.path);
      if (src is File) {
        encoder.addFile(src, entityName);
      } else if (src is Directory) {
        encoder.addDirectory(src, includeDirName: true);
      }
    }
    encoder.close();
    return File(outputZipPath);
  }

  /// Encrypt given file producing `<original>.enc` (or [encryptedPath] if provided).
  static Future<File> encryptFile(File input, {String? encryptedPath}) async {
    final (key, iv) = await _getOrCreateKey();
    final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    final bytes = await input.readAsBytes();
    final encrypted = cipher.encryptBytes(bytes, iv: iv);
    final outPath = encryptedPath ?? '${input.path}.enc';
    final outFile = File(outPath);
    await outFile.writeAsBytes(encrypted.bytes, flush: true);
    return outFile;
  }

  /// Decrypts an encrypted file (raw AES bytes) and writes output (typically a zip).
  static Future<File> decryptFile(File encryptedFile, {required String outputPath}) async {
    final (key, iv) = await _getOrCreateKey();
    final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    final encBytes = await encryptedFile.readAsBytes();
    final decrypted = cipher.decryptBytes(enc.Encrypted(encBytes), iv: iv);
    final outFile = File(outputPath);
    await outFile.writeAsBytes(decrypted, flush: true);
    return outFile;
  }

  /// Unzips a zip archive to [destination]. Returns extracted file paths.
  static Future<List<String>> unzip(File zipFile, {required String destination}) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final extracted = <String>[];
    for (final file in archive) {
      final outPath = p.join(destination, file.name);
      if (file.isFile) {
        final outFile = File(outPath)..createSync(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
        extracted.add(outFile.path);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }
    return extracted;
  }

  /// Convenience: compute SHA256 of file (for integrity metadata).
  static Future<String> sha256OfFile(File file) async {
    final digest = sha256.convert(await file.readAsBytes());
    return digest.toString();
  }
}

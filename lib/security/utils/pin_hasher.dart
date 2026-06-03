import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../security_constants.dart';

/// PBKDF2‑HMAC‑SHA256 PIN hashing with constant‑time comparison.
///
/// PIN hash and salt are stored exclusively in FlutterSecureStorage —
/// never in Hive.
class PinHasher {
  PinHasher._();

  // ── Public API ──────────────────────────────────────────────────────

  /// Generate a cryptographically secure random salt.
  static String generateSalt() {
    final random = Random.secure();
    final bytes = Uint8List(SecurityConstants.saltLengthBytes);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// Derive a PBKDF2‑HMAC‑SHA256 hash from [pin] and [salt].
  static String hashPin(String pin, String salt) {
    final saltBytes = utf8.encode(salt);
    final pinBytes = utf8.encode(pin);

    final derived = _pbkdf2(
      password: pinBytes,
      salt: saltBytes,
      iterations: SecurityConstants.pbkdf2Iterations,
      keyLength: SecurityConstants.derivedKeyLengthBytes,
    );

    return base64Url.encode(derived);
  }

  /// Verify [pin] against a previously stored [hash] and [salt].
  ///
  /// Uses constant‑time comparison to prevent timing attacks.
  static bool verifyPin(String pin, String salt, String storedHash) {
    final candidateHash = hashPin(pin, salt);
    return _constantTimeEquals(candidateHash, storedHash);
  }

  // ── PBKDF2 implementation ──────────────────────────────────────────

  static Uint8List _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmacSha256 = Hmac(sha256, password);
    final blocks = (keyLength / sha256.blockSize).ceil();
    final result = BytesBuilder();

    for (var blockIndex = 1; blockIndex <= blocks; blockIndex++) {
      final blockBytes = _intToBytes(blockIndex);
      final saltWithBlock = Uint8List.fromList([...salt, ...blockBytes]);

      var u = hmacSha256.convert(saltWithBlock).bytes;
      var xor = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = hmacSha256.convert(u).bytes;
        for (var j = 0; j < xor.length; j++) {
          xor[j] ^= u[j];
        }
      }

      result.add(xor);
    }

    return Uint8List.fromList(result.toBytes().sublist(0, keyLength));
  }

  static Uint8List _intToBytes(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }

  /// Constant‑time comparison to defend against timing side channels.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

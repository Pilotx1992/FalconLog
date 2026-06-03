import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provides the current app version (e.g., 1.0.0+1). Falls back to pubspec version if unavailable.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version; // ignore build number for manifest brevity
  } catch (_) {
    return '1.0.0';
  }
});

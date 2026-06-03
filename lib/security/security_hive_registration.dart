import 'package:hive/hive.dart';

import 'models/security_settings.dart';

/// Registers security Hive adapters without modifying global Hive init.
void registerSecurityHiveAdapters() {
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SecuritySettingsAdapter());
  }
}

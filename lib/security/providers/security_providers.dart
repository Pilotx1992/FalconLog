import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/security_repository.dart';
import '../models/security_settings.dart';
import '../services/security_service.dart';

final securityRepositoryProvider = Provider<SecurityDataStore>((ref) {
  return SecurityRepository();
});

final securityServiceProvider = Provider<SecurityService>((ref) {
  final repository = ref.watch(securityRepositoryProvider);
  final service = SecurityService(repository);
  ref.onDispose(service.dispose);
  return service;
});

/// Runs [SecurityService.initialize] once; UI and lifecycle await this.
final securityInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(securityServiceProvider);
  await service.initialize();
});

final securitySettingsProvider = StreamProvider<SecuritySettings>((ref) {
  ref.watch(securityInitProvider);
  final service = ref.watch(securityServiceProvider);
  return service.settingsStream;
});

final securityLockStateProvider = StreamProvider<bool>((ref) {
  ref.watch(securityInitProvider);
  final service = ref.watch(securityServiceProvider);
  return service.lockStateStream;
});

/// Synchronous snapshot; stays in sync via [securityLockStateProvider].
final securityIsLockedProvider = Provider<bool>((ref) {
  ref.watch(securityInitProvider);
  final lockAsync = ref.watch(securityLockStateProvider);
  final service = ref.watch(securityServiceProvider);
  return lockAsync.valueOrNull ?? service.isLocked;
});

final securityPinEnabledProvider = Provider<bool>((ref) {
  ref.watch(securityInitProvider);
  final service = ref.watch(securityServiceProvider);
  return service.isPinEnabled;
});

/// Device has enrolled biometrics and PIN is on (for Settings toggle).
final biometricAvailableForAppLockProvider = FutureProvider<bool>((ref) async {
  ref.watch(securityInitProvider);
  // Re-run when PIN / biometric settings change (not only on first load).
  ref.watch(securitySettingsProvider);
  final service = ref.watch(securityServiceProvider);
  return service.isBiometricAvailableForAppLock();
});

final canUseAppLockBiometricProvider = FutureProvider<bool>((ref) async {
  ref.watch(securityInitProvider);
  ref.watch(securitySettingsProvider);
  final service = ref.watch(securityServiceProvider);
  return service.canUseAppLockBiometric();
});

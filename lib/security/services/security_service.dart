import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../services/biometric_auth_service.dart';
import '../data/security_repository.dart';
import '../models/security_settings.dart';
import '../security_constants.dart';
import '../utils/pin_hasher.dart';
import '../utils/pin_validator.dart';

/// Device-level PIN and biometric app lock (independent of Firebase Auth).
class SecurityService {
  SecurityService(SecurityDataStore repository) : _repository = repository;

  final SecurityDataStore _repository;

  SecuritySettings _settings = SecuritySettings.initial();
  bool _isLocked = false;
  bool _initialized = false;
  DateTime? _pausedAt;
  DateTime? _lastInteractionMemory;
  DateTime? _lastInteractionPersisted;
  DateTime? _lastOrientationChangeAt;

  final _lockStateController = StreamController<bool>.broadcast();
  final _settingsController = StreamController<SecuritySettings>.broadcast();

  Stream<bool> get lockStateStream async* {
    yield _isLocked;
    yield* _lockStateController.stream;
  }

  Stream<SecuritySettings> get settingsStream async* {
    yield _settings;
    yield* _settingsController.stream;
  }

  SecuritySettings get settings => _settings;
  bool get isInitialized => _initialized;
  bool get isLocked => _isLocked;
  bool get isPinEnabled => _settings.isPinEnabled;

  Duration get autoLockTimeout => Duration(
        seconds: _settings.autoLockTimeoutSeconds,
      );

  bool get isInLockout {
    final until = _settings.lockoutUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Duration? get lockoutRemaining {
    final until = _settings.lockoutUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  bool shouldShowLock() => _settings.isPinEnabled && _isLocked;

  Future<void> initialize() async {
    if (_initialized) return;

    _settings = await _repository.loadSettings();
    await _repairIntegrityIfNeeded();

    if (_settings.isPinEnabled) {
      _isLocked = true;
    } else {
      _isLocked = false;
    }

    _lastInteractionMemory = _settings.lastInteractionTime ?? DateTime.now();
    _initialized = true;
    _emitLockState();
    _emitSettings();
  }

  Future<void> _repairIntegrityIfNeeded() async {
    if (!_settings.isPinEnabled) return;

    try {
      final hasSecrets = await _repository.hasPinSecrets();
      if (!hasSecrets) {
        await _disablePinDueToCorruption(
          'PIN enabled but secrets missing or unreadable',
        );
        return;
      }

      final hash = await _repository.readPinHash();
      final salt = await _repository.readPinSalt();
      if (!_arePinSecretsWellFormed(hash, salt)) {
        await _disablePinDueToCorruption(
          'PIN enabled but hash/salt are corrupted or invalid',
        );
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[SecurityService] PIN secret check failed: $e\n$st');
      await _disablePinDueToCorruption(
        'PIN enabled but secrets could not be validated',
      );
    }
  }

  bool _arePinSecretsWellFormed(String? hash, String? salt) {
    if (hash == null || salt == null || hash.isEmpty || salt.isEmpty) {
      return false;
    }
    try {
      final hashBytes = base64Url.decode(hash);
      final saltBytes = base64Url.decode(salt);
      return hashBytes.isNotEmpty &&
          saltBytes.length >= SecurityConstants.saltLengthBytes;
    } catch (_) {
      return false;
    }
  }

  Future<void> _disablePinDueToCorruption(String reason) async {
    if (kDebugMode) debugPrint('[SecurityService] $reason — disabling PIN safely');

    _settings = _settings.copyWith(
      isPinEnabled: false,
      isAppLockBiometricEnabled: false,
      failedAttempts: 0,
      lockoutUntil: null,
    );
    try {
      await _repository.saveSettings(_settings);
      await _repository.clearPinSecrets();
    } catch (e, st) {
      if (kDebugMode) debugPrint('[SecurityService] Failed to persist PIN repair: $e\n$st');
    }
    _isLocked = false;
    _emitLockState();
    _emitSettings();
  }

  Future<PinValidationResult> enablePin(String pin) async {
    final validation = PinValidator.validate(pin);
    if (!validation.isValid) return validation;

    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hashPin(pin, salt);
    await _repository.savePinSecrets(hash: hash, salt: salt);

    final now = DateTime.now();
    _settings = _settings.copyWith(
      isPinEnabled: true,
      failedAttempts: 0,
      lockoutUntil: null,
      lastUnlockedAt: now,
      sessionStartTime: now,
      lastInteractionTime: now,
    );
    await _repository.saveSettings(_settings);
    _lastInteractionMemory = now;
    _isLocked = false;
    _emitSettings();
    _emitLockState();
    return const PinValidationResult.valid();
  }

  Future<PinValidationResult> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final verify = await checkPin(currentPin);
    if (!verify) {
      return const PinValidationResult.invalid('Current PIN is incorrect');
    }

    final validation = PinValidator.validate(newPin);
    if (!validation.isValid) return validation;

    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hashPin(newPin, salt);
    await _repository.savePinSecrets(hash: hash, salt: salt);

    _settings = _settings.copyWith(failedAttempts: 0, lockoutUntil: null);
    await _repository.saveSettings(_settings);
    _emitSettings();
    return const PinValidationResult.valid();
  }

  Future<bool> disablePin({String? pin}) async {
    if (!_settings.isPinEnabled) return true;

    if (pin != null) {
      final ok = await verifyPin(pin);
      if (!ok) return false;
    } else {
      return false;
    }

    await _repository.clearPinSecrets();
    _settings = _settings.copyWith(
      isPinEnabled: false,
      isAppLockBiometricEnabled: false,
      failedAttempts: 0,
      lockoutUntil: null,
    );
    await _repository.saveSettings(_settings);
    _isLocked = false;
    _emitSettings();
    _emitLockState();
    return true;
  }

  Future<bool> disablePinWithBiometric() async {
    if (!_settings.isPinEnabled) return true;
    if (!await canUseAppLockBiometric()) return false;
    if (isInLockout) return false;

    final ok = await authenticateForAppUnlock();
    if (!ok) return false;

    await _repository.clearPinSecrets();
    _settings = _settings.copyWith(
      isPinEnabled: false,
      isAppLockBiometricEnabled: false,
      failedAttempts: 0,
      lockoutUntil: null,
    );
    await _repository.saveSettings(_settings);
    _isLocked = false;
    _emitSettings();
    _emitLockState();
    return true;
  }

  /// Verifies PIN without changing lock state (e.g. change/disable PIN flows).
  Future<bool> checkPin(String pin) async {
    if (isInLockout) return false;

    final salt = await _repository.readPinSalt();
    final hash = await _repository.readPinHash();
    if (!_arePinSecretsWellFormed(hash, salt)) {
      if (_settings.isPinEnabled) {
        await _disablePinDueToCorruption(
          'PIN secrets unavailable or corrupted during verify',
        );
      }
      return false;
    }

    return PinHasher.verifyPin(pin, salt!, hash!);
  }

  Future<bool> verifyPin(String pin) async {
    if (isInLockout) return false;

    final ok = await checkPin(pin);
    if (ok) {
      await _onSuccessfulUnlock();
      return true;
    }

    await _onFailedAttempt();
    return false;
  }

  Future<void> _onSuccessfulUnlock() async {
    final now = DateTime.now();
    _settings = _settings.copyWith(
      failedAttempts: 0,
      lockoutUntil: null,
      lastUnlockedAt: now,
      sessionStartTime: now,
      lastInteractionTime: now,
    );
    await _repository.saveSettings(_settings);
    _lastInteractionMemory = now;
    _lastInteractionPersisted = now;
    // Biometric sheet triggers inactive/paused; do not re-lock on the matching resume.
    _pausedAt = null;
    unlock();
    _emitSettings();
  }

  Future<void> _onFailedAttempt() async {
    final attempts = _settings.failedAttempts + 1;
    DateTime? lockoutUntil;

    for (final entry in SecurityConstants.lockoutSchedule) {
      if (attempts >= entry.threshold) {
        lockoutUntil = DateTime.now().add(entry.duration);
        break;
      }
    }

    _settings = _settings.copyWith(
      failedAttempts: attempts,
      lockoutUntil: lockoutUntil,
    );
    await _repository.saveSettings(_settings);
    _emitSettings();
  }

  /// Device can offer biometrics for app lock (Settings toggle), PIN must be on.
  Future<bool> isBiometricAvailableForAppLock() async {
    if (!_settings.isPinEnabled) return false;
    if (!await BiometricAuthService.isDeviceSupported()) return false;
    if (!await BiometricAuthService.canCheckBiometrics()) return false;
    if (!await BiometricAuthService.hasEnrolledBiometrics()) return false;
    return true;
  }

  /// Biometric unlock allowed on the lock screen (enabled + device ready).
  Future<bool> canUseAppLockBiometric() async {
    if (!_settings.isAppLockBiometricEnabled) return false;
    if (isInLockout) return false;
    return isBiometricAvailableForAppLock();
  }

  Future<void> setAppLockBiometricEnabled(bool enabled) async {
    _settings = _settings.copyWith(isAppLockBiometricEnabled: enabled);
    await _repository.saveSettings(_settings);
    _emitSettings();
  }

  Future<bool> authenticateForAppUnlock({
    String reason = 'Unlock FalconLog',
  }) async {
    if (isInLockout) return false;
    try {
      final available = await isBiometricAvailableForAppLock();
      if (!available) {
        if (kDebugMode) debugPrint('[SecurityService] Biometric not available for app lock');
        return false;
      }
      return await BiometricAuthService.authenticate(reason: reason);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[SecurityService] Biometric auth failed: $e\n$st');
      return false;
    }
  }

  Future<bool> unlockWithAppLockBiometric() async {
    if (!await canUseAppLockBiometric()) return false;
    final ok = await authenticateForAppUnlock();
    if (!ok) return false;
    await _onSuccessfulUnlock();
    return true;
  }

  void lock() {
    if (!_settings.isPinEnabled) return;
    if (_isLocked) return;
    _isLocked = true;
    _emitLockState();
  }

  void unlock() {
    if (!_isLocked) return;
    _isLocked = false;
    _emitLockState();
  }

  /// Called when screen metrics change (rotation, resize).
  void markOrientationChange() {
    _lastOrientationChangeAt = DateTime.now();
  }

  bool get _isWithinOrientationGrace {
    final at = _lastOrientationChangeAt;
    if (at == null) return false;
    return DateTime.now().difference(at) <
        SecurityConstants.orientationChangeGracePeriod;
  }

  void recordInteraction() {
    if (!_settings.isPinEnabled || _isLocked) return;

    final now = DateTime.now();
    _lastInteractionMemory = now;

    final shouldPersist = _lastInteractionPersisted == null ||
        now.difference(_lastInteractionPersisted!) >=
            SecurityConstants.interactionPersistThrottle;

    if (shouldPersist) {
      _persistInteraction(now);
    }
  }

  Future<void> flushInteractionTime() async {
    if (_lastInteractionMemory != null) {
      await _persistInteraction(_lastInteractionMemory!);
    }
  }

  Future<void> _persistInteraction(DateTime time) async {
    _settings = _settings.copyWith(lastInteractionTime: time);
    _lastInteractionPersisted = time;
    await _repository.saveSettings(_settings);
    _emitSettings();
  }

  bool checkSessionExpired() {
    if (!_settings.isPinEnabled || _isLocked) return false;

    final last = _lastInteractionMemory ?? _settings.lastInteractionTime;
    if (last == null) return false;

    final limit = Duration(seconds: _settings.sessionDurationSeconds);
    return DateTime.now().difference(last) > limit;
  }

  void onAppPaused() {
    if (!_settings.isPinEnabled) return;
    if (_isWithinOrientationGrace) return;

    _pausedAt = DateTime.now();
    unawaited(flushInteractionTime());

    if (autoLockTimeout == Duration.zero) {
      lock();
    }
  }

  void onAppResumed() {
    if (!_settings.isPinEnabled) {
      _pausedAt = null;
      return;
    }

    if (checkSessionExpired()) {
      lock();
      _pausedAt = null;
      return;
    }

    // "Immediately" (0s) locks in [onAppPaused] only. Re-locking here would fire
    // right after the system biometric dialog closes and undo a fresh unlock.
    if (autoLockTimeout == Duration.zero) {
      _pausedAt = null;
      return;
    }

    if (_pausedAt != null) {
      final elapsed = DateTime.now().difference(_pausedAt!);
      final withinOrientationGrace =
          elapsed < SecurityConstants.orientationChangeGracePeriod;
      if (withinOrientationGrace && elapsed < autoLockTimeout) {
        _pausedAt = null;
        return;
      }
      if (elapsed >= autoLockTimeout) {
        lock();
      }
    }
    _pausedAt = null;
  }

  Future<void> setAutoLockTimeoutSeconds(int seconds) async {
    _settings = _settings.copyWith(autoLockTimeoutSeconds: seconds);
    await _repository.saveSettings(_settings);
    _emitSettings();
  }

  void clearExpiredLockout() {
    final until = _settings.lockoutUntil;
    if (until == null) return;
    if (DateTime.now().isBefore(until)) return;

    _settings = _settings.copyWith(lockoutUntil: null);
    unawaited(_repository.saveSettings(_settings));
    _emitSettings();
  }

  void _emitLockState() {
    if (!_lockStateController.isClosed) {
      _lockStateController.add(_isLocked);
    }
  }

  void _emitSettings() {
    if (!_settingsController.isClosed) {
      _settingsController.add(_settings);
    }
  }

  void dispose() {
    _lockStateController.close();
    _settingsController.close();
  }
}

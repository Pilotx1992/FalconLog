import 'package:hive/hive.dart';

part 'security_settings.g.dart';

/// Security configuration stored in Hive.
///
/// **Hive = metadata only.** PIN hash and salt live in FlutterSecureStorage.
@HiveType(typeId: 10)
class SecuritySettings extends HiveObject {
  /// Whether PIN protection is enabled.
  @HiveField(0)
  bool isPinEnabled;

  /// Whether biometric unlock is enabled for the app lock screen.
  /// Only meaningful when [isPinEnabled] is true and the device supports
  /// biometrics. This flag controls **app‑lock biometric** only — it has
  /// nothing to do with Firebase login.
  @HiveField(1)
  bool isAppLockBiometricEnabled;

  /// Consecutive failed PIN attempts since last successful unlock.
  @HiveField(2)
  int failedAttempts;

  /// If non‑null and in the future, the user is temporarily locked out.
  @HiveField(3)
  DateTime? lockoutUntil;

  /// Timestamp of last successful unlock (PIN or biometric).
  @HiveField(4)
  DateTime? lastUnlockedAt;

  /// Seconds of inactivity (app backgrounded) before auto‑lock.
  /// `0` means "immediately on pause".  Negative / very large = never.
  @HiveField(5)
  int autoLockTimeoutSeconds;

  /// When the current security session began.
  @HiveField(6)
  DateTime? sessionStartTime;

  /// Last user interaction time (in‑memory authoritative; Hive is
  /// best‑effort, flushed at most once every ~45 s and on app pause).
  @HiveField(7)
  DateTime? lastInteractionTime;

  /// Session duration in seconds.  After this period with no interaction
  /// the app may re‑lock on next resume.
  @HiveField(8)
  int sessionDurationSeconds;

  SecuritySettings({
    this.isPinEnabled = false,
    this.isAppLockBiometricEnabled = false,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.lastUnlockedAt,
    this.autoLockTimeoutSeconds = 60,
    this.sessionStartTime,
    this.lastInteractionTime,
    this.sessionDurationSeconds = 900, // 15 minutes
  });

  /// Factory for default initial settings.
  factory SecuritySettings.initial() {
    return SecuritySettings(
      isPinEnabled: false,
      isAppLockBiometricEnabled: false,
      failedAttempts: 0,
      autoLockTimeoutSeconds: 60,
      sessionDurationSeconds: 900,
    );
  }

  /// Copy with updated fields.
  SecuritySettings copyWith({
    bool? isPinEnabled,
    bool? isAppLockBiometricEnabled,
    int? failedAttempts,
    DateTime? lockoutUntil,
    DateTime? lastUnlockedAt,
    int? autoLockTimeoutSeconds,
    DateTime? sessionStartTime,
    DateTime? lastInteractionTime,
    int? sessionDurationSeconds,
  }) {
    return SecuritySettings(
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      isAppLockBiometricEnabled:
          isAppLockBiometricEnabled ?? this.isAppLockBiometricEnabled,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: lockoutUntil,
      lastUnlockedAt: lastUnlockedAt,
      autoLockTimeoutSeconds:
          autoLockTimeoutSeconds ?? this.autoLockTimeoutSeconds,
      sessionStartTime: sessionStartTime,
      lastInteractionTime: lastInteractionTime,
      sessionDurationSeconds:
          sessionDurationSeconds ?? this.sessionDurationSeconds,
    );
  }

  @override
  String toString() {
    return 'SecuritySettings('
        'isPinEnabled: $isPinEnabled, '
        'isAppLockBiometricEnabled: $isAppLockBiometricEnabled, '
        'failedAttempts: $failedAttempts, '
        'lockoutUntil: $lockoutUntil, '
        'autoLockTimeoutSeconds: $autoLockTimeoutSeconds, '
        'sessionDurationSeconds: $sessionDurationSeconds)';
  }
}

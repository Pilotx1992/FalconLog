/// Constants for the security subsystem.
///
/// Centralises thresholds, storage keys, lockout schedule, and
/// auto‑lock timeout presets so they are trivially auditable.
class SecurityConstants {
  SecurityConstants._();

  // ── FlutterSecureStorage keys ──────────────────────────────────────
  static const String pinHashKey = 'falconlog_pin_hash';
  static const String pinSaltKey = 'falconlog_pin_salt';

  // ── Hive box ───────────────────────────────────────────────────────
  static const String settingsBoxName = 'securitySettingsBox';

  // ── PBKDF2 parameters ─────────────────────────────────────────────
  static const int pbkdf2Iterations = 100000;
  static const int saltLengthBytes = 32;
  static const int derivedKeyLengthBytes = 32;

  // ── PIN rules ─────────────────────────────────────────────────────
  static const int pinLength = 4;

  // ── Lockout schedule ──────────────────────────────────────────────
  /// Threshold → lockout duration mapping.
  /// Evaluated top‑down; first match wins.
  static const List<({int threshold, Duration duration})> lockoutSchedule = [
    (threshold: 10, duration: Duration(minutes: 5)),
    (threshold: 5, duration: Duration(seconds: 30)),
  ];

  /// Max failed attempts before the longest lockout applies.
  static int get maxFailedAttempts => lockoutSchedule.first.threshold;

  // ── Auto‑lock timeout presets (seconds) ───────────────────────────
  /// `0` means "immediately on pause".
  static const List<({int seconds, String label})> autoLockPresets = [
    (seconds: 0, label: 'Immediately'),
    (seconds: 30, label: '30 seconds'),
    (seconds: 60, label: '1 minute'),
    (seconds: 300, label: '5 minutes'),
    (seconds: 900, label: '15 minutes'),
  ];

  /// Default auto‑lock timeout in seconds.
  static const int defaultAutoLockTimeoutSeconds = 60;

  /// Default session duration in seconds (15 min).
  static const int defaultSessionDurationSeconds = 900;

  // ── Interaction throttle ──────────────────────────────────────────
  /// Minimum interval between Hive flushes for `lastInteractionTime`.
  static const Duration interactionPersistThrottle = Duration(seconds: 45);
}

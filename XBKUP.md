# FalconLog Backup System — Enhanced PRD

## 1. Executive Summary
- Objective: Deliver a secure, reliable, and user‑friendly backup, restore, and cloud sync system for FalconLog (Android/iOS/Desktop) with Google Drive integration, supporting full/incremental/differential backups, background scheduling, progress tracking, and clear UX.
- Scope: Local encrypted backups, Google Drive upload/download/list/delete, restore (with selective options), sync (local ↔ cloud), scheduling (WorkManager), integrity checks, and robust error handling. Integrated with Riverpod, Hive, and existing app services.

## 2. Goals & Non‑Goals
- Security: AES‑256‑GCM encryption, secure key storage, integrity verification.
- Reliability: Resumable uploads, exponential backoff, verification, retention policies.
- UX: Simple flows, progress + notifications, understandable errors, preview before restore.
- Performance: Compression before encryption, streaming/chunking, non‑blocking operations.
- Maintainability: Modular services with clear contracts, testable, Riverpod‑aware providers.
- Out of scope (v1): Multi‑provider cloud (AWS/Azure), real‑time multi‑device merge, desktop cloud background scheduling parity.

## 3. Personas & Use Cases
- Single pilot: periodic auto‑backups and device migration via Drive.
- Power user: selective restore by date/type, manual on‑demand sync, verification.
- Reliability‑focused: scheduled backups, retention (keep last N), storage/health insights.

## 4. Architecture Overview
- Auth: `lib/services/drive_auth_service.dart` — Google Sign‑In; silent sign‑in; OAuth headers.
- Drive API: `lib/services/google_drive_service.dart` — ensure backup folder, list/upload/download/delete, space summary, cached folderId.
- Local backup core: `lib/backup/services/backup_service.dart` — create full/incremental/differential backups; write encrypted `.flb/.enc` files; persist `BackupMetadata` in Hive.
- Encryption: `lib/backup/services/encryption_service.dart` — master key in `FlutterSecureStorage`, AES‑256‑GCM encrypt/decrypt, PBKDF2 helpers.
- Cloud orchestration: `lib/backup/services/cloud_backup_service.dart` — coordinates local backup then Drive upload; download + handoff to restore; sync glue.
- Restore: `lib/backup/services/restore_service.dart` — validate, decrypt, extract, selective recovery, post‑verify.
- Scheduler: `lib/backup/services/scheduler_service.dart` — WorkManager periodic tasks + internal timer; Hive box for schedules.
- Progress/Notifications: `lib/backup/services/progress_service.dart` — track operations in Hive; show notifications.
- Data model: `lib/backup/models/backup_metadata.dart` — enriched metadata (location, encryption, compression, status/health).
- Providers: Riverpod DI for all services (`googleDriveServiceProvider`, `cloudBackupServiceProvider`, `backupServiceProvider`, etc.).

### 4.1 Project Structure (relevant)
- `lib/backup/models/` — backup_metadata.dart, backup_result.dart, restore_options.dart, sync_operation.dart
- `lib/backup/services/` — backup_service.dart, cloud_backup_service.dart, restore_service.dart, encryption_service.dart, compression_service.dart, scheduler_service.dart, progress_service.dart, validation_service.dart
- `lib/backup/screens/` — backup_restore_screen.dart
- `lib/backup/widgets/` — backup_dashboard.dart, restore_wizard.dart, export_import_widget.dart
- `lib/services/` — drive_auth_service.dart, google_drive_service.dart, notification_service.dart
- `lib/models/` — flight_log.dart (+ Hive adapters)

## 5. Data & File Formats
- Backup payload (pre‑encryption): JSON { schema, created_at, logs_count, logs[] from FlightLog.toJson() }.
- Backup file name: `falconlog_backup_<epoch>.enc` (compressed + encrypted; compression may be `NONE` initially).
- Metadata (Hive, `BackupMetadata`): id, fileName, type (full/incremental/differential), createdAt, sizeBytes, checksum, recordCount, location (local/googleDrive/both), isEncrypted, encryptionAlgorithm, compressionType, compressionRatio, status, health, cloudId, lastVerified, parentBackupId.
- Drive folder: `FalconLog_Backups/` containing `.enc` files; optional sidecar `.meta.json` or file appProperties.

## 6. Security & Key Management
- Encryption: AES‑256‑GCM with unique IV per backup; associated data may include filename/backupId.
- Master key (MK): generated and stored in `FlutterSecureStorage` (Android encrypted shared prefs, iOS Keychain).
- Integrity: SHA‑256 checksums stored in metadata and verified before restore.
- Phase‑2 (optional): user passphrase → KEK (PBKDF2‑HMAC‑SHA256, ≥100k iters) to wrap MK; store wrapped MK JSON in Drive `appDataFolder` + locally; unlock on new device by passphrase.
- Logging: never print OAuth tokens, keys, or plaintext; redact PII; enable secure diagnostics mode for dev builds only.

## 7. Functional Requirements
### 7.1 Local Backups
- Full backup: all logs.
- Incremental backup: logs created/updated after last backup timestamp.
- Differential backup: delta since last full.
- Verification: compute checksum, persist size; optional post‑write verification.

### 7.2 Google Drive
- Ensure backup folder exists (cached folderId via SharedPreferences).
- Upload encrypted backups (streamed/chunked), retries with exponential backoff on transient failures.
- List backups: sorted by modifiedTime desc; include name, size, created/modified times, id.
- Download backup to temp; verify checksum; return `File` for restore.
- Delete backup; Prune keeping last N by date.
- Storage info: total backups, total size, oldest/newest; formatted sizes.

### 7.3 Restore
- Preview: parse backup, compute summary (total logs, date range, aircraft/type breakdown).
- Selective restore: filter by date range and/or flight types.
- Integrity: validate schema + checksum; on failure, block restore with clear guidance.
- Optional pre‑restore backup of current state.

### 7.4 Scheduling
- WorkManager periodic tasks (Hourly/Daily/Weekly/Monthly) with constraints (Wi‑Fi only, battery not low, charging optional).
- Foreground timer checks (every minute) to catch missed runs when app active.
- Persist schedule states, last run, last result, consecutive failures.

### 7.5 Progress & Notifications
- Persist progress in Hive: started → inProgress (percentage) → completed/failed/cancelled.
- Local notifications for start/progress/completion/failure; tapping opens details.

## 8. Non‑Functional Requirements
- Performance: full backup (5k logs) ≤ 10s; restore ≤ 15s; upload 20MB ≤ 45s over Wi‑Fi.
- Reliability: >99% success on stable network; 3 retries with backoff; safe temp cleanup on failure.
- Resource usage: streamed IO for upload/download; memory bounded; respect Wi‑Fi‑only policy.
- Retention: default keep 10 backups; configurable 1–50; prune strategy by newest.

## 9. Module Contracts (Key APIs)
### DriveAuthService (`lib/services/drive_auth_service.dart`)
- `Future<GoogleSignInAccount?> signIn({bool interactive, bool attemptSilent})`
- `Future<Map<String,String>> getAuthHeaders({bool interactive, bool attemptSilent})`
- `Future<void> signOut({bool disconnect})`

### GoogleDriveService (`lib/services/google_drive_service.dart`)
- `Future<String?> ensureBackupFolder({bool interactive = true})`
- `Future<List<DriveFileMeta>> listBackups({bool interactive = false})`
- `Future<String?> uploadEncryptedBackup(File file, {required BackupMetadata metadata, bool interactive = false})`
- `Future<File?> downloadBackup(String fileId, {String? localPath, bool interactive = false})`
- `Future<bool> deleteBackup(String fileId, {bool interactive = false})`
- `Future<void> pruneBackups(int keepCount, {bool interactive = false})`
- `Future<Map<String, dynamic>> getStorageInfo({bool interactive = false})`

### BackupService (`lib/backup/services/backup_service.dart`)
- `Future<BackupResult> createFullBackup({required List<FlightLog> logs, ...})`
- `Future<BackupResult> createIncrementalBackup({required List<FlightLog> logs, required String? lastBackupId, ...})`
- `Future<BackupResult> createDifferentialBackup({required List<FlightLog> logs, required String? lastFullBackupId, ...})`
- `List<BackupMetadata> getAllBackups()`
- `Future<ValidationResult> verifyBackup(String backupId)`

### CloudBackupService (`lib/backup/services/cloud_backup_service.dart`)
- `Future<BackupResult> createCloudBackup({...})` — orchestrates local backup then upload.
- `Future<RestoreResult> restoreFromCloud({...})` — download + restore pipeline.
- `Future<SyncResult> syncWithCloud()` — minimal up‑sync; bidirectional roadmap.

### RestoreService (`lib/backup/services/restore_service.dart`)
- `restoreFromBackup({required File backupFile, required BackupMetadata metadata, RestoreOptions? options})`
- `previewBackup({required File backupFile, required BackupMetadata metadata})`

### SchedulerService (`lib/backup/services/scheduler_service.dart`)
- `initialize()`, manage schedules, register WorkManager tasks, track results.

### ProgressService (`lib/backup/services/progress_service.dart`)
- `startProgress`, `updateProgress`, `complete`, `fail`, `cancel` with notifications.

## 10. UI/UX Specification
### Information Architecture
- Backup & Restore Screen (`lib/backup/screens/backup_restore_screen.dart`)
  - Tabs: Backups | Restore | Schedule | Settings
  - Backups: Local / Cloud switch; list with size/date/health; actions: Verify, Delete, Prune, Sync Now, Create (Full/Inc/Diff).
  - Restore: Select cloud/local backup → Preview (summary) → Options (date range, flight types) → Confirm.
  - Schedule: List schedules; Add/Edit (type, frequency, constraints, keep N); last run/result; enable/disable.
  - Settings: Encryption (Phase‑2 passphrase), Network policy (Wi‑Fi only), Retention, Diagnostics.

### Key Flows
- Cloud Backup: Check Drive auth → Create local backup → Upload (ensure folder, resumable, retries) → Update `cloudId`/status → Notify success.
- Cloud Restore: List Drive backups → Pick → Download → Verify checksum → Decrypt → Preview → Selective restore → Verify → Notify.
- Scheduling: Configure schedule → WorkManager registers → Background run updates progress + notifications.

### Visual/States (textual)
- List item: `[icon][name]  [formattedSize]  [age]  [healthBadge]  [providerBadge]`
- Progress banner: `Backing up… 42% · Encrypting` with cancel when applicable.
- Notification samples: `Backup completed (12.3MB)`, `Restore failed: checksum mismatch`.

## 11. Error Handling
- Auth errors: sign‑in required, scope missing, token fetch failed — actionable messages.
- Network: retries (3x) with backoff; offline → notify and defer; show remaining attempts.
- Storage: disk full/Drive quota exceeded → show usage and prune option; cleanup temp files on failure.
- Integrity: checksum mismatch or schema invalid → block restore; mark backup as corrupted; guide user.

## 12. Performance & Limits
- Targets: 5k logs backup ≤ 10s; restore ≤ 15s; 20MB upload ≤ 45s (Wi‑Fi).
- Chunk sizes: 2–8MB per upload; streamed download; bounded memory.
- Retention default: keep 10 (configurable 1–50); prune oldest first.

## 13. Testing Strategy
- Unit: encryption (IV uniqueness, MAC), PBKDF2, checksum, metadata serialize/deserialize, selection logic (inc/diff), Drive folder creation/caching.
- Integration: end‑to‑end local → cloud → download → restore, with injected failures (auth/network/quota).
- Instrumentation: WorkManager background run without UI; verify notifications and Hive persisted progress.
- Manual QA: passphrase wrong/correct, missing keywrap (Phase‑2), no network, large backups.

## 14. Rollout Plan
- Phase 1: Implement Drive upload/download/list/delete/prune; replace TODOs in `cloud_backup_service.dart`; enable real compression; basic UI wiring.
- Phase 2: Recovery passphrase + key‑wrap in `appDataFolder`; migration prompt for existing users.
- Phase 3: Selective restore wizard polish; richer storage analytics; retention UI.
- Phase 4: Performance optimizations; advanced scheduling options.

## 15. Acceptance Criteria
- Encrypted backup uploaded to Drive with `cloudId` persisted; visible in Cloud list; progress + completion notifications emitted.
- Download + decrypt + restore yields original logs; counts and checksum verified.
- Scheduling runs headless within constraints; results recorded; user notified of success/failure.
- Prune keeps N newest; storage info reflects changes; no orphaned metadata.
- No sensitive tokens/keys/plaintext in logs; temp artifacts cleaned on failure.

## 16. Open Questions
- Store metadata as Drive appProperties vs sidecar JSON? (Prefer appProperties; keep sidecar as fallback.)
- Default retention by user profile (basic 5, pro 20)?
- iOS background constraints parity with WorkManager — roadmap items.


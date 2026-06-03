# FalconLog Backup System - Product Requirements Document (PRD)

## Executive Summary

This PRD defines a WhatsApp-style encrypted backup system for FalconLog, based on the proven architecture from the alkhazna project. The system provides secure, automatic cloud backups with end-to-end encryption, eliminating all file system path issues by storing encrypted data directly in Google Drive's AppDataFolder.

**Key Benefits:**
- ✅ No file system errors (direct cloud storage)
- ✅ End-to-end encryption (AES-256-GCM)
- ✅ WhatsApp-style user experience
- ✅ Automatic scheduled backups
- ✅ Single-tap backup and restore
- ✅ Cross-device support

---

## 1. alkhazna Backup Architecture Analysis

### 1.1 System Overview

alkhazna implements a production-ready WhatsApp-style backup system with the following characteristics:

**Architecture Pattern:** Direct Cloud Storage (No Local Files)
```
User Data → Hive Database → Encryption → Google Drive AppDataFolder
                                ↓
                        Persistent Master Key
                                ↓
                    Google Drive (Encrypted Key File)
                                +
                    Local Secure Storage (Fallback)
```

**Core Components:**
1. **BackupService** - Main orchestrator with 7-step backup/restore workflow
2. **EncryptionService** - AES-256-GCM encryption (crypt14 format)
3. **GoogleDriveService** - Direct AppDataFolder integration
4. **KeyManager** - Persistent master key management
5. **BackupScheduler** - WorkManager-based auto-backup
6. **NotificationHelper** - Real-time progress notifications
7. **BackupErrorHandler** - Comprehensive error handling

### 1.2 File Structure

```
lib/backup/
├── models/
│   ├── backup_metadata.dart       # Backup information
│   ├── backup_status.dart         # Status enums with display helpers
│   ├── restore_result.dart        # Restore operation results
│   └── key_file_format.dart       # Encryption key storage format
├── services/
│   ├── backup_service.dart        # Main backup/restore orchestrator (613 lines)
│   ├── encryption_service.dart    # AES-256-GCM encryption
│   ├── google_drive_service.dart  # Google Drive API wrapper
│   └── key_manager.dart           # Master key lifecycle
├── ui/
│   ├── backup_settings_page.dart  # Settings interface
│   ├── backup_progress_sheet.dart # Real-time progress display
│   ├── backup_screen.dart         # Main backup screen
│   └── restore_dialog.dart        # Restore confirmation dialog
└── utils/
    ├── backup_constants.dart      # All constants and messages
    ├── backup_scheduler.dart      # Auto-backup with OEM workarounds
    ├── error_handler.dart         # User-friendly error handling
    └── notification_helper.dart   # Progress notifications
```

### 1.3 Key Technical Decisions

#### 1.3.1 No Local File Storage
**Decision:** Store encrypted backups directly in Google Drive AppDataFolder
**Rationale:** Eliminates all file system permission issues that plagued FalconLog's backup implementations

#### 1.3.2 Persistent Master Key
**Decision:** Use same 256-bit AES key per Google account, stored in cloud + local secure storage
**Rationale:**
- Enables cross-device restore (same key on all devices)
- Prevents key loss (cloud backup of key itself)
- Maintains WhatsApp-style user experience (no password entry)

#### 1.3.3 crypt14 Format
**Decision:** Use WhatsApp's crypt14-inspired format
**Rationale:**
- Industry-proven encryption pattern
- AES-256-GCM provides authenticated encryption
- Base64 encoding for safe cloud storage

#### 1.3.4 7-Step Process
**Decision:** Break backup/restore into 7 distinct steps with progress tracking
**Rationale:**
- Clear user feedback (14-28% per step)
- Easy to debug failures (know exactly which step failed)
- Professional user experience

### 1.4 Backup Workflow

```
BACKUP PROCESS (7 Steps):
Step 1 (0-14%):   Check connectivity → Exit early if no internet
Step 2 (14-28%):  Initialize Google Drive → Get authenticated API client
Step 3 (28-42%):  Get/Create master key → KeyManager handles cloud + local
Step 4 (42-57%):  Create database backup → Read Hive database bytes
Step 5 (57-71%):  Encrypt database → AES-256-GCM encryption
Step 6 (71-85%):  Upload to Drive → AppDataFolder upload
Step 7 (85-100%): Save metadata → Store backup info locally

RESTORE PROCESS (7 Steps):
Step 1 (0-14%):   Check connectivity
Step 2 (14-28%):  Initialize Google Drive
Step 3 (28-42%):  Find backup in Drive
Step 4 (42-57%):  Download encrypted backup
Step 5 (57-71%):  Retrieve master key
Step 6 (71-85%):  Decrypt database
Step 7 (85-100%): Restore to Hive
```

### 1.5 Encryption Details

**Algorithm:** AES-256-GCM (Galois/Counter Mode)
- **Key Size:** 256 bits (32 bytes)
- **Nonce Size:** 96 bits (12 bytes) - randomly generated per encryption
- **Tag Size:** 128 bits (16 bytes) - authentication tag
- **Associated Data:** Backup ID string for additional security

**Encryption Output Format:**
```json
{
  "encrypted": true,
  "version": "1.0",
  "backup_id": "unique_backup_id",
  "original_size": 123456,
  "timestamp": "2025-09-30T...",
  "data": "base64_encoded_ciphertext",
  "iv": "base64_encoded_nonce",
  "tag": "base64_encoded_mac"
}
```

**Master Key Storage:**
```json
{
  "version": 1.1,
  "user_email": "user@example.com",
  "normalized_email": "userexamplecom",
  "google_id": "unique_google_id",
  "device_id": "Samsung-GalaxyS21",
  "created_at": "2025-09-30T...",
  "checksum": "sha256-abcd1234",
  "key_bytes": "base64_encoded_256bit_key"
}
```

### 1.6 Auto-Backup System

**Technology:** WorkManager (Android background tasks)

**Features:**
- Periodic tasks (daily/weekly/monthly)
- Network constraints (WiFi-only or WiFi+Mobile)
- Battery optimization handling
- OEM-specific workarounds (Xiaomi, OnePlus, etc.)

**OEM Workarounds:**
```dart
// OnePlus devices: Relaxed constraints
Constraints(
  networkType: NetworkType.unmetered,
  requiresBatteryNotLow: false,  // Don't wait for high battery
  requiresDeviceIdle: false,     // Don't wait for idle state
)

// Other devices: Standard constraints
Constraints(
  networkType: NetworkType.unmetered,
  requiresBatteryNotLow: true,
  requiresDeviceIdle: true,
)
```

### 1.7 Error Handling

**Error Categories:**
1. **Network Errors** - No internet, timeout, connection failed
2. **Authentication Errors** - Google sign-in failed, permissions denied
3. **Storage Errors** - Drive quota exceeded, insufficient space
4. **Encryption Errors** - Key generation failed, decryption failed
5. **Database Errors** - Backup creation failed, restore failed

**User Experience:**
- User-friendly error messages (no technical jargon)
- Actionable buttons (Retry, Sign In, Manage Storage)
- Visual error indicators (icons + colors)
- Detailed logging for debugging (kDebugMode only)

### 1.8 State Management

**Pattern:** ChangeNotifier with Singleton services

```dart
class BackupService extends ChangeNotifier {
  // Progress tracking
  int _currentStep = 0;
  int _totalSteps = 7;
  String _currentStepMessage = '';
  BackupStatus _status = BackupStatus.idle;

  // Notify listeners on every update
  void _updateProgress(int step, String message, BackupStatus status) {
    _currentStep = step;
    _currentStepMessage = message;
    _status = status;
    notifyListeners();  // UI automatically updates
  }
}
```

**UI Reactivity:**
```dart
// UI listens to BackupService
backupService.addListener(() {
  setState(() {
    // UI rebuilds automatically when service notifies
    percentage = backupService.currentProgress.percentage;
    message = backupService.currentProgress.currentAction;
  });
});
```

---

## 2. FalconLog Current State Analysis

### 2.1 Current Backup Implementations

FalconLog has **MULTIPLE CONFLICTING** backup systems:

**1. NEW Military-Grade System** (`lib/backup/`)
- Complex multi-level architecture
- Local file storage with compression
- Multiple backup service variants
- **PROBLEM:** File system path errors

**2. OLD Simple System** (`lib/services/`)
- `backup_service.dart` - Simple backup
- `backup_service_simple.dart` - Simplified variant
- `drive_backup_service.dart` - Drive integration
- **PROBLEM:** Mixed with new system, causing confusion

**3. Backup V2 System** (`lib/services/backup_v2/`)
- Incremental backup engine
- Chunk-based architecture
- Retention policies
- **PROBLEM:** Deleted or partially deleted

### 2.2 Issues with Current Systems

1. **File System Errors**
   - `FileSystemException: Creation failed, path = iOS (OS Error: Read-only file system, errno = 30)`
   - Multiple attempts to fix with `getApplicationDocumentsDirectory()` failed
   - Persists even after cleaning and rebuilding

2. **System Complexity**
   - Too many layers (OptimizedBackupService, CloudBackupService, etc.)
   - Hard to debug which code path is executing
   - Multiple providers importing different services

3. **Incomplete Integration**
   - New backup screen exists but not integrated
   - Old and new systems both present
   - Unclear which system is active

4. **Over-Engineering**
   - Military-grade features not needed for flight logs
   - Complex compression, chunking, incremental backups
   - More code = more bugs

### 2.3 What Needs to be Removed

**Delete Entire Directories:**
```
lib/backup/                     # NEW military-grade system
lib/services/backup_v2/         # V2 incremental system (if exists)
```

**Delete Individual Files:**
```
lib/services/backup_service.dart
lib/services/backup_service_simple.dart
lib/services/backup_bundle_service.dart
lib/services/drive_backup_service.dart
lib/services/backup_fix_service.dart (already deleted)
lib/services/backup_logger.dart (already deleted)
lib/screens/advanced_backup_screen.dart (already deleted)
lib/screens/backup_debug_screen.dart (already deleted)
lib/screens/restore_test_screen.dart (already deleted)
lib/widgets/backup_fix_widget.dart (already deleted)
lib/widgets/backup_widgets_safe.dart (already deleted)
```

**Modify Files:**
```
lib/providers/backup_provider.dart  # Remove backup logic, make it call new service
lib/screens/settings_screen.dart    # Update backup settings UI to use new system
```

---

## 3. FalconLog New Backup System Requirements

### 3.1 Functional Requirements

**FR-1: Single-Tap Backup**
- User taps "Backup Now" button
- System creates encrypted backup and uploads to Google Drive
- Shows progress with 7 steps
- Completes in under 2 minutes for typical database size
- Success/failure notification

**FR-2: Automatic Backups**
- User can enable auto-backup (Off/Daily/Weekly/Monthly)
- System runs backup automatically in background
- Respects network preference (WiFi-only or WiFi+Mobile)
- Shows notification when backup completes
- Reminder notification if backup hasn't run in configured period

**FR-3: Single-Tap Restore**
- User taps "Restore from Backup" button
- System finds latest backup in Google Drive
- Shows backup metadata (date, device, size)
- User confirms restore action
- System downloads, decrypts, and restores database
- App restarts with restored data

**FR-4: Google Account Integration**
- One Google account per device at a time
- Can change Google accounts
- Each account has separate backup
- Backup follows the Google account (cross-device)

**FR-5: End-to-End Encryption**
- All backups encrypted with AES-256-GCM
- Master key stored in Google Drive (encrypted) + local secure storage
- User never enters encryption password
- Same key across all user's devices (WhatsApp-style)

**FR-6: Network Optimization**
- WiFi-only mode (default)
- WiFi+Mobile mode (optional)
- Automatic retry on network failure
- Timeout handling

### 3.2 Non-Functional Requirements

**NFR-1: Security**
- AES-256-GCM authenticated encryption
- Master key stored in FlutterSecureStorage (local) + Google Drive AppDataFolder (cloud)
- No encryption keys in logs
- Backup files stored in Google Drive AppDataFolder (hidden from user)

**NFR-2: Reliability**
- No file system operations (eliminates path errors)
- Comprehensive error handling
- Automatic retry on transient failures
- State persistence across app restarts

**NFR-3: Performance**
- Backup completes in under 2 minutes for 1000 flight logs
- Restore completes in under 1 minute
- Background backups don't drain battery
- Minimal app size increase (<500KB)

**NFR-4: Usability**
- WhatsApp-like UI/UX
- Clear progress indicators
- User-friendly error messages
- Single settings screen
- No technical jargon

**NFR-5: Maintainability**
- Single backup service (no multiple variants)
- Clear separation of concerns
- Comprehensive logging in debug mode
- Well-documented code

### 3.3 Technical Specifications

**Platform:** Flutter (Android, iOS, Desktop)

**Required Packages:**
```yaml
dependencies:
  google_sign_in: ^6.2.1              # Google authentication
  googleapis: ^13.2.0                  # Google Drive API
  googleapis_auth: ^1.6.0              # API authentication
  cryptography: ^2.7.0                 # AES-256-GCM encryption
  flutter_secure_storage: ^9.2.2       # Local key storage
  connectivity_plus: ^6.1.0            # Network status
  shared_preferences: ^2.3.3           # Settings storage
  hive: ^2.2.3                         # Database
  hive_flutter: ^1.1.0
  device_info_plus: ^11.1.1            # Device identification

  # Android-only (auto-backup)
  workmanager: ^0.5.2                  # Background tasks

  # Notifications
  flutter_local_notifications: ^18.0.1 # Progress notifications
```

**File Size Limits:**
- Max backup size: 100 MB (typical flight log database: 1-10 MB)
- Max Google Drive AppDataFolder: Unlimited (part of user's Drive quota)

**Encryption Specifications:**
- Algorithm: AES-256-GCM
- Key derivation: Direct random key generation (not password-based)
- Nonce: 12 bytes random per encryption
- Tag: 16 bytes authentication tag
- Associated Data: Backup ID string

**Google Drive Scopes:**
```dart
scopes: [
  'https://www.googleapis.com/auth/drive.appdata',  # AppDataFolder access
  'email',                                          # User email
  'profile',                                        # User profile
]
```

### 3.4 Data Models

**FlightLog Backup Metadata:**
```dart
class BackupMetadata {
  final String version;           // "1.0"
  final String userEmail;         // "pilot@example.com"
  final String normalizedEmail;   // "pilotexamplecom" (for matching)
  final String googleId;          // Unique Google account ID
  final String deviceId;          // "Android-Pixel7"
  final DateTime createdAt;       // Backup timestamp
  final String checksum;          // Data integrity check
  final int fileSizeBytes;        // Encrypted file size
  final String driveFileId;       // Google Drive file ID
  final int flightLogsCount;      // Number of flight logs in backup
}
```

**Backup Status:**
```dart
enum BackupStatus {
  idle,         // Ready to start
  preparing,    // Step 1-2: Connectivity + Drive init
  encrypting,   // Step 3-5: Key + Database + Encrypt
  uploading,    // Step 6: Upload to Drive
  completed,    // Step 7: Success
  failed,       // Error occurred
  cancelled,    // User cancelled
}
```

**Restore Result:**
```dart
class RestoreResult {
  final bool success;
  final String? errorMessage;
  final int? flightLogsRestored;
  final DateTime? backupDate;
  final String? sourceDevice;
}
```

### 3.5 User Interface Specifications

**Settings Screen - Backup Section:**
```
┌─────────────────────────────────────┐
│ Google Account                      │
│ ├─ [Avatar] pilot@example.com      │
│ └─ [Change]                         │
├─────────────────────────────────────┤
│ Last Backup                         │
│ └─ 2 hours ago                      │
├─────────────────────────────────────┤
│ [     🔄 Backup Now     ]          │  ← Green button
├─────────────────────────────────────┤
│ Auto Backup                         │
│ ○ Off                               │
│ ○ Daily                             │
│ ● Weekly                            │
│ ○ Monthly                           │
├─────────────────────────────────────┤
│ Network Preference                  │
│ ☑ Wi-Fi only                       │
├─────────────────────────────────────┤
│ 🔒 Secure & Private                 │
│ Your data is encrypted and stored   │
│ securely in your Google Drive.      │
└─────────────────────────────────────┘
```

**Backup Progress Sheet:**
```
┌─────────────────────────────────────┐
│        Backing up...                │
│                                     │
│    [████████████░░░░░░░░] 57%      │
│                                     │
│ 🔐 Encrypting your data...          │
│                                     │
│ Step 5 of 7                         │
└─────────────────────────────────────┘
```

**Restore Dialog:**
```
┌─────────────────────────────────────┐
│ Restore from Backup?                │
│                                     │
│ Backup found:                       │
│ • Date: Sep 30, 2025 at 2:30 PM    │
│ • Device: Android-Pixel7            │
│ • Flight logs: 754                  │
│ • Size: 2.4 MB                      │
│                                     │
│ This will replace your current data.│
│                                     │
│ [Cancel]             [Restore] ←────│  Blue button
└─────────────────────────────────────┘
```

---

## 4. Implementation Plan

### 4.1 Phase 1: Cleanup (Day 1)

**Goal:** Remove all existing backup systems

**Tasks:**
1. ✅ Delete `lib/backup/` directory
2. ✅ Delete backup_v2 files in `lib/services/`
3. ✅ Delete old backup service files
4. ✅ Remove backup-related imports from providers
5. ✅ Remove backup widgets
6. ✅ Comment out backup UI in settings screen
7. ✅ Test app runs without errors
8. ✅ Commit: "Remove all backup systems in preparation for new implementation"

**Acceptance Criteria:**
- App starts successfully
- No import errors
- No file system errors
- Settings screen loads (backup section commented out)

### 4.2 Phase 2: Core Services (Day 1-2)

**Goal:** Implement core backup services

**Tasks:**
1. Create `lib/backup/` directory structure
2. Implement `models/`:
   - `backup_metadata.dart`
   - `backup_status.dart`
   - `restore_result.dart`
   - `key_file_format.dart`
3. Implement `services/encryption_service.dart`:
   - Copy from alkhazna
   - Adapt for FalconLog data structures
4. Implement `services/google_drive_service.dart`:
   - Copy from alkhazna
   - Change file names to `falconlog_backup.db.crypt14`
5. Implement `services/key_manager.dart`:
   - Copy from alkhazna
   - Change key file name to `falconlog_backup_keys.encrypted`
6. Test encryption/decryption in unit tests

**Acceptance Criteria:**
- All services compile without errors
- Unit tests pass for encryption
- Can authenticate with Google Drive
- Can upload/download files to AppDataFolder

### 4.3 Phase 3: Main Backup Service (Day 2-3)

**Goal:** Implement backup/restore orchestration

**Tasks:**
1. Implement `services/backup_service.dart`:
   - 7-step backup workflow
   - 7-step restore workflow
   - Progress tracking with ChangeNotifier
   - Error handling
2. Adapt for FalconLog specifics:
   - Use Hive FlightLog box
   - Handle flight log count in metadata
   - Custom associated data string
3. Create `utils/backup_constants.dart`:
   - All error messages
   - Progress messages
   - Configuration constants
4. Create `utils/error_handler.dart`:
   - User-friendly error mapping
   - Network/auth/storage error detection

**Acceptance Criteria:**
- Can create encrypted backup of flight logs
- Can restore flight logs from backup
- Progress callbacks work correctly
- Errors are handled gracefully

### 4.4 Phase 4: User Interface (Day 3-4)

**Goal:** Implement backup UI

**Tasks:**
1. Create `ui/backup_settings_page.dart`:
   - Google account section
   - Last backup info
   - Backup Now button
   - Auto backup settings (Off/Daily/Weekly/Monthly)
   - Network preference toggle
2. Create `ui/backup_progress_sheet.dart`:
   - Progress bar
   - Current step message
   - Step counter (X of 7)
   - Cancel button
3. Create `ui/restore_dialog.dart`:
   - Backup metadata display
   - Confirmation buttons
   - Warning message
4. Integrate into `screens/settings_screen.dart`:
   - Add "Backup & Restore" section
   - Link to BackupSettingsPage

**Acceptance Criteria:**
- Can tap "Backup Now" and see progress
- Progress updates in real-time
- Can restore from backup
- UI matches design specifications

### 4.5 Phase 5: Auto-Backup (Day 4-5)

**Goal:** Implement automatic scheduled backups

**Tasks:**
1. Create `utils/backup_scheduler.dart`:
   - WorkManager initialization
   - Schedule periodic backups
   - Network constraints
   - OEM workarounds (if needed)
2. Create `utils/notification_helper.dart`:
   - Progress notifications
   - Completion notifications
   - Reminder notifications
3. Initialize in `main.dart`:
   - WorkManager initialization
   - Notification channels
4. Test background execution:
   - Kill app and verify backup runs
   - Test on OnePlus/Xiaomi if available

**Acceptance Criteria:**
- Auto-backup runs on schedule
- Notifications appear correctly
- Background execution works reliably
- Network constraints respected

### 4.6 Phase 6: Testing & Polish (Day 5-6)

**Goal:** Test all scenarios and polish UX

**Tasks:**
1. Test happy path:
   - Backup → Restore on same device
   - Backup on Device A → Restore on Device B
2. Test error scenarios:
   - No internet connection
   - Google sign-in failure
   - Drive quota exceeded
   - No backup found
   - Decryption failure
3. Test auto-backup:
   - Daily schedule
   - Weekly schedule
   - WiFi-only constraint
   - WiFi+Mobile mode
4. Polish UI:
   - Loading states
   - Animation timing
   - Error message clarity
   - Success feedback
5. Performance testing:
   - 100 flight logs
   - 1000 flight logs
   - 5000 flight logs

**Acceptance Criteria:**
- All test scenarios pass
- Backup completes in <2 minutes for 1000 logs
- Restore completes in <1 minute
- Error messages are user-friendly
- UI feels polished

### 4.7 Phase 7: Documentation & Deployment (Day 6-7)

**Goal:** Document and deploy

**Tasks:**
1. Write user documentation:
   - How to enable backups
   - How to restore
   - Troubleshooting guide
2. Write developer documentation:
   - Architecture overview
   - Code structure
   - Testing guide
3. Update app version
4. Create release build
5. Test release build thoroughly
6. Deploy to production

**Acceptance Criteria:**
- Documentation complete
- Release build tested
- No debug code in production
- Logging disabled in release mode

---

## 5. Risk Analysis

### 5.1 Technical Risks

**Risk 1: Google Drive API Rate Limits**
- **Impact:** Backup failures if user hits rate limit
- **Mitigation:** Implement exponential backoff, queue multiple requests
- **Likelihood:** Low (AppDataFolder has generous limits)

**Risk 2: Encryption Performance**
- **Impact:** Slow backup for large databases
- **Mitigation:** Test with large datasets, optimize if needed
- **Likelihood:** Low (flight log databases are typically small)

**Risk 3: WorkManager Reliability**
- **Impact:** Auto-backups don't run as scheduled
- **Mitigation:** Implement OEM workarounds, test on multiple devices
- **Likelihood:** Medium (Chinese OEMs are aggressive with background tasks)

**Risk 4: Cross-Device Key Sync**
- **Impact:** User can't restore on new device
- **Mitigation:** Store key in cloud, test cross-device scenarios
- **Likelihood:** Low (alkhazna proves this works)

### 5.2 User Experience Risks

**Risk 1: User Doesn't Enable Auto-Backup**
- **Impact:** Data loss if phone is lost/broken
- **Mitigation:** Show reminder notifications, default to weekly
- **Likelihood:** Medium

**Risk 2: Confusing Error Messages**
- **Impact:** User gives up on backups
- **Mitigation:** User-friendly messages with clear actions
- **Likelihood:** Low (comprehensive error handling)

**Risk 3: Accidental Restore**
- **Impact:** User overwrites current data accidentally
- **Mitigation:** Require explicit confirmation, show metadata
- **Likelihood:** Low (confirmation dialog prevents this)

---

## 6. Success Metrics

### 6.1 Technical Metrics

- ✅ 0 file system errors (goal: eliminate completely)
- ✅ Backup success rate >95%
- ✅ Restore success rate >98%
- ✅ Auto-backup execution rate >90% (scheduled vs actual)
- ✅ Average backup time <2 minutes for 1000 logs
- ✅ Average restore time <1 minute

### 6.2 User Metrics

- ✅ >50% of users enable auto-backup within first week
- ✅ <5% of users report backup-related errors
- ✅ <1 support ticket per 100 users about backups
- ✅ User satisfaction score >4.5/5 for backup feature

---

## 7. Appendix

### 7.1 Key Differences: alkhazna vs FalconLog

| Aspect | alkhazna | FalconLog |
|--------|----------|-----------|
| **Database** | Hive (income/outcome entries) | Hive (flight logs) |
| **Backup File Name** | `alkhazna_backup.db.crypt14` | `falconlog_backup.db.crypt14` |
| **Key File Name** | `alkhazna_backup_keys.encrypted` | `falconlog_backup_keys.encrypted` |
| **Data Size** | Small (income/outcome records) | Small-Medium (flight logs with details) |
| **User Base** | Personal finance users | Pilots |
| **Critical Data** | Financial transactions | Flight hours, certifications |
| **Platform** | Android | Android + iOS + Desktop |

### 7.2 Google Drive AppDataFolder

**What is it?**
- Special folder in Google Drive
- Hidden from user (can't see in Drive UI)
- Automatically created per app
- Counts against user's Drive quota
- Persists even if app uninstalled
- Tied to app's package name

**Why use it?**
- ✅ No file permission issues
- ✅ Automatic cloud sync
- ✅ Hidden from user (prevents accidental deletion)
- ✅ Per-app isolation (other apps can't access)
- ✅ Works on all platforms (Android, iOS, Desktop)

**Required Scope:**
```
https://www.googleapis.com/auth/drive.appdata
```

### 7.3 AES-256-GCM Details

**Why GCM mode?**
- Provides both confidentiality and authenticity
- Detects tampering (authentication tag)
- Widely used industry standard
- Fast on modern hardware
- No padding required

**Security Properties:**
- Confidentiality: Ciphertext reveals no information about plaintext
- Authenticity: Any modification detected via MAC verification
- Associated Data: Additional context authenticated but not encrypted

**Implementation Notes:**
- Never reuse nonce with same key (we generate random nonce each time)
- Verify authentication tag before decrypting (prevents chosen-ciphertext attacks)
- Use constant-time comparison for MAC (prevents timing attacks)

### 7.4 Code Snippets

**Creating Backup:**
```dart
final backupService = BackupService();

// Listen to progress
backupService.addListener(() {
  final progress = backupService.currentProgress;
  print('${progress.percentage}% - ${progress.currentAction}');
});

// Start backup
final success = await backupService.startBackup();

if (success) {
  print('✅ Backup completed!');
} else {
  print('❌ Backup failed');
}
```

**Restoring Backup:**
```dart
final backupService = BackupService();

// Check if backup exists
final hasBackup = await backupService.hasCloudBackup();

if (hasBackup) {
  // Get backup metadata
  final metadata = await backupService.getBackupMetadata();
  print('Backup from ${metadata.createdAt} (${metadata.flightLogsCount} logs)');

  // Confirm with user, then restore
  final result = await backupService.startRestore();

  if (result.success) {
    print('✅ Restored ${result.flightLogsRestored} flight logs');
  } else {
    print('❌ Restore failed: ${result.errorMessage}');
  }
}
```

**Scheduling Auto-Backup:**
```dart
// Enable weekly auto-backup
await BackupScheduler.scheduleAutoBackup(BackupFrequency.weekly);

// Set network preference
await BackupScheduler.setNetworkPreference(NetworkPreference.wifiOnly);

// Check last backup time
final lastBackup = await BackupScheduler.getLastBackupTime();
print('Last backup: $lastBackup');
```

---

## 8. Conclusion

This PRD defines a production-ready, WhatsApp-style backup system for FalconLog based on the proven alkhazna architecture. The system eliminates all file system issues by using Google Drive's AppDataFolder directly, provides end-to-end encryption for security, and offers a polished user experience with automatic backups and single-tap restore.

**Implementation Timeline:** 6-7 days
**Complexity:** Medium (leveraging proven alkhazna code)
**Risk Level:** Low (architecture already proven in production)

**Next Steps:**
1. Review and approve this PRD
2. Remove all existing backup systems (Phase 1)
3. Begin implementation of Phase 2
4. Test thoroughly at each phase
5. Deploy to production

---

**Document Version:** 1.0
**Created:** September 30, 2025
**Author:** Claude Code
**Status:** Ready for Review
# FalconLog — Existing User Update Safety

## Summary

This update is designed to **preserve local data** during app upgrade:

- Hive **TypeIds unchanged** (0, 1, 2, 10, 100–102)
- Hive **box names unchanged** (`flightLogsBox`, `backupMetadata`, `securitySettingsBox`, etc.)
- **No plaintext ΓåÆ encrypted Hive migration** in this release (schema v1)
- Legacy backup formats remain restorable
- Corrupted Hive files are **quarantined**, not deleted

## Before you update (recommended for testers)

1. Run a **manual backup** (Google Drive or local) before installing a new APK.
2. Note whether your current APK is **debug-signed** or **release-signed** (see below).

## Android signing and in-place updates

- **applicationId** is unchanged: `com.falcon_log.falconlog`
- **In-place update** requires the **same signing certificate** as the installed APK.
- If you previously installed a **debug-signed** APK (e.g. `flutter run` / CI debug), a **release-signed** APK will **not** install over it without uninstalling first.
- **Uninstalling removes local app data** unless you have a backup.

### Safe path from debug-signed ΓåÆ release-signed

1. Create a cloud or local backup in the app.
2. Export/share backup if available.
3. Uninstall the debug build.
4. Install the release-signed build.
5. Sign in and **restore** from backup.

Release signing: copy `android/key.properties.example` ΓåÆ `android/key.properties` and add your keystore (never commit secrets).

## What changed (data-related)

| Area | Behavior |
|------|----------|
| Hive corruption | Files copied to `hive_quarantine/`; originals kept |
| Replace restore | Journal phases: rollback only if not `committed` |
| Merge restore | Snapshot + journal + rollback (same as replace) |
| Restore cancel | Allowed before apply; ignored during apply |
| Android backup | `allowBackup=false` + data extraction excludes |
| App lock | UI only; Hive files remain plaintext on disk (encryption is a separate future migration) |
| Backup retention | Latest successful backup kept after a new backup completes (PR2.2) |

## If migration fails

- App data migrations (`AppDataMigrationService`) **do not clear boxes** on failure.
- Storage schema stays at v1; app continues with existing plaintext Hive.
- Restore from backup if the app cannot open flight logs (quarantine path in logs).

## Cloud backup honesty

- Backup payloads use **AES-256-GCM**.
- The recovery key is stored in **Google Drive AppData** (not end-to-end against Google account access).
- Old key files remain readable.

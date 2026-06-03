# Copilot Instructions for FalconLog

## Project Overview
- **FalconLog** is a Flutter application with a focus on cloud backup, Google authentication, and Google Drive integration.
- The architecture centers around services for authentication (`DriveAuthService`), backup (`CloudBackupService`), and Google Drive operations (`GoogleDriveService`).
- The main workflow involves user authentication, backup creation, and uploading encrypted ZIP files to Google Drive.

## Key Workflows
- **App Startup:**
  - `DriveAuthService.init()` attempts silent sign-in.
  - Sets authentication state (`SignedIn` or `SignedOut`).
- **Manual Backup:**
  - Triggered by user action (e.g., "Backup Now").
  - `CloudBackupService.backupEncryptedZip()` coordinates backup and upload.
  - `DriveAuthService.getAuthHeaders()` handles authentication (interactive or silent).
  - `GoogleDriveService._getDriveApi()` manages Drive API access and file upload.

## Developer Workflows
- **Build:** Standard Flutter build commands (`flutter build`, `flutter run`).
- **Test:** Place tests in `test/`. Use `flutter test` to run.
- **Debug:** Use Flutter DevTools or IDE debugging tools.

## Project Conventions
- **Service Pattern:** Core logic is encapsulated in service classes under `lib/services/`.
- **Authentication:** Always use `DriveAuthService` for Google sign-in and token management.
- **Backup:** Use `CloudBackupService` for all backup/restore operations. Backups are encrypted ZIPs uploaded to Google Drive.
- **UI Triggers:** User actions (e.g., backup) are routed through service methods, not direct API calls.
- **Error Handling:** UI displays badges/messages for sign-in requirements and backup results.

## Integration Points
- **Google Drive:** All file uploads use the Google Drive API via `GoogleDriveService`.
- **Google Auth:** Managed by `DriveAuthService`.
- **Cloud Backup:** Orchestrated by `CloudBackupService`.

## References
- See `.cursor/rules/workflow.mdc` for detailed workflow diagrams and sequence charts.
- See `lib/services/` for service implementations.
- See `README.md` for general Flutter setup.

---

**Example:**
- To trigger a backup, call `CloudBackupService.backupEncryptedZip(zip, interactive: true)` from the UI layer.
- For authentication, always use `DriveAuthService.getAuthHeaders()`.

---

Update this file as workflows or architecture evolve. For more details, consult the workflow documentation and service source files.

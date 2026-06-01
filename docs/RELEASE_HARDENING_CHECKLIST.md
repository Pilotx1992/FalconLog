# Release Hardening Checklist

This checklist is limited to release safety. It does not require UI changes and does not change backup or restore data formats.

## Scope

- Android permission minimization.
- Release signing safety.
- CI checks for analysis and tests.
- Safer debug logging around Google Drive API requests.

## Local checks

Run from the project root:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

## Android release build checks

Release builds must use a real release keystore. Create `android/key.properties` from the example file and keep signing files out of Git.

```bash
flutter build apk --release
flutter build appbundle --release
```

Expected behavior: release builds fail fast if release signing is not configured.

## Backup and restore regression checks

Before publishing a release candidate, verify these flows on a physical Android device:

1. Manual Google Drive backup completes successfully.
2. Manual local backup completes successfully.
3. Cancel during Google Drive backup does not leave a new visible backup entry.
4. Merge restore succeeds from the latest Google Drive backup.
5. Replace restore succeeds and rollback protection remains available on failure.
6. Safety copy import validates and restores a known-good backup file.
7. Auto Backup remains enabled after closing and reopening the app.
8. Scheduled backup worker runs without requiring UI.

## Background backup expectations

FalconLog uses WorkManager for best-effort scheduled background backup. Android may delay work because of Doze mode, battery optimization, connectivity constraints, or force-stop behavior. This is expected platform behavior and should not be presented as exact-timing backup.

## Android permission policy

Only keep permissions required by current app behavior. Do not add broad storage, exact alarm, or foreground service permissions unless a real feature uses them and the Play Store declaration is ready.

## Git branch safety

Before final release, ensure the release branch is merged into the repository default branch or that the default branch is updated intentionally.

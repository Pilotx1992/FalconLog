# FalconLog Android Release Checklist

Use this checklist before uploading a build to **Google Play Console internal testing**.

**Do not distribute release APKs via sideload** (file share, messaging apps, etc.). Sideloaded APKs trigger Play Protect warnings and install failures when signing keys differ from an existing debug install. The supported path is **AAB → Play internal track → tester opt-in link**.

## Prerequisites

1. Copy [`android/key.properties.example`](../android/key.properties.example) to `android/key.properties` (never commit).
2. Create the Play upload keystore at `android/upload-keystore.jks` (see comments in `key.properties.example`).
3. Register upload certificate **SHA-1** and **SHA-256** in [Firebase Console](https://console.firebase.google.com) for `com.falcon_log.falconlog` (required for Google Sign-In on release builds).

## Pre-release commands

Run from the project root:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

**Expected:**

- `flutter analyze` — 0 issues
- `flutter test` — all tests pass
- AAB output: `build/app/outputs/bundle/release/app-release.aab`

## Post-build verification (optional local signing check)

Build a release APK only to verify signing locally. Upload the **AAB** to Play, not the APK.

```powershell
flutter build apk --release

$apksigner = "$env:LOCALAPPDATA\Android\sdk\build-tools\36.0.0\apksigner.bat"
& $apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk

$aapt = "$env:LOCALAPPDATA\Android\sdk\build-tools\36.0.0\aapt.exe"
& $aapt dump badging build/app/outputs/flutter-apk/app-release.apk
```

Confirm in `apksigner` output:

- `Verified using v2 scheme: true`
- `Verified using v3 scheme: true`
- Package name: `com.falcon_log.falconlog`

Confirm in `aapt dump badging`:

- `versionCode`, `versionName`, `sdkVersion` (minSdk), `targetSdkVersion`

## Play Console internal testing

1. Create the app in [Play Console](https://play.google.com/console) with package `com.falcon_log.falconlog` (if not already created).
2. Enable **Play App Signing** when prompted.
3. Upload `build/app/outputs/bundle/release/app-release.aab` to the **Internal testing** track.
4. Add tester email addresses and share the **Play Store opt-in link** (not an APK file).
5. Complete **Data safety** and **Privacy policy** before promoting beyond internal testing.

## Tester device preparation

If a tester previously installed a **debug-signed** build (`flutter run`, CI debug APK), a release build cannot install over it. Uninstall first:

```powershell
adb uninstall com.falcon_log.falconlog
```

Then install from the Play internal testing link.

See also: [`EXISTING_USER_UPDATE.md`](../EXISTING_USER_UPDATE.md) for backup-before-uninstall guidance.

## Install failure diagnostics

If installation fails on a test device, capture the exact `INSTALL_FAILED_*` reason:

```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -d | Select-String "PackageManager|INSTALL_FAILED"
```

Common causes:

| Symptom | Likely cause |
|---------|----------------|
| "App not installed" after debug build | `INSTALL_FAILED_UPDATE_INCOMPATIBLE` — uninstall debug build first |
| Play Protect "harmful app" on sideload | Expected for unknown sideloaded APKs — use Play internal track instead |
| Corrupt APK | Re-transfer AAB/APK via USB or direct download; avoid chat-app compression |

## Related checklists

- [`RELEASE_HARDENING_CHECKLIST.md`](../RELEASE_HARDENING_CHECKLIST.md) — backup/restore regression and permission policy
- [`EXISTING_USER_UPDATE.md`](../EXISTING_USER_UPDATE.md) — debug-to-release signing migration

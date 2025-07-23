# FalconLog - Production Configuration
# This file contains settings for running on real devices

## Firebase Configuration
- Project ID: falconlog-534f8
- Package Name: com.falcon_log.falconlog
- Firebase Auth: Production (no emulator)
- Firestore: Production database
- Google Drive API: Enabled (status: 403 error needs fixing)

## Android Configuration
- Min SDK: 23 (Android 6.0+)
- Target SDK: Latest Flutter SDK
- Cleartext Traffic: Disabled (production security)
- Network Security: Production settings
- Proguard: Enabled for release builds
- Signing: Debug keys (should be replaced with release keys for production)

## Google Services
- Google Sign-In: Production OAuth clients
- Google Drive API: Need to enable in Firebase Console
- Certificate Hash: 410b3b71e66173b35bc6b1cf487e1fedfa76be25

## Required Steps for Real Device:
1. Enable Google Drive API in Firebase Console
2. Add device fingerprint for Google Sign-In
3. Test on physical device with Google Play Services
4. Verify all permissions work correctly

## Build Commands:
- Debug: flutter run
- Release: flutter build apk --release
- Profile: flutter run --profile

## Testing Checklist:
□ Firebase Auth (Google Sign-In)
□ Local backup functionality  
□ Google Drive backup (after API enabled)
□ Flight log CRUD operations
□ Data persistence
□ App performance

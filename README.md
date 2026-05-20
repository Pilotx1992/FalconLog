# FalconLog

Offline-first flight log for pilots. Firebase Auth for sign-in; Hive for local flight data; optional Google Drive backup with AES-256-GCM payload encryption.

## Documentation

- [Existing user update safety](docs/EXISTING_USER_UPDATE.md) — upgrade, signing, Hive, restore, and backup honesty
- [Backup/restore verification notes](BACKUP_RESTORE_VERIFICATION.md) — technical backup/restore reference (not a production sign-off)

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

Release signing: see `android/key.properties.example` (never commit secrets).

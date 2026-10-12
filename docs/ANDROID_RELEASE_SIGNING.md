# Android release signing — owner-controlled setup

**Current status:** SOURCE PREPARATION ONLY. No signing key was generated, imported, uploaded, or verified here. The existing application ID `com.example.rokter_badhon` is a development placeholder, and real Firebase package/app identity requires **owner review**. This guide does not authorize distribution or any production change.

## Why this matters

Older `android/app/build.gradle.kts` explicitly signed `release` with the Android **debug** key. The current config refuses release signing unless a private, locally held keystore and `android/key.properties` are supplied. No debug fallback is permitted. `flutter build apk --debug` remains supported by GitHub CI.

Only sign builds after finalizing the correct **immutable Android application ID**, verifying `google-services.json` and the Firebase Android app registration, Android/Google SHA certificate fingerprints, allowed OAuth/App Check providers, and package update compatibility for installed devices. **Do not arbitrarily change the current package ID as part of a signing test.**

## Private setup (not performed)

1. Designate a signing key owner, independent backup custodian, secure key location and tested recovery route. Preserve the **original key** for future updates. Never store it in this repository, in CI artifacts, chat messages or a shared screenshot.
2. Create or import the owner-controlled upload key with a trusted local `keytool` process. Save the key under `android/upload-key.jks` (ignored by Git), or use another secure absolute/relative path accessible on the build machine.
3. Create `android/key.properties` **locally only**, containing these properties:

```properties
storeFile=upload-key.jks
storePassword=YOUR_PRIVATE_STORE_PASSWORD
keyAlias=YOUR_PRIVATE_ALIAS
keyPassword=YOUR_PRIVATE_KEY_PASSWORD
```

This is an **example template only**, not a real credential. `storeFile` is resolved relative to the `android/` Gradle project directory. The private `key.properties` and `.jks` files are ignored by Git; do not override that exclusion.

4. Verify the Android application ID and associated Firebase files/fingerprints and app attestation before building. For the moment, `com.example.rokter_badhon` is **unapproved for production distribution**.
5. After completing the owner-controlled production gates, run locally:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

6. Verify the **actual signed artifacts** using local Android SDK Build Tools and record their SHA-256 hashes:

```powershell
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256
Get-FileHash build/app/outputs/bundle/release/app-release.aab -Algorithm SHA256
```

Run install, existing-install update compatibility, offline/restart and role-scoped end-to-end acceptance on a real Android device; see `docs/STAGE9_ANDROID_ACCEPTANCE_MATRIX.md`. A successful unsigned/debug build is not a signed release acceptance.

## Fail-closed behavior

- `flutter build apk --release` / `flutter build appbundle --release` with missing/incomplete `key.properties` fails rather than falling back to debug signing.
- Invalid or missing `storeFile` fails with a generic message; passwords are not printed. Local signing files are **never placed in GitHub Actions** by this change.
- The production Android manifest explicitly requests Internet access for Firebase. The HTTP cleartext allowance is **debug manifest only** for local emulators.
- No production Firebase data, Security Rules, indexes, committee roster, user login, or signing credentials are changed by these source edits.

## Outstanding owner release gates

**NO-GO** until production app identity, Firebase project match, permission/App Check checks, Android key custody, fully reconciled donor phone registry/backfill, rules/index deployment, verified production-safe accounts, real-device test evidence, privacy/backup approvals and signed artifact verification have been completed. No automated CI result can substitute for them.

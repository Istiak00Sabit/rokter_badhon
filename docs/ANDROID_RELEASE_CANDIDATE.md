# Stage 10 Batch 2 — Android release-candidate verification

**Status: NO-GO for production distribution.** This batch audits source consistency and the **debug APK built by CI**, not a signed release APK/AAB and not a physical-device acceptance result.

## Automated source preflight

Run from the repository root:

```powershell
node tools/release/verify_candidate.mjs --source-only --out release-preflight.json
```

The checker fails closed when the Android application ID differs from the registered Android client in `android/app/google-services.json`, the Flutter Android Firebase app ID/project number disagrees with that registration, the Kotlin MainActivity package differs from the Gradle namespace, production Internet permission is missing, cleartext HTTP is enabled in the main manifest, private signing guards are absent, or signing key files are not ignored.

An intact source audit **always reports `releaseApproval: "NO_GO"` and `productionReady: false`** because it cannot prove owner approval, production deployment, signing-key custody or real-device acceptance. The current `com.example.rokter_badhon` is a development application ID; matching Firebase configuration does **not** make it approved for distribution. The final application ID and corresponding Firebase Android app registration must be owner-approved together.

## Built debug APK preflight

After a successful local `flutter build apk --debug` with an installed Android SDK build-tools:

```powershell
node tools/release/verify_candidate.mjs --apk build/app/outputs/flutter-apk/app-debug.apk --out release-preflight.json
```

The checker uses installed Android build-tools `aapt` and `apksigner` to verify the actual debug APK's package identity, Internet permission, APK signature, size and SHA-256. It checks for missing Android SDK tooling rather than silently skipping verification. The report is machine-readable and deliberately contains no secret signing properties, Firebase API keys, raw donor information, user IDs or private application data.

GitHub Actions `Flutter checks` runs the source preflight before Flutter Analyze, builds a **Firebase-emulator-configured** debug APK, and runs the binary preflight. A successful run uploads both `app-debug.apk` and `release-preflight.json` as one short-retention artifact. Always verify the run's commit SHA and inspect the downloaded report before installation.

**This artifact is debug-only.** It cannot be accepted as a release APK and should never be publicly distributed as the organization's production client.

## Stage 10 Batch 3 — safe emulator-only CI artifact and cloud launch smoke

GitHub Actions now explicitly builds its installable debug APK with
`--dart-define=USE_FIREBASE_EMULATOR=true` and
`--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1`.
The artifact is named **`rokter-badhon-emulator-debug-apk`** so it cannot
be confused with a production Firebase build. The `release-preflight.json`
report includes a declared emulator target plus the exact Git SHA and GitHub
Actions run ID, the built APK SHA-256, package ID and signature check.
The mode declaration follows reviewed CI build flags; binary inspection by
itself does **not** recover Dart compile-time defines from the APK.

A separate GitHub Actions `android-smoke` job downloads that same artifact,
boots an Android 14 cloud emulator, installs the APK, launches the Flutter
activity and checks that the app process survives an initial launch and restart
without an AndroidRuntime fatal exception. The Firebase emulators are **not**
started by this smoke job; network/database, UI navigation and credentials
are **not tested** by this basic runtime check. It intentionally never contacts
real Firebase for user operations.

Use the same-run report and the smoke job result when recording the tested
build. The smoke job passing does **not** validate Registration, Login,
Donor Approval, committee screens, or real hardware: those remain explicitly
UNTESTED in the physical-device acceptance matrix.

## Stage 10 Batch 4 — isolated cloud Firebase login UI acceptance

The Android 14 CI emulator now also runs local Firebase Auth and Firestore
emulators under **`demo-rokter-badhon`**, seeds its synthetic developer-admin
AuthLink/User and an empty donor phone registry, and checks the registry
integrity before launching. Local emulator endpoints and guarded seeding must
be available; missing ports, a populated donor history, or a non-demo target
stop the test instead of switching to production.

The `android-smoke` job now separately exercises accessibility-visible login
fields, Bengali-to-English language switch, the public synthetic demo account
login through real local Auth/Firestore emulators, and a navigation check to
the Current committee screen. It prints no credentials, donor IDs, screenshots
or application content to CI output. This is a **targeted Android-cloud test**,
not a test of real production Firebase, completed donor approval, all
registration workflows or physical hardware.

Only mark these cloud checks passed after the **latest commit's** GitHub CI
run succeeds, including the actual Android UI script. All physical-device
acceptance cases in `STAGE9_ANDROID_ACCEPTANCE_MATRIX.md` remain untested.

## Release owner gates (all still required)

- Finalize and approve application ID, Android namespace where needed, Firebase registration, app fingerprints, app-attestation and expected update path before any package rename.
- Complete historical donor-phone key backfill, reconcile all old data and verify the real deployed Rules/indexes. Production registry must not be enabled without the reviewed migration evidence.
- Use `docs/ANDROID_RELEASE_SIGNING.md` with private, owner-held signing key and a supported release APK/AAB build. Verify the **release artifact** with `apksigner` and a separate SHA-256. Do not reuse the GitHub debug certificate.
- Perform every physical-phone scenario in `docs/STAGE9_ANDROID_ACCEPTANCE_MATRIX.md`; record redacted results, including denied access, unreliable connectivity, registration/approval and data integrity.
- Approve backup/recovery, privacy, production operator identities and required rollback. No automatic production migration or live deployment occurs in this batch.

A passing source check and debug APK inspection are meaningful **code/build verification only**. Every remaining owner/device/production gate stays open and the release decision stays **NO-GO**.

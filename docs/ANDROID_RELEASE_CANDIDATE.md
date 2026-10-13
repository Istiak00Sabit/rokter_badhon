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

GitHub Actions `Flutter checks` runs the source preflight before Flutter Analyze, and after building the debug APK runs the binary preflight. A successful run uploads both `app-debug.apk` and `release-preflight.json` as one short-retention artifact. Always verify the run's commit SHA and inspect the downloaded report before any installation.

**This artifact is debug-only.** It cannot be accepted as a release APK and should never be publicly distributed as the organization's production client.

## Release owner gates (all still required)

- Finalize and approve application ID, Android namespace where needed, Firebase registration, app fingerprints, app-attestation and expected update path before any package rename.
- Complete historical donor-phone key backfill, reconcile all old data and verify the real deployed Rules/indexes. Production registry must not be enabled without the reviewed migration evidence.
- Use `docs/ANDROID_RELEASE_SIGNING.md` with private, owner-held signing key and a supported release APK/AAB build. Verify the **release artifact** with `apksigner` and a separate SHA-256. Do not reuse the GitHub debug certificate.
- Perform every physical-phone scenario in `docs/STAGE9_ANDROID_ACCEPTANCE_MATRIX.md`; record redacted results, including denied access, unreliable connectivity, registration/approval and data integrity.
- Approve backup/recovery, privacy, production operator identities and required rollback. No automatic production migration or live deployment occurs in this batch.

A passing source check and debug APK inspection are meaningful **code/build verification only**. Every remaining owner/device/production gate stays open and the release decision stays **NO-GO**.

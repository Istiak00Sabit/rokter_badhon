# Local Firebase manual testing

This workflow is development-only. It uses the Firebase demo project ID and both local emulators. The operator guard refuses non-demo projects and refuses to run unless both emulator host variables are present.

The fixed credentials below are intentionally public local-test credentials. Never reuse this password for a real account.

- Phone: `01000000000`
- Password: `123456`
- Auth state: enabled; email verification is not used
- Application state: `developer_admin`, `active = true`, `login_enabled = true`

From `C:\rokter_badhon`, use three PowerShell terminals.

## Terminal 1 — emulators

```powershell
$env:PATH = 'C:\Program Files\Java\jdk-21\bin;' + $env:PATH
npx firebase-tools emulators:start --config firebase.emulator.json --project demo-rokter-badhon --only auth,firestore
```

## Terminal 2 — repeatable test data seed

Run after Terminal 1 reports that all emulators are ready.

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
node tools/operator/cli.js seed-test-admin --project-id demo-rokter-badhon
node tools/operator/cli.js seed-official-committee --project-id demo-rokter-badhon
```

## Terminal 3 — Flutter on an Android emulator

The Android emulator reaches the development machine at `10.0.2.2`, which is the development-mode default.

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

For a physical Android phone connected through USB debugging, use the build/install helper below. The install step can clear existing `adb reverse` rules, so the helper applies the routes only after the APK is installed:

```powershell
adb devices
.\tools\run_local_phone.ps1 -DeviceId <adb-device-id>
```

The helper builds with `USE_FIREBASE_EMULATOR=true` and `FIREBASE_EMULATOR_HOST=127.0.0.1`, installs the debug APK, then applies:

```powershell
adb -s <adb-device-id> reverse tcp:9099 tcp:9099
adb -s <adb-device-id> reverse tcp:8080 tcp:8080
```

The Flutter runtime keeps `127.0.0.1` as the documented value and maps it internally to `0.0.0.0` on Android. This avoids Android's automatic `127.0.0.1` → `10.0.2.2` emulator mapping while the USB reverse routes still target the host machine. Do not use the production `flutter run` command for this local account.

With `USE_FIREBASE_EMULATOR` absent or false, the app keeps its existing normal Firebase configuration. Emulator mode changes only Firebase endpoints; it does not bypass AuthLink resolution, User state, login enablement, role recognition, or Firestore Rules. The app login field remains Phone Number + Password in both modes.

The test password is six characters and is passed unchanged to the Auth emulator. No credential adapter or production bypass exists. The committee preload creates exactly 51 organization Users and 51 current assignments, but creates no Firebase Auth accounts for committee members. To test complete committee provisioning locally, use `provision-committee-accounts` with the same emulator variables; generated credentials go only to the ignored `tools/operator/.local/` directory. Both seed commands are idempotent and refuse non-demo targets; the CLI also refuses to initialize unless both emulator host variables are set.

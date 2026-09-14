# Local Firebase manual testing

This workflow is development-only. It uses the Firebase demo project ID and both local emulators. The operator guard refuses non-demo projects and refuses to run unless both emulator host variables are present.

The fixed credentials below are intentionally public local-test credentials. Never reuse this password for a real account.

- Email: `a@a.com`
- Password: `123456`
- Auth state: enabled and email-verified
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

For a physical Android phone connected through USB debugging, reverse both emulator ports and use loopback:

```powershell
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

With `USE_FIREBASE_EMULATOR` absent or false, the app keeps its existing normal Firebase configuration. Emulator mode changes only Firebase endpoints; it does not bypass email verification, AuthLink resolution, User state, login enablement, role recognition, or Firestore Rules.

The test password is six characters and is passed unchanged to the Auth emulator. No credential adapter or production bypass exists. The committee preload creates exactly 51 organization Users and 51 current assignments, but creates no Firebase Auth accounts for committee members. Both seed commands are idempotent and refuse non-demo targets; the CLI also refuses to initialize unless both emulator host variables are set.

# Physical-phone testing

This project has two intentionally separate Firebase targets. A normal build
uses the real project configured in `lib/firebase_options.dart`. Emulator mode
is opt-in at compile time and never changes the production default.

## Real Firebase (production)

Run the normal command with no emulator defines:

```powershell
adb devices
flutter run -d <adb-device-id>
```

The Android login screen accepts only Phone Number and Password. Flutter
normalizes the phone and derives the reserved internal Firebase Auth identity
before password sign-in. Admission then requires an active
`auth_links/{firebaseAuthUid}`, an active User, `login_enabled == true`, and a
recognized `users.access_role`. Firebase `emailVerified` is not checked. A
real profile email is optional information and is not a login credential.

Production mutation remains trusted-operator-only. Do not use the Flutter app
or direct Firestore Console writes to manufacture a profile or auth link.
Generated committee passwords are written once to the ignored local
`tools/operator/.local/` file by the provisioning command; distribute them
securely and delete that file after handoff.

## Local Firebase Emulator (physical Android phone)

Terminal 1 — start both emulators:

```powershell
$env:PATH = 'C:\Program Files\Java\jdk-21\bin;' + $env:PATH
npx firebase-tools emulators:start --config firebase.emulator.json --project demo-rokter-badhon --only auth,firestore
```

After Terminal 1 reports that both emulators are ready, run this from the
repository root in Terminal 2:

```powershell
adb devices
.\tools\run_local_phone.ps1 -DeviceId <adb-device-id>
```

The helper seeds the local test administrator, builds and installs the debug
APK with these defines, applies the USB routes after installation, and launches
the app:

```text
--dart-define=USE_FIREBASE_EMULATOR=true
--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
adb -s <adb-device-id> reverse tcp:9099 tcp:9099
adb -s <adb-device-id> reverse tcp:8080 tcp:8080
```

On Android, the runtime maps the documented `127.0.0.1` value to `0.0.0.0` so
Firebase's Android loopback rewrite does not turn a physical phone into the
unreachable `10.0.2.2` address. Cleartext HTTP is permitted in the debug
manifest only for these local emulators; production builds retain the normal
Android default.

The local-only credentials are:

```text
Phone:    01000000000
Password: 123456
```

They exist only in the `demo-rokterbadhon` Auth emulator. The local seed gives
this account the explicit `developer_admin` application role; it is not a
production identity and is not a committee-member Auth account.

Optional local committee preload (creates strict Users and assignments but no
Auth identities):

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
node tools/operator/cli.js seed-official-committee --project-id demo-rokterbadhon
```

To exercise the complete committee Auth provisioning flow locally instead,
use `provision-committee-accounts` with the same emulator variables and the
demo project. The generated credentials are written to the ignored
`tools/operator/.local/` directory.

Do not run a second emulator process on the same ports. If the phone is
unplugged, rerun the two `adb reverse` commands after reconnecting it.

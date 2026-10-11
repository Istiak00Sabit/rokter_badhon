# Physical-phone testing

This project has two intentionally separate Firebase targets. A normal build
uses the real project configured in `lib/firebase_options.dart`. Emulator mode
is opt-in at compile time and never changes the production default.

## Install the automated test APK

Open the latest successful GitHub Actions **Flutter checks** run on the
repository. Under **Artifacts**, download `rokter-badhon-debug-apk`,
extract the ZIP and install `app-debug.apk` on an Android phone
(only install builds from your own trusted repository). This is a debug
build for testing and is **not** a signed production release.

**Do not use the normal CI APK to mutate real Firebase during acceptance
testing without explicit owner approval.** That APK targets the configured
real Firebase project, not the local emulators. Use the emulator-configured
physical-phone helper below for development tests.

In the emulator, test Registration → Pending → trusted operator approval →
Phone + Password Login. A pending or rejected applicant must not reach
protected screens; an approved applicant without a valid AuthLink must also
be denied. Separately test donor submission, leader approval/rejection,
active-donor visibility, and Bengali/English locality selectors.

Committee display is **read-only in Flutter**: confirm the unsynced bundled
51-person preview when no current Firestore term exists. After a separate
emulator-only committee seed, confirm the live 51-person roster with exactly
2 leaders, 31 executives and 18 committee members. In-app Committee Add
is intentionally unavailable; member changes require the trusted operator
and must never be simulated with client Firestore writes.

For existing real users, test approved logins **without deleting or
recreating their accounts**. Older email-based identities may require
an operator-reviewed migration. Do not attempt to bypass the admission
rules by writing User/AuthLink documents manually.

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

They exist only in the `demo-rokter-badhon` Auth emulator. The local seed gives
this account the explicit `developer_admin` application role; it is not a
production identity and is not a committee-member Auth account.

Optional local committee preload (creates strict Users and assignments but no
Auth identities):

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
node tools/operator/cli.js seed-official-committee --project-id demo-rokter-badhon
```

To exercise the complete committee Auth provisioning flow locally instead,
use `provision-committee-accounts` with the same emulator variables and the
demo project. The generated credentials are written to the ignored
`tools/operator/.local/` directory.

Do not run a second emulator process on the same ports. If the phone is
unplugged, rerun the two `adb reverse` commands after reconnecting it.


## Stage 9 Batch 8 — local phone registry prerequisites

The approved local phone helper now runs `seed-empty-demo-donor-registry`
after `seed-test-admin`. It operates **only** on project
`demo-rokter-badhon` with both Auth and Firestore emulators running.

The fixture enables `system_config/donor_phone_registry` only when the
local donor collection and phone-key collection are BOTH empty, or returns
success if an already-ready **empty** fixture matches the schema. Any
historical donor, stray phone-key document, unknown registry schema or
incomplete scan stops the helper with an error. **No data is migrated or
deleted.** Never point this command at real Firebase.

Manual equivalent for a NEW/EMPTY local emulator:

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
node tools/operator/cli.js seed-empty-demo-donor-registry --project-id demo-rokter-badhon
```

To inspect local registry completeness *without writing*:

```powershell
node tools/operator/cli.js audit-donor-registry --project-id demo-rokter-badhon
```

This reports only counts, flags and issue counts, never donor IDs/phone numbers.
It exits with code 2 if reservation integrity/registry readiness is incomplete.
For existing emulator histories it is normal for the result to be blocked until
a separately reviewed migration; do not delete/reseed data just to get a green
result. After the local fixture, use a fresh synthetic donor submission and
verify approval by a leader, duplicate phone rejection for a second submission,
and the original donor remains visible without duplicate active records.
Once a donor exists, rerunning `seed-empty-demo-donor-registry` intentionally
refuses to auto-activate anything.

Automated emulator CI is not a physical-device acceptance result. Record
device/Android version, commit, build source, tests, outcome and redacted
failure details in the acceptance matrix, and keep all production changes
blocked pending separate owner approval.

## Stage 9 physical-phone acceptance notes

Keep a local, redacted record of device/Android version, exact Git commit and
APK origin, each test performed and its pass/fail result. Never include real
member phones, credentials, applicant IDs or patient details in shared logs.

Before declaring Stage 9 complete, verify on an actual Android device:
- Emulator-only registration, pending/rejected access denial, approved login,
  logout and blocked disabled-user reentry.
- Committee preview versus seeded live roster and past-term presentation
  without any direct Add Member action in the mobile client.
- Pending donor never appearing in active search; leader approval and rejection
  with repeat-tap protection and clear failure states.
- Emergency blood request submission (including failed network and duplicate
  tap), role-scoped donation history, ranking, notices and events.
- Bangla/English switching, Ghatail union/village choices, network loss,
  recovery/retry and application restart.

An automated CI pass and a compiled APK do **not** confirm these device tests.
Real Firebase acceptance, deployed Rules review and the official production
committee import remain separate owner-controlled gates.

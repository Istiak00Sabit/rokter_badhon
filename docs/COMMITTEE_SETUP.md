# Committee setup: reviewed 2025–2027 roster

The source of truth for the initial 51-member list is `data/committee_2025_2027.json`.
The same reviewed JSON is bundled at `assets/data/committee_2025_2027.json`
for a **read-only preview** in the app before live Firebase import.
The reviewed list contains 2 leaders, 31 executives, and 18 committee
members. No committee account is created simply by opening the app.

## Import the initial 51 people into Firebase

Import **only after reviewing a backup and confirming the intended Firebase
project**. On the computer where the operator CLI runs, set up Firebase Admin
SDK Application Default Credentials securely; do not commit credentials.
Ensure the Auth and Firestore emulator host variables are unset.

From the repository root:

```powershell
npm --prefix tools/operator install
node tools/operator/cli.js seed-official-committee --project-id rokterbadhon-b247b --allow-production true --confirm-project-id rokterbadhon-b247b
```

This explicit production operation creates the active 2025–2027 term and
51 strict `users`, `user_directory`, and `committee_assignments` records.
It does **not** create Firebase Authentication identities and sets
`login_enabled: false` for the newly imported committee members.
Existing matching records can be reused. Conflicts are rejected rather
than overwritten. Re-running an exact successful import is idempotent.

Without the import, the app labels the bundled list as an unsynced preview.
Once the active term exists in Firestore, the UI reads the live server roster.

## Add further members

A user logged in with `developer_admin` can open **Committee →
Add committee member** and enter a name, phone, position, blood group and
profession. This flow creates a directory-only record (if no User exists) and
a committee assignment in a Firestore transaction. It does not generate a
password, change an existing User's role, or grant login.

The service refuses duplicates for the same User and committee term.
The app's UI role check is not an authorization boundary: the currently
deployed Firestore rules must authorize this user through a valid
`auth_links` record and an active `developer_admin` profile.
The initial 51-person import must be completed before adding new members.

Account authorization changes, future committee terms, and audit policy
should be handled with the trusted operator workflow.

## Address dropdowns

The existing 14 union IDs, Ghatail municipality ID, 411 villages and
14 municipality localities remain exactly as supplied in the locality JSON.
The app sorts displayed unions/municipality and their localities.
English mode offers display-only English transliterations of union and
municipality names, sorted A-Z, while database values stay in Bangla.
No verified English names were supplied for villages/mahallas, so they
remain in their original Bangla spelling and sorted accordingly.

## Developer verification

```powershell
flutter pub get
flutter analyze
flutter test
npm --prefix tools/operator test
```

These checks should be run before installing a new APK. The JSON preview
and the production import are separate from the donor and registration
permission-denied issues and do not by themselves resolve those errors.

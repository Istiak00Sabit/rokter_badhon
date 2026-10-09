# Committee setup: reviewed 2025–2027 roster

The source of truth for the initial 51-member list is `data/committee_2025_2027.json`.
The same reviewed JSON is bundled at `assets/data/committee_2025_2027.json`
for a **read-only preview** in the app before live Firebase import.
The reviewed list contains 2 leaders, 31 executives, and 18 committee
members. No committee account is created simply by opening the app.

## Read-only production preflight (run first)

The GitHub source and emulator tests cannot confirm deployed production data,
rules, indexes or old accounts. Before importing real people, make an
authorized Firestore backup and use read-only Firebase Admin credentials.
Keep credentials off GitHub and never paste them into chat.

Install Node.js 24 and the operator dependencies. Run this command from the
repository root on a trusted machine:

```powershell
npm --prefix tools/operator ci
node tools/operator/production_preflight.js --project-id rokterbadhon-b247b --confirm-project-id rokterbadhon-b247b --pending-limit 100 --auth-scan-limit 1000
```

This command makes **zero changes**. It produces a redacted count report:
committee Users/directory/assignments/audits already present, collisions,
pending registrations with old email-based Auth, and (within the selected
scan limit) unlinked historical accounts. It never prints member names,
phone numbers, user emails, passwords or authentication UIDs.

### If the preflight reports auth/internal-error

Firebase's Admin Authentication API may reject default end-user credentials
created with plain `gcloud auth application-default login` (the Google
Cloud SDK OAuth client). This is distinct from Firestore IAM.

Start with a **Firestore-only** investigation (no Firebase Authentication API
calls and absolutely no writes):

```powershell
git pull origin main
node tools/operator/production_preflight.js --project-id rokterbadhon-b247b --confirm-project-id rokterbadhon-b247b --pending-limit 100 --auth-scan-limit 0 --firestore-only true
```

This intentionally reports `authLookupsComplete: false`,
`safeToConsiderImport: false` and `requiresOwnerReview: true`.
That is expected, not an import approval. It can still reveal existing
committee Users, assignments, duplicate phones and pending-request counts.
On failures the tool prints the read-only **stage** and sanitized code only,
never the backend response body or member data.

For a full Authentication read, use an **already approved, minimally
privileged service account** that can read the necessary Firebase Auth and
Firestore data. Node.js ADC supports service-account impersonation:

```powershell
gcloud auth login
gcloud auth application-default login --impersonate-service-account=SERVICE_ACCOUNT_EMAIL
node tools/operator/production_preflight.js --project-id rokterbadhon-b247b --confirm-project-id rokterbadhon-b247b --pending-limit 100 --auth-scan-limit 1000
```

The human operator must have Service Account Token Creator permission on
that service account. Replace the placeholder with the email obtained from
the authorized Cloud project owner; do not paste service-account key files,
OAuth client secrets or refresh tokens into issues or chat.

An alternative supported by Firebase is `gcloud auth application-default login --client-id-file=...` using **your own Desktop OAuth client**, not the
default Cloud SDK client. Do not create new privileged service accounts or
deploy new IAM permissions without the owner reviewing the access needs.

A nonzero `requiresOwnerReview` or any import blocker requires review,
not an override. `auth-scan-limit 0` skips the optional Auth scan.
A successful preflight does not reserve records against concurrent changes;
the import itself repeats its transactional conflict checks.

The tool **does not** verify live Rules or indexes. With the authorized owner
account, inspect Firebase Console → Firestore Database → Rules and Indexes.
Compare the deployed Rules with `firestore.rules` and the composite
indexes with `firestore.indexes.json`. Capture release timestamps and
review differences before making any deployment. Emulator test success is
not evidence that these files are already deployed.

Legacy email-based Firebase Auth accounts must be reviewed by an operator;
do not delete them, overwrite their identifiers or manufacture a new User
to bypass the mismatch.

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

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

## Free-plan encrypted local Firestore backup (before any production import)

This is a **best-effort logical export of Firestore documents**, NOT the Google
Cloud managed backup/export service and NOT a single point-in-time snapshot.
It does **not** require enabling project billing, but still uses Firestore read
operations and is subject to free-tier read quotas. Run when the app is quiet,
preferably without concurrent writes, as changes during the export can produce
an inconsistent view. The script never requests Firestore mutations.

The operator CLI uses existing **read-only impersonated ADC credentials**.
It discovers every root collection, each nested subcollection, and missing
parent documents by calling Firestore REST read-only list endpoints with
pagination. The archive stores raw typed Firestore REST fields, including
integer strings, timestamps, byte strings, geo-points, references, arrays
and maps, without converting through JavaScript numbers.

From an interactive PowerShell terminal in the repository root:

    git status
    git pull --ff-only origin main
    npm --prefix tools/operator ci
    gcloud auth application-default print-access-token 1>$null
    Write-Host "ADC Status: $LASTEXITCODE"
    node tools/operator/local_firestore_backup.js --project-id rokterbadhon-b247b --confirm-project-id rokterbadhon-b247b --run true

The token command must show **ADC Status: 0**. Do not print access tokens
or paste them into chat. On backup start, the tool asks for a **16+ character
passphrase twice**, with hidden typing. Keep it offline: it cannot be
recovered. It uses scrypt and AES-256-GCM, encrypts all document data
**before** writing it to disk, and then verifies the archive (authentication
tag, record hash, counts and project ID). It writes the backup only under the
Git-ignored directory:

    tools/operator/.local/backups/firestore-rokterbadhon-b247b-<timestamp>.rbfsenc

The backup contains personal information. Never commit or upload the file,
put it in a public cloud link, or share the passphrase. Copy it to a second
encrypted drive only after it reports "verified": true. Verification can
be repeated locally with the backup **filename only**:

    node tools/operator/local_firestore_backup.js --project-id rokterbadhon-b247b --confirm-project-id rokterbadhon-b247b --verify firestore-rokterbadhon-b247b-YYYYMMDDTHHMMSSSZ.rbfsenc

Replace the sample filename with the actual filename printed after
the successful backup. The backup tool reads **only** Firestore documents.
It does **not** back up Firebase Authentication user accounts/passwords,
Cloud Storage objects, IAM policies, deployed Firestore Rules or indexes,
or hosted configuration. Retain the repository Rules/Indexes separately
and review deployed versions in Firebase Console.

**Restoration limitation:** this encrypted format is export/verification
only. No automatic production restore is provided. It preserves Firestore
document paths and typed values for a future *reviewed* restore utility.
Do not point any ad hoc restore script at production without testing it on
an isolated Firebase project first. Successful verification demonstrates
local archive integrity, not that real-world restoration has been tested.

Next gates before importing official committee members:

1. Identify the one legacy email-based Auth identity that has neither
   auth_links nor registration_requests. Do not delete it.
2. Review the live Firestore Rules and indexes in Firebase Console against
   firestore.rules and firestore.indexes.json (the preflight does not check them).
3. Complete the local backup and offline verification and secure a copy.
4. Use a **separate reviewed write-authorized operator identity**, not
   the read-only preflight account, for the one-time committee import.

## Import the initial 51 people into Firebase

Import **only after reviewing a backup and confirming the intended Firebase
project**. On the computer where the operator CLI runs, set up Firebase Admin
SDK Application Default Credentials securely; do not commit credentials.
Ensure the Auth and Firestore emulator host variables are unset.

From the repository root:

```powershell
npm --prefix tools/operator install
node tools/operator/cli.js seed-official-committee --project-id rokterbadhon-b247b --allow-production true --confirm-project-id rokterbadhon-b247b --confirm-command seed-official-committee --confirm-roster 51:2:31:18 --confirm-leaders 001,009 --acknowledge-no-login true --reason "Organization owner approved this exact 51-person directory-only import"
```

The CLI now requires **separate, explicit confirmations** of the exact
command, 51 total people, 2/31/18 role split, leader serials 001 and 009,
and the fact that no login access is being granted. It also requires a
meaningful audit reason before initializing Firebase. These checks supplement,
but never replace, project-owner authorization, credentials and transactional
conflict detection. **Never run the example command without the owner's
specific approval and verified credentials.**

This explicit production operation creates the active 2025–2027 term and
51 strict `users`, `user_directory`, and `committee_assignments` records.
It does **not** create Firebase Authentication identities and sets
`login_enabled: false` for the newly imported committee members.
Existing matching records can be reused. Conflicts are rejected rather
than overwritten. Re-running an exact successful import is idempotent.

Without the import, the app labels the bundled list as an unsynced preview.
Once the active term exists in Firestore, the UI reads the live server roster.

## Add or change committee members after the first import

The mobile app currently displays the roster **read-only**. It does **not**
show a working `Add committee member` or `Change member role` button:
Firestore Rules deliberately reject direct client changes to `users`,
`user_directory` and `committee_assignments`. A legacy internal
`AddCommitteeMemberScreen` and its client-side service still exist in the
repository but are **not a supported production workflow**.

Approved future member additions, assignment endings and role updates
must instead be performed by a separately authorized trusted operator,
with explicit identity/term checks and an audit trail. New User records,
if appropriate, must not automatically grant Firebase Auth accounts,
passwords or login access.

The initial 51 members, their two confirmed leaders and the approved
2025–2027 term must not be changed during this stage. A reviewed amendment
to the official roster is a separate owner decision; it is not the same as
opening the app or viewing the bundled preview.

If no active Firestore term exists the app shows the **unsynced 51-person
bundled preview**. If an active term already exists, even without any
assignments, its **live data** is authoritative: missing members are
not silently fabricated from the local JSON. Such gaps need operator review.

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

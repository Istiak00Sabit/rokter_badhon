# Live Firestore Rules and indexes: owner read-only verification

Target project: `rokterbadhon-b247b`. The initial live data/Auth preflight
identified 51 planned committee members with no detected import collisions, but
one legacy email-based Firebase Auth account lacked both `auth_links` and a
`registration_requests` record. That legacy identity is **not** deleted or
modified by this process.

## Production changes are not authorized by running this audit

The user has declined a Firestore backup. This is an informed operational
choice, **not** evidence that a future production import is risk free.
Preserve existing records. Do not deploy security rules or seed the committee
until this report is reviewed and a separate explicit production-write decision
has been made.

Use Windows VS Code PowerShell in the repo root:

```powershell
cd C:\rokter_badhon
git status
git pull --ff-only origin main
gcloud auth list
node tools/operator/live_rules_audit.js --project-id rokterbadhon-b247b --confirm-project-id rokterbadhon-b247b
```

If `git status` has local modifications, stop and protect them before pulling.
Log into the owner Google Cloud CLI account with `gcloud auth login` if needed.
No need to change ADC settings or use the Read-only Service Account here.

The audit invokes `gcloud auth print-access-token` internally and keeps the
short-lived token in process memory; it never logs the token or writes a file.
Only read operations are performed:

- **HTTP GET** to `firebaserules.googleapis.com` retrieves the published
  `cloud.firestore` release and linked ruleset.
- The official `gcloud firestore indexes composite list --project=rokterbadhon-b247b --format=json --quiet`
  command lists all composite indexes from the `(default)` database.
  This replaces the earlier hand-built `collectionGroups/-/indexes` REST
  request, which returned HTTP 400 in this project. Google Cloud CLI handles
  the Firestore Admin API endpoint, pagination and output. No index is created
  or deleted.

It reads only local `firestore.rules` and `firestore.indexes.json`. No
Firebase Authentication user data or Firestore documents are accessed by this
audit. No backup is created.

Expected report flags:

- `firestoreRules.verified`: the deployed Rules source was read.
- `firestoreRules.exactContentMatch`: normalized live and local text equal.
- `compositeIndexes.verified`: live composite list was read.
- `compositeIndexes.exactCompositeMatch`: no missing, not-ready or extra
  composite indexes. The system-added `__name__` field is ignored.
- `compositeIndexes.fieldOverridesVerified`: **false**, because this tool does
  not inspect Firestore single-field index exemptions/TTL/field overrides.
- `writesPerformed`: always 0. A failure returns exit code 2 but prints JSON.

If composite index verification previously failed with `HTTP 400`, first
`git pull --ff-only origin main` to get the official CLI-based fix, then rerun
the audit. If the listing still fails, run the **read-only** diagnostic
`gcloud firestore indexes composite list --project=rokterbadhon-b247b --format=json --quiet`
locally, but do not paste entire index metadata or any credentials into a
public issue.

For Google Cloud CLI user credentials, the read-only Rules API request now
includes the project-specific `X-Goog-User-Project: rokterbadhon-b247b`
quota-consumer header. Without it, Google may report `SERVICE_DISABLED` for
a different consumer project. This does not enable an API or billing.

If `firestoreRules.verified=false` with `HTTP 403`, the owner CLI account
may lack a Firebase Rules read permission, the active CLI account may not be
the owner, or the Firebase Rules API may be unavailable/disabled for the
project. The script safely prints allowlisted Google statuses/reasons when
provided (e.g., `SERVICE_DISABLED`, `IAM_PERMISSION_DENIED` or
`ACCESS_TOKEN_SCOPE_INSUFFICIENT`), never the full response body.

Use these read-only checks before any IAM/API configuration changes:

```powershell
gcloud auth list --filter="status:ACTIVE" --format="value(account)"
gcloud services list --enabled --project=rokterbadhon-b247b --filter="config.name:firebaserules.googleapis.com" --format="value(config.name)"
```

The first must be the intended account with authorization. The second should
print `firebaserules.googleapis.com` if enabled. Empty output means it is
not in the enabled-services listing or your service-list access is limited;
check the command's errors and Firebase Console before taking action.

Firebase Rules GET access needs `firebaserules.releases.get` and
`firebaserules.rulesets.get`. The specific
`roles/firebaserules.viewer` role grants these reads, but do **not**
grant new roles blindly—project Owners often already have access.
Do not enable APIs or modify IAM without reviewing the actual reason.
 If either exact match is false, share only the redacted JSON report,
not OAuth credentials or entire production data.

Even if both matches are true, this does not prove the app can register and
approve users on real devices. Current deployed configuration, the old Auth
identity and real Android acceptance tests are separate launch gates.

Official API reference:
- https://firebase.google.com/docs/reference/rules/rest/v1/projects.releases/get
- https://firebase.google.com/docs/reference/rules/rest/v1/projects.rulesets/get
- https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.collectionGroups.indexes/list

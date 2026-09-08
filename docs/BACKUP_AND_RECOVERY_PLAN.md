# Rokter Badhon Ghatail — Backup and Admin Recovery Plan

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: FROZEN FOR IMPLEMENTATION  
Plan date: 2026-09-07  
Execution status: **PREPARATION ONLY — NO BACKUP OR RECOVERY EXECUTED**

This operational plan follows [CURRENT_FIREBASE_INVENTORY.md](CURRENT_FIREBASE_INVENTORY.md), [MIGRATION_PLAN.md](MIGRATION_PLAN.md), [AUTH_AND_SECURITY.md](AUTH_AND_SECURITY.md), [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md), and [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md). It does not amend their permission contracts or authorize execution. Application bulk export remains an unlisted, denied capability; an approved operator using separately verified operational credentials performs backups outside the application.

No Firebase reads were repeated for this plan. The baseline below is evidence from the inventory, not a fresh snapshot. No exports, imports, account changes, auth links, roles, indexes, buckets, rules, billing/IAM changes, PITR/delete-protection changes, or application changes were performed. Current operational amendment: Free V1 uses encrypted raw capture with independent no-cost cloud/offline custody. CLOUD_BACKUP_DESIGN and its readiness/preflight reports are FUTURE / BLAZE OPERATIONAL REFERENCE; their dated observations remain evidence, not current requirements. No earlier one-command authorization is standing execution approval.

## Baseline and responsibility register

| Item | Inventory baseline to revalidate before execution |
| --- | --- |
| Production source | `rokterbadhon-b247b`, project number `941165503580` |
| Firestore | `(default)`, Native, `asia-south1`; 2 User documents; other legacy collections empty |
| Auth | 1 default-project account; enabled, emailVerified false |
| Legacy admin User and Auth UID | `nb3LLlkwB9QlF8ePYqRKPtkhct32`; role admin; active true; auth_uid and login_enabled missing; legacy uid matches |
| President User | `HEXfP31SPrYrDXayKcW2`; role president; active true; login_enabled false; auth_uid null; no Auth account |
| Target authorization state | Neither User has access_role; no auth_links discovered |
| Recovery infrastructure | No project Storage bucket or managed backup/schedule observed; PITR and delete protection disabled |
| Rules/indexes | Broad signed-in reads; legacy UID-path admin writes; zero composite indexes; default single-field indexes ready; two required donor composites missing |
| Operator tooling | Existing CLI OAuth session previously supported metadata/data reads; Firebase CLI 15.11.0; no gcloud on PATH or standard ADC found |

Do not classify a newly observed third User/account or changed state as corruption automatically. Pause, reconcile legitimate changes and reapprove the baseline. Do not force counts back to two and one.

The following execution register must be completed in a restricted operational record. No custodian identity, destination or credential is invented here.

| Required decision | Current status | Required evidence |
| --- | --- | --- |
| Accountable system owner / approval authority | UNASSIGNED | Named person, authority over this project and approved change scope |
| Backup operator | UNASSIGNED | Named operator; authenticated principal; verified source-read/export permissions |
| Independent recovery custodian / reviewer | UNASSIGNED | Named alternate with strong authentication and tested recovery access independent of Flutter |
| Artifact destination and key custodian | UNSELECTED | Exact path/URI, owner, encryption and access checks; separate key-recovery route |
| Restore target and operator | UNSELECTED | Exact isolated target project/environment and permissions; production explicitly excluded |
| Capture window, acceptable data-loss window and recovery-time objective | UNAPPROVED | Owner-approved schedule and measurable RPO/RTO; no promise based on this plan |
| Retention/deletion review date | UNAPPROVED | Approved duration, legal/privacy requirements and disposal owner |

## 1. Firestore backup procedure

### Current Free-V1 capture method

Use a reviewed operator-local raw Firestore read/capture tool, supported Firebase Auth export, and deployed Rules/index/config capture. Preserve types and paths without using Flutter model defaults. No managed Firestore export/import, new bucket/project, billing or hosted paid execution is required or authorized. Select an approved existing no-cost independent cloud destination or encrypted offline medium; this laptop must not be the sole long-term copy.

Managed export/import and separate paid cloud backup provisioning are FUTURE / BLAZE OPERATIONAL REFERENCE only. A raw capture is not a managed export and needs its own reviewed raw restore tool. It is not automatically a consistent snapshot: a verified quiet window or explicit reconciliation/repeat is required.

### Capture sequence for a later authorized phase

1. Record explicit source project/database, approved destination, method, operator, run ID and UTC start time. Revalidate identity and scope using read-only checks. Never rely on a CLI default project or emulator environment.
2. Coordinate a no-write interval with all known operators/clients and identify automated writers. A verbal pause alone is insufficient if writers cannot be accounted for. Do not deploy temporary rules as part of backup authorization; an enforced maintenance change requires separate scope. If quiescence is uncertain, record capture bounds and reconcile changes or repeat the capture.
3. Re-enumerate roots and nested collections, including descendants of missing parent documents, with complete pagination. Capture all documents, not only users or the five code-referenced names. Reject incomplete/permission-denied pages rather than marking them empty.
4. Preserve document paths and native values, including Timestamp precision, integers, null versus absent versus empty string, references, arrays/maps and other Firestore types. Preserve raw document metadata separately. Never deserialize through current Flutter models; never normalize or synthesize fields during backup.
5. Run only the separately approved raw capture with complete pagination and recursive path coverage. Preserve native REST type wrappers, precision and document metadata; mark any omitted/inaccessible page or descendant as failure. Use an exclusive unique run directory outside the repository; encrypt artifacts before independent transfer.
6. Re-read counts, User security states and source update metadata after capture. Reconcile with Auth capture within the same window. A count match alone is insufficient: compare paths and values/types, or the raw restored data against a stable baseline. Investigate any change before accepting the run.
7. Record completion time, byte/object counts, integrity checksums and verification results without personal values in the repository. Leave source documents untouched.

The existing joined_date values must remain Timestamps in backup. The legacy admin's missing login_enabled/auth_uid must remain missing; the President's explicit false/null must remain false/null. A backup preserves legacy evidence; it does not make that evidence valid v1.2.1 authorization.

## 2. Firebase Auth backup/export procedure

1. Verify the operator and exact project, current account count, providers, tenant usage (previous inventory covered default-project accounts), verification/disabled state and secure destination. Account listing permission does not prove complete credential-export capability.
2. Select supported firebase auth:export to a unique JSON file in an approved temporary protected workspace outside the repository, with explicit `--project rokterbadhon-b247b`. Do not run it from the repository, enable debug payload logging, or overwrite an existing file. The final command and resolved output path must be reviewed in the separate backup authorization.
3. Treat the file as credential-bearing. Supported exports can contain password hashes/salts; algorithm/import history can affect their completeness. Capture required restore configuration separately under protected custody, without printing it, putting it in shell history, or embedding it in this document. See [Firebase Auth import/export](https://firebase.google.com/docs/cli/auth).
4. Verify UID/provider coverage and present-state fidelity in a restricted local validation process. Expect the one inventory UID only if the refreshed baseline agrees. Validate disabled and emailVerified explicitly; capture missing export coverage in a protected supplemental metadata manifest rather than assuming false. Verify any custom claims, MFA/provider configuration or tenant-specific recovery needs separately if discovered.
5. Preserve the observed emailVerified false and disabled false in the baseline. Do not verify, reset, disable or recreate the account to make the backup test pass. The President must not appear as a newly created Auth account.
6. Encrypt the Auth artifact, transfer only ciphertext to the approved independent no-cost cloud/offline destination, verify its checksum and recoverability, then remove plaintext temporary material under the approved cleanup procedure. Verify encrypted-volume protection and ACLs before any plaintext capture; ordinary SSD file deletion is not proof of secure erasure. Hash configuration is sensitive recovery material requiring separate protected custody, never plaintext in the bundle. Reconcile User/Auth IDs; report only counts/state checks and never account export contents.

A metadata-only export is useful evidence but is **not** proof of password-preserving recovery. If credential material cannot be exported, document a degraded recovery route requiring owner-controlled Firebase password reset in a later approved incident procedure; do not declare equivalent restore coverage. Auth export also does not back up active sessions, operational IAM credentials or all project settings. No password, reset message or verification email is sent in this task.

## 3. Rules, indexes and configuration backup procedure

Capture separately from document data, into the same protected run bundle:

- Exact deployed Firestore release/ruleset source and metadata, with checksum. Baseline release is `cloud.firestore`, ruleset `fbb416ea-c159-4515-b43f-a18c009fe7ce`, last updated `2026-09-05T06:23:02.712470Z`. Re-resolve the release before capture; a stale ruleset ID is not proof of current deployment.
- Complete composite and single-field/TTL configuration with pagination and database metadata. Preserve zero composites as an observed configuration. The missing donor indexes belong in a future change plan, not in the backup of current state.
- Local `firebase.json`, `lib/firebase_options.dart`, `android/app/google-services.json`, Android Gradle configuration and an application/source/build version manifest, migration manifest and checksums. Record absence of `.firebaserc`, local rules/index files and Storage rules instead of fabricating them.
- Auth provider/authorized-domain/recovery settings, relevant App Check, IAM, service-agent, billing and project metadata where safely readable. Record inaccessible settings and which custodian owns their recovery. Do not copy CLI token caches, private keys or debug logs into the configuration bundle.
- Storage bucket/rules enumeration. If still absent, save absence evidence, not an empty placeholder object backup. If new objects exist, stop to expand authorized scope to a verified object-and-metadata copy; no object backup is assumed by this plan.
- Release signing custody and recovery references, without key contents. The current debug-signed release configuration is historical evidence, not an approved production-signing setup.

Configuration capture is not deployment. A copy of the current permissive rules is forensic evidence and must not become the automatic production rollback policy.

## 4. Secure artifact storage requirements

Use encrypted artifacts with restricted, independently recoverable no-cost cloud/offline custody. No application users or runtime service accounts receive access. Use local storage only for protected temporary work outside the repository, shared folders and build output. No Firebase Storage capability or new paid cloud resource is part of this path.

Requirements before capture:

- Exact resolved destination, available capacity, existing encryption, least-privilege access, named custodians, retention and deletion-review date are approved. Use unique run IDs and exclusive creation; never overwrite prior runs.
- Full-disk encryption and restrictive filesystem ACLs protect local plaintext during export. Cloud artifacts require encryption and restricted operational access. Do not claim a backup is encrypted merely because a later encryption step is planned.
- Key/credential recovery is held separately from the artifacts and does not depend solely on the production Flutter account. Verify that the alternate custodian can recover access. No shared plaintext passwords or new service-account key files are required by this plan.
- Separate Auth credential material and restore-secret configuration from broadly readable manifests. Record only secure references in the operational manifest. Application leaders receive no backup authority from their role.
- After initial encrypted capture verification, verify an independent no-cost cloud/offline copy and plan a second independently recoverable copy under separately approved custody. Track this separately from first-capture readiness. All creation/transfer/retention changes require separate authorization.
- Keep operational logs minimal: operator principal reference, approval/run ID, source/target, bounds, counts, checksums, operation status and reviewer. No tokens, verification links, private profiles or credential values.

Use `rokter-badhon/{firestore,auth,config,manifests,verification}/YYYY-MM-DDTHHMMSSZ_<run-id>/` as the logical artifact layout, preserving raw paths/types in manifests. Names are unique, not proof of enforced immutability. Approve lifecycle/retention before execution; provider-specific versioning/retention controls require separate review. No bucket is selected or required. Manifests distinguish complete/partial/failed artifacts and reference protected recovery material without embedding secrets.

## 5. Restore rehearsal procedure

Restoration is a separate mutation phase requiring explicit approval even when the destination is staging. It is not included in permission to export.

1. Name and validate an isolated empty emulator or separately approved no-cost staging/recovery environment, never production rokterbadhon-b247b. Use reviewed raw restore tooling, explicit target allowlists, no production fallback or outbound email/SMS and restricted access. Emulator checks do not prove real Auth password/import continuity; validate that separately in an approved isolated supported target or record the recovery limitation. Paid managed import/service-agent bucket permissions are not current prerequisites.
2. Verify bundle integrity and key recovery. Use synthetic fixtures first to validate the restore mechanism and its preservation of missing/null/false values. Synthetic tests do not replace a restricted real-bundle restoration test when declaring this backup restorable.
3. Restore original legacy Firestore data and Auth metadata/credential material only into that approved target. Do not perform schema migration during this baseline restore. Validate the specific Auth format's preservation of disabled/verification/provider state, including supplemental restoration where needed. Keep the isolated service inaccessible to normal users while baseline state is evaluated.
4. Preserve IDs and compare restored raw fields/types and collection coverage against the capture manifest. Expect two Users and one Auth account only if that was the capture baseline. Verify both specific IDs, the admin missing fields, President login false/no Auth, and all original dates. Raw restoration must use an empty isolated target and prove no unrelated documents remain; do not treat successful parsing as proof of restoration.
5. Restore/reconstruct configuration only under target-specific controls. Do not expose staging through the copied permissive production rules. Verify the captured rules/index artifacts are readable and reproducible through isolated tooling; distinguish configuration reproducibility from approval to activate them.
6. Separately exercise v1.2.1 migration/recovery against a disposable restored copy once its tooling is reviewed. Rehearse missing-link denial, stale token rejection, failed/duplicate/concurrent bootstrap, directory atomicity, protected-admin recovery and leader denial. Do not change the immutable baseline bundle to accommodate migration.
7. Validate Auth password continuity without exposing the administrator's password to operators. Use owner-controlled validation only in the approved isolated environment, if safe; otherwise record password continuity as unverified. Metadata comparison alone cannot pass that check. Rehearsal must not send production reset/verification messages.
8. Measure recovery time and compare with approved RTO/RPO; record exact failures and reviewer acceptance. Plan disposal of restored personal data under a separately approved retention cleanup. No production restore or automatic destructive cleanup is authorized here.

## 6. Backup verification checklist

All boxes are pending, not completed results.

- [ ] Approved source, target, run ID, operator and capture window recorded.
- [ ] Entire Firestore scope, subcollections and pagination accounted for; no error reported as an empty collection.
- [ ] Artifacts have terminal success/completion markers; no partial files counted as backups.
- [ ] Document IDs, raw types, absent/null/empty states and original Timestamp precision reconcile.
- [ ] Auth UID/provider coverage and disabled/verification state reconcile; credential restore coverage explicitly assessed.
- [ ] Admin and President identity/state checks pass without altering either account.
- [ ] Rules release/source, composite indexes, single-field configuration and relevant config captured independently.
- [ ] Source changes during capture are absent or fully reconciled across Firestore/Auth; no false cross-service snapshot claim.
- [ ] Primary cloud objects/generations/checksums verify; Auth ciphertext is recoverable and temporary plaintext cleanup is recorded.
- [ ] Eventual second-copy decision and independent restore verification are tracked separately; primary capture is not mislabeled as full recovery readiness.
- [ ] Isolated restore passes; unsupported fields/settings and password-continuity limits are documented.
- [ ] Capture/restore manifests contain no public secrets or unnecessary personal values; retention dates and owners recorded.
- [ ] Reviewer accepts the bundle for the proposed recovery scope. Successful capture alone is not a passed restore rehearsal.

## 7. Existing developer-admin bootstrap and recovery plan

### Identity and operational authority

The sole technical candidate is User/Auth UID `nb3LLlkwB9QlF8ePYqRKPtkhct32`. Confirm that the intended owner controls the existing Firebase identity through a private owner-controlled sign-in and email verification procedure, and independently confirm their system-owner designation with the accountable owner/custodian. Name/email/phone matching, title or CLI possession alone is insufficient. Retain minimal evidence references and reviewer attestation; do not store identity documents or passwords here.

These verification actions themselves are later authorized work. The current Auth account is unverified; do not set emailVerified true merely because the UID matches. Do not use organization registration approval to provision this protected account. The President's office supplies no bootstrap authority.

Execution requires named primary and alternate custodians, strong operational authentication, verified least-privilege access and a recovery route independent of application admission. A developer_admin application token alone cannot authorize `admin.provision`/`admin.recover`; all application-role cells remain DENY. No second application admin or new Auth identity is proposed automatically.

### Proposed bounded bootstrap, not approved field writes

Preserve the existing User document ID as an opaque ID. A later reviewed, dry-run manifest may request only the following, after backups and rehearsal pass:

| Target | Proposed eventual effect | Gate |
| --- | --- | --- |
| Existing admin User | Explicit `access_role = developer_admin`, explicit login enablement and approved valid profile/audit metadata; preserve current active true unless independent incident evidence requires another action | Independently verified system-owner designation and explicit P approval; missing login state is not authorization |
| `auth_links/nb3LLlkwB9QlF8ePYqRKPtkhct32` | Exactly one active link to the existing verified User, with server creation time and attributable creation evidence | Verified Auth identity/email; no conflicting UID link or active User link; common serialized transaction protocol |
| Matching `user_directory` document | Exactly name, phone, blood_group, profession, photo_url, active from validated authoritative User | Q: atomic with User changes; no security fields; missing source data resolved without inventions |
| `audit_logs` event | Committed protected bootstrap action, operation ID, server time, minimal before/after evidence and reason | Atomic with Firestore state; trusted operational identity attribution |

This table defines a future review boundary, not a write payload. Required created_at provenance is currently unresolved: joined_date must not silently become created_at, and current time cannot replace unknown historical dates. Resolve provenance before a full valid User conversion. Preserve legacy evidence and determine exactly which fields remain temporarily for controlled compatibility under MIGRATION_PLAN §6; final v1.2.1 User must omit role/uid/auth_uid/committee-year legacy authority. No cleanup or field retirement is part of backup preparation.

System/recovery audit actors may be null only as explicitly permitted in DATA_MODEL §11, with an attributable operational record and reason. Do not invent an admitted actor to authorize bootstrap. Resolve required link creation attribution before execution. Null recovery actors do not turn into a new application role.

Use a fixed target, reviewed field diff, pre-state/update-time guards, a unique operation ID and payload identity. Serialize all competing link writers on the target User; a query followed by an independent write is insufficient. Commit User, directory, link and required audit evidence together within Firestore. Exact retries must not duplicate links/events; conflicting state or reused IDs with different payloads must abort. Fresh Auth checks occur outside the Firestore transaction and require a bounded, revalidated workflow; Firebase Auth and Firestore cannot be presented as one atomic transaction.

### Incident recovery variants

- **Lost app access, existing identity still controlled:** use independently authenticated operational custody to diagnose exact gate failure. Repair only specifically approved fields/links through P, with Q and audit. No permissive rules or missing-field exception.
- **Suspected compromised identity:** contain access and handle session revocation through a separately scoped incident action. Never restore an older active flag over a later security disablement. Verify replacement ownership independently; if replacement is approved, retain the User ID, deactivate the old link, create the new unique link and audit atomically. New Auth account creation, token revocation or disablement is separately authorized, not implied here.
- **Lost all operational custody:** stop account writes and use the project's formal owner/provider recovery route. Do not substitute a leader, a President title, or an unverified email as emergency authority.

## 8. Lockout prevention before v1.2.1 auth cutover

1. Preserve the current production state while planning and backing up. The legacy exception remains an observed dependency, not an approved v1.2.1 recovery mechanism.
2. Verify independent operational recovery access and rehearse it in isolation before enabling strict rules or removing compatibility. Do not test recovery by disabling the only production administrator.
3. Obtain verified email through the owner-controlled process and a fresh token. Stage a reviewed compatible client, trusted execution and rules together; test fail-closed gate behavior and old-client rejection.
4. Rehearse the exact admin bootstrap and full schema/projection transition using the restored copy. Resolve missing required provenance first. The protected operational recovery tool must not require the application admission state it is supposed to establish.
5. Approve a bounded cutover window and a security-preserving failure mode. Capture a new checkpoint immediately before the actual mutation. Quiesce legacy writers through an explicitly approved mechanism; do not add new authority while unsafe old writers can overwrite it.
6. Perform later approved bootstrap/schema work under operational custody, then activate matching enforcement and verify fresh-session admission. No individual ordering of client/rules/data deployments can replace the rehearsed coordinated plan.
7. Revalidate the President's login_enabled false, absence of an Auth account/link, and absence of any inferred role. A future explicit organization role decision is required before their schema conversion; office alone supplies none.
8. Only after recovery and admission checks pass, remove legacy lookup/fallback and retire legacy fields in their approved phase. Subsequent backend requests must enforce current link/User/login state; UI or cached session continuity is insufficient.

If a gate fails, stop in a preapproved restrictive maintenance state and use operational recovery. Do not restore broad authenticated reads or infer admin privileges to regain access.

## 9. Rollback checkpoints

| Checkpoint | Evidence to retain | Recovery behavior |
| --- | --- | --- |
| R0 — inventory baseline | Existing redacted report; no restorable artifact yet | No mutation has occurred; continue prerequisite work only |
| R1 — verified backup bundle | Raw legacy data/Auth/config, checksums, capture bounds, isolated restore evidence | Forensic/data recovery source; unsafe old rules are not an automatic deployment target |
| R2 — immediately before admin bootstrap | Fresh exact pre-state, approved diff, recovery-custody check, operation ID | Abort on drift; failed Firestore transaction leaves no partial User/link/directory/audit state |
| R3 — explicit admin prepared, before strict cutover | Validated state, committed audits and compatible release/rules/backend references | Diagnose through operational controls; do not delete a valid link or restore missing-field admission as rollback |
| R4 — strict v1.2.1 cutover validated | Gate/negative-test results, client/backend/rules versions and revocation journal | Roll back only to a security-compatible version or approved restrictive maintenance |
| R5 — before legacy retirement | Reconciliation report and archived provenance | Delay cleanup on uncertainty; restore historical evidence only through reviewed repair |

No blind production import or database wipe is a rollback step. Reconcile all writes and security revocations after the selected checkpoint; preserve later disablements, link replacement and role reduction. Record compensating actions with new audit evidence rather than deleting prior audit history. Auth changes and Firestore changes need separately tracked checkpoints and compensation. If the only older executable version is insecure, it is not an acceptable automatic rollback target.

## 10. Manual verification before any mutation

Required before backup artifact creation/export:

- Name owner, operator, alternate recovery custodian and reviewer; verify operational identity and exact project/database.
- Approve the reviewed raw capture/restore tool, protected workspace, independent no-cost destination, artifact encryption/key custody, retention and cleanup.
- Confirm raw Firestore read and supported Auth credential-export capability without treating metadata reads as proof. Missing credential/workspace access is a blocker; no billing, bucket or IAM change is implied.
- Recheck source drift, nested coverage, Auth tenant/provider scope, buckets and existing backups. Approve a capture window and reconciliation strategy.
- Review the exact command/tool request, artifact paths, logging behavior and cost implications; obtain explicit backup authorization.

Additional gates before restore or production security/data mutations:

- Name the isolated restore target, prove production exclusion and authorize its writes separately.
- Verify owner-controlled admin identity, email ownership and independent recovery custody; settle credential continuity limits.
- Resolve required historical provenance, exact approved migration field diffs and audit attribution; do not fabricate dates/actors.
- Pass recovery, transaction/idempotency, Q, link uniqueness, revocation and capability-denial tests; approve the coordinated client/backend/rules plan.
- Record rollback owner, checkpoints, maintenance behavior and preservation of later revocations. Actual migration needs fresh explicit authorization.

## 11. Exact next eventual operation — DO NOT EXECUTE

Next safe step: review the raw capture tool and synthetic type-roundtrip tests, name custodians, and verify a protected temporary workspace plus independent no-cost artifact destination. No production data is captured by that review.

After those gates and separate explicit backup authorization, the first data-bearing operation is a read-only raw capture of projects/rokterbadhon-b247b/databases/(default) into a unique protected artifact outside the application repository. Source data stays untouched, but artifact creation contains private data and is not authorized by this document. Auth export, config capture, encryption, independent transfer and cleanup must be explicitly scoped. No managed export endpoint is used.

The first eventual production security mutation remains the separately approved, rehearsed existing-admin bootstrap in section 7, only after verified backup/restore, identity and provenance gates. Its exact write manifest remains blocked by unresolved prerequisites. Preserve President login_enabled = false. Backup approval does not authorize account changes, auth links, role assignment, rules/index deployment, billing or cloud provisioning.

## 12. Go / No-Go for migration preparation and actual backup

| Gate | Current result | Consequence |
|---|---|---|
| Dated inventory and Free-V1 plan | GO for documentation/read-only preparation | Refresh source before authorized capture |
| Operator, alternate custody, encrypted workspace and independent destination | NO-GO until evidenced | No data-bearing artifact creation yet |
| Reviewed raw capture/restore and Auth export coverage | NO-GO until tested | Pagination, descendants, types, quiet-window consistency and credential continuity must be demonstrated |
| Exact commands/window and backup authorization | NO-GO until approved | This document grants no standing execution permission |
| Isolated restore and verified recovery bundle | NO-GO for production migration until passed | Emulator-only Auth evidence must not overstate credential recovery |
| Verified existing admin identity/email, provenance and rehearsed cutover | NO-GO for security cutover until resolved | Preserve legacy evidence and President denial; no inferred access |

Current path is Free V1 raw capture, supported Auth/config capture and encrypted independent custody. Billing, Blaze, paid cloud provisioning and managed export are not prerequisites. Protected temporary handling is required for raw Firestore personal data as well as Auth credential material. Local BitLocker remains unverified dated evidence until independently checked; choose a verified protected environment before capture.

Stop after planning. Actual backup, restore and migration each require their own concrete authorization and evidence.

# Rokter Badhon Ghatail — Cloud Backup Readiness

> **FUTURE / BLAZE OPERATIONAL REFERENCE — NOT ACTIVE IN FREE V1.** Production Architecture v1.2.1, Free V1 Implementation Profile, is FROZEN FOR IMPLEMENTATION on Spark. This document preserves dated cloud planning/verification evidence; it is not a current provisioning, billing, IAM or managed-export requirement or authorization. Current backup procedure: [BACKUP_AND_RECOVERY_PLAN.md](BACKUP_AND_RECOVERY_PLAN.md).

Production Architecture v1.2 — FROZEN FOR IMPLEMENTATION  
Verification date: 2026-09-07  
Scope: read-only cloud metadata and capability verification; proposed settings only.

Reviewed [CURRENT_FIREBASE_INVENTORY.md](CURRENT_FIREBASE_INVENTORY.md), [CLOUD_BACKUP_DESIGN.md](CLOUD_BACKUP_DESIGN.md), [BACKUP_AND_RECOVERY_PLAN.md](BACKUP_AND_RECOVERY_PLAN.md) and [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md). Only this document was created. No project, bucket, billing, IAM, Auth, data, export, upload, deployment, installation or migration operation was performed. No credential values or billing-account identifiers are included.

## 1. Billing status

**BILLING NOT ENABLED — VERIFIED FROM LIVE CLOUD BILLING METADATA.**

The read-only project billingInfo response for `rokterbadhon-b247b` returned:

- `billingEnabled: false`.
- No linked billing account name.

There is therefore no linked account whose open/closed status can be inspected for this project. Other billing accounts the operator might control were not enumerated. Firebase **appears to be Spark**, inferred from the unbilled project state; the Firebase console's plan label was not separately read. The definitive observed fact is billing disabled, not a guess based on Firestore free-tier metadata.

Managed Firestore export/import requires billing on the relevant Firestore project; Firebase requires Blaze. Export incurs document-read charges and Cloud Storage incurs storage charges. No upgrade or billing linkage is authorized by this report. See [managed export/import requirements](https://firebase.google.com/docs/firestore/manage-data/export-import).

## 2. Firestore service agent

**VERIFIED FROM LIVE PROJECT IAM POLICY:** this exact principal has an unconditional `roles/firestore.serviceAgent` binding on production:

`service-941165503580@gcp-sa-firestore.iam.gserviceaccount.com`

This is actual IAM evidence, not merely a constructed naming pattern. However, **service-account existence/enabled state and active export-job identity are NOT FULLY VERIFIED**:

| Read-only check | Result |
| --- | --- |
| Project IAM getIamPolicy | Successful; exact principal and Firestore service-agent role found |
| IAM serviceAccounts.get under production project | HTTP 404 |
| IAM serviceAccounts.get using wildcard project path | HTTP 403 |

Do not interpret these responses as proof the agent is absent, disabled or usable. A policy binding alone does not prove a live enabled account or identify the account currently selected for export/import jobs. The project-scoped 404 and wildcard 403 leave that distinction unresolved.

**Required manual check:** an authorized operator must view Firestore Import/Export's “jobs run as” identity and IAM/service-agent details with Google-provided role grants visible. Confirm the exact account, enabled state where available, and whether legacy App Engine identity is involved. Record only the principal and status. Do not generate a service identity or grant IAM as a diagnostic step. Google's documentation distinguishes these export identities and documents the service-agent requirement. See [service-agent verification and permissions](https://firebase.google.com/docs/firestore/manage-data/export-import#service_agent_permissions).

## 3. Operator source export capability

**VERIFIED FROM LIVE testIamPermissions:** the existing authenticated CLI principal has all requested source-project permissions:

| Permission | Purpose |
| --- | --- |
| `datastore.databases.export` | Initiate a Firestore export |
| `datastore.databases.get` | Inspect database metadata |
| `datastore.operations.get` | Read export-operation status |
| `datastore.operations.list` | List operation metadata |

Database metadata independently confirmed `projects/rokterbadhon-b247b/databases/(default)`, Native mode, location `asia-south1`.

**Source permission gate: PASS. Source export execution readiness: NO-GO.** Billing is disabled, exact export-agent usability needs confirmation, and the cross-project destination/access do not yet exist as approved resources. Organization policy, service perimeter and destination compatibility constraints remain unverified. A successful permission test is not a successful export.

The existing CLI session was refreshed in memory; credentials were neither printed nor saved. An initial connection reset occurred before the metadata checks; a subsequent retry succeeded. No Auth accounts, password hashes or Firestore documents were retrieved during this task.

## 4. Exact future backup-project requirements

These are requirements for a later separately approved provisioning change set, not resources created now.

1. A separate operational Google Cloud project under an approved organization/folder and named owner/custodians. Final project ID remains unselected. No Firebase application registration or Flutter use.
2. An approved active billing-account relationship for that backup project and a separately approved source-project billing/Blaze change. Do not infer authority to use a billing account from export permissions. Identify billing owner and project/billing-link permissions before requesting execution.
3. Cloud Storage API (`storage.googleapis.com`) available/enabled for backup operations; verify status before planning any enablement. Other management/IAM/budget API requirements depend on the approved provisioning tooling. No API enablement is performed here.
4. One dedicated, globally uniquely named Cloud Storage bucket in `asia-south1`, using the proposed defaults below. Final bucket name remains unselected.
5. Uniform bucket-level access, public access prevention, encryption at rest, least-privilege operational access and independently recoverable administrative custody.
6. Reviewed bucket-level access for the verified production Firestore export agent. No application users or runtime service accounts receive access. An application developer_admin role does not supply operational authority.
7. Approved capture schedule, run naming, retention, budget contacts, validation process and isolated recovery project. The separate staging/recovery project is not the backup-custody project and must never be production.

Proposed logical prefixes are `rokter-badhon/firestore/`, `auth/`, `config/`, `manifests/` and `verification/` under the same `rokter-badhon/` root, each followed by `YYYY-MM-DDTHHMMSSZ_<run-id>/`. Preserve the complete managed-export hierarchy; use new prefixes rather than overwriting runs. No actual bucket/project name is invented.

## 5. Proposed initial bucket defaults

| Setting | Proposal — not configured |
| --- | --- |
| Location | Regional `asia-south1` |
| Storage class | Standard |
| Public access | Public access prevention enforced |
| Access model | Uniform bucket-level access enabled |
| Encryption | Google-managed encryption at rest initially; Auth artifacts also encrypted before upload with separately recoverable key custody |
| Application access | None, including application runtime service accounts and Firebase users |
| Flutter/Firebase application configuration | Must never reference this bucket/project |
| Retention | Propose 90 days initially, with an **unlocked** 90-day bucket retention policy subject to approval and compatibility review |
| Lifecycle deletion | Propose age-based deletion at/after 90 days only after approving restoration/verification and privacy requirements; do not enable deletion until reviewers accept the policy |
| Object versioning | Disabled initially; enable later only for a concrete recovery benefit and reviewed cost |
| Retention lock | Not enabled initially |
| Naming/overwrite | Unique run prefixes; no intentional overwrites |

Concerns: a 90-day retention policy prevents early object removal while in force, including mistaken or sensitive uploads. It is a minimum retention control, not an automatic purge schedule; lifecycle deletion is separate and asynchronous. Do not confuse an unlocked policy with strong protection against a privileged administrator changing it. Unique run names are not enforced immutability. Confirm managed-export behavior with the proposed retention controls before execution, and keep incomplete-run handling explicit.

Standard favors straightforward access/rehearsal for this small workload. Future volume, frequency, transfers and retention can change cost. Soft-delete defaults must be reviewed separately before provisioning because they can extend retained storage beyond lifecycle deletion; disabled object versioning does not determine soft-delete behavior. Never promise exact 90-day physical disposal without examining all retention mechanisms. See [Cloud Storage retention policies](https://cloud.google.com/storage/docs/bucket-lock) and [soft delete](https://cloud.google.com/storage/docs/soft-delete).

## 6. Proposed IAM relationship table

No policy or binding was created. Named principals, approvals and effective inherited permissions must be reviewed before execution.

| Principal purpose | Target resource | Required permission category | Duration | Removal/reduction point |
| --- | --- | --- | --- | --- |
| Provisioning operator | Selected project parent, backup project and selected billing account | Only approved project creation/configuration, API enablement, billing linkage and bucket setup responsibilities; split duties where practical | Temporary setup access | After provisioning and custody verification; no automatic persistent Owner grant |
| Source export operator | Production project/database | Export initiation and operation monitoring; source permissions currently verified | On-demand or narrowly persistent for approved operations | Remove when operator no longer runs approved backups; review periodically |
| Verified production Firestore service agent | Dedicated backup **bucket** | Managed-export Storage access; documented Storage Admin role at bucket scope, subject to review below | Prefer operation window | Reduce/remove after export terminal success and verification, before the next explicitly approved window where practical |
| Auth/config uploader | Dedicated bucket and supported scoped artifact resources | New ciphertext/config/manifest object upload and required verification; no routine IAM editing or historical deletion | Operation window or reviewed dedicated operational identity | Remove/reduce after verified upload; retain only approved recurring responsibilities |
| Backup custodian | Backup project/bucket and separate key custody | Restricted administration and recovery/verification access; independently authenticated | Persistent, reviewed | Remove at custody handover only after replacement recovery is verified |
| Budget manager/recipients | Relevant billing-account budget resource / notification channels | Budget management for manager; notification delivery for recipients, not broad data access | Persistent, reviewed | Reduce when duties end; preserve responsible alert coverage |
| Recovery-project Firestore service agent | Backup bucket containing approved export | Required managed-import Storage access, documented bucket-level role; validate destination identity/location | Temporary rehearsal/incident window | Remove/reduce after import and verification finish |
| Restore operator | Separate staging/recovery database/project | Import and operation monitoring; approved artifact access as needed | Temporary rehearsal/incident window | Remove after validation and disposition review |
| Application users/runtime accounts | Backup project/bucket | **None** | No grant | No grant to remove; reject inherited/broad app access during review |

Google's current guide explicitly says the service agent needs **Storage Admin (`roles/storage.admin`) on the bucket** for managed export/import. Do not silently substitute an unvalidated object-creator or viewer role. Bucket-level Storage Admin is narrower in resource scope than project-wide Storage Admin but remains broad within that bucket; it can affect historical artifacts and more than one prefix. Proposed object paths do not isolate IAM by themselves. A custom narrower supported permission set may be assessed later, but none is asserted as validated here. The production service agent is an operational service identity, distinct from application runtime service accounts.

Inspect inherited grants, supported resource conditions and impersonation routes before approval. Cross-project separation is weakened if production/app operators can impersonate backup custodians or hold broad persistent bucket access. Revoke only after operations finish, not while exports/imports are running. No project-wide Storage Admin grant is proposed.

## 7. Proposed cost controls

**Alerts-only monthly budget proposal: USD 5. Not created.**

| Actual-spend threshold | Alert amount |
| --- | ---: |
| 50% | USD 2.50 |
| 90% | USD 4.50 |
| 100% | USD 5.00 |

Prefer a budget scope covering the production export costs plus the backup project's storage/operations and, when applicable, staging rehearsal costs on the chosen billing account. A backup-project-only budget misses production Firestore read charges. If projects use different billing accounts, approve separate budget scopes/amount allocations rather than pretending one budget crosses billing-account boundaries. Confirm currency compatibility; do not silently replace USD with another currency.

Choose named billing recipients and a backup contact, verify delivery, and assign a reviewer to investigate early alerts. Costs and notifications can lag. This is an **alerts-only** proposal: budget alerts are notifications, not a hard spending cap, and USD 5 is not a guaranteed maximum bill. No spend-cap automation or automatic billing disablement is proposed. See [Cloud Billing budget alerts](https://cloud.google.com/billing/docs/how-to/budgets).

The small inventory supports starting with a low alert threshold, not promising that all backup/restore activity will fit it. Confirm capture frequency, object retention/soft deletion, second-copy scope and restore/transfer costs before approval.

## 8. Auth temporary-workspace blocker

**Firestore:** managed export is cloud-to-cloud; no local plaintext staging and no laptop BitLocker prerequisite.

**Firebase Auth:** supported auth:export remains a separate workflow: protected temporary export → artifact encryption → ciphertext upload → checksum/object verification → secure plaintext cleanup. Hash configuration also needs protected custody. No Auth export or hash retrieval occurred here.

Minimum safe alternatives to select and verify:

- A trusted workstation with verified encryption/protection, restrictive temporary-directory permissions, no shared/synchronized folder, an approved encryption tool and key-recovery/cleanup method. The previous laptop check could not verify BitLocker, so that specific path is not yet approved.
- A separately controlled temporary cloud recovery environment with encrypted temporary storage, restricted operational identity/network access, no public service or debug output, explicit cache/snapshot/log handling and verified cleanup. A generic Cloud Shell session is not assumed safe merely because it is in the cloud; its persistent home and custody require review. Provisioning such an environment requires separate approval.

Neither option makes local disk long-term backup custody. Do not export first and attempt to secure plaintext later. SSD file deletion alone does not establish erasure; design cleanup and key disposal before capture. The Auth blocker does not prevent a separately scoped Firestore-only cloud export once its own gates pass, but such a partial run cannot be called a complete Firestore/Auth recovery bundle.

## 9. Remaining decisions and GO / NO-GO

| Gate | Result |
| --- | --- |
| Source database/project/location | VERIFIED |
| Operator export/monitor permissions | VERIFIED |
| Source billing | **NOT ENABLED — blocks managed export** |
| Firestore principal in actual IAM policy | VERIFIED binding; existence/enabled state/export selection still needs confirmation |
| Separate backup project/bucket names and parent | UNSELECTED |
| Billing account/owner, linkage authority and budget recipients | UNSELECTED / NOT VERIFIED |
| Custodians and exact bucket IAM scope | UNASSIGNED / review required |
| Proposed Standard/90-day/no-versioning/no-lock defaults | Proposal only; retention/lifecycle/soft-delete implications need approval |
| Cloud Storage API and organization/location constraints in future project | NOT VERIFIED; target does not yet have an approved identity |
| Protected Auth workspace and key recovery | UNSELECTED |
| Staging target and independent second copy | UNSELECTED; separate later provisioning/recovery gates |

**GO for reviewing a provisioning proposal; NO-GO for provisioning execution or export.** The design is concrete enough to request the owner's missing decisions and explicit approval in stages. It is not yet ready for an executable blanket provisioning approval: exact project/bucket identities, organization parent, billing account owner, custodians and IAM principals must first be supplied/validated. Auth staging and second-copy decisions can remain separately gated while reviewing a cloud-infrastructure-only proposal.

**Exact next safe step:** complete a non-secret provisioning decision record naming the proposed backup project/bucket, parent, custodians, billing owner and budget recipients; confirm the console export-agent identity discrepancy; approve or revise the proposed 90-day controls. Then present separate concrete approval scopes for resource provisioning, billing, IAM and budget creation. No approval to export, change the administrator, enable President login or migrate is implied. Stop after this report.

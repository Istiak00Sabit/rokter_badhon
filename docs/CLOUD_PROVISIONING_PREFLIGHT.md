# Rokter Badhon Ghatail — Cloud Provisioning Preflight

> **FUTURE / BLAZE OPERATIONAL REFERENCE — NOT ACTIVE IN FREE V1.** Production Architecture v1.2.1, Free V1 Implementation Profile, is FROZEN FOR IMPLEMENTATION on Spark. This document preserves dated cloud planning/verification evidence; it is not a current provisioning, billing, IAM or managed-export requirement or authorization. Current backup procedure: [BACKUP_AND_RECOVERY_PLAN.md](BACKUP_AND_RECOVERY_PLAN.md).

Production Architecture v1.2 — FROZEN FOR IMPLEMENTATION  
Date: 2026-09-07  
Result: **PROVISIONING NOT READY**

Read-only verification following [CLOUD_BACKUP_READINESS.md](CLOUD_BACKUP_READINESS.md), [CLOUD_BACKUP_DESIGN.md](CLOUD_BACKUP_DESIGN.md) and [BACKUP_AND_RECOVERY_PLAN.md](BACKUP_AND_RECOVERY_PLAN.md). Only this report was created. No project, bucket, billing linkage, API enablement, IAM change, export, upload, deployment, application change or migration occurred. No credentials, billing-account IDs, personal account records or password hashes were printed.

Live checks reused the existing CLI Google session, refreshed in memory without saving credentials. API GET, search, getIamPolicy and testIamPermissions calls were used; these do not reserve names or provision resources. Findings are point-in-time and distinguish permission evidence from execution readiness.

## 1. Billing-account readiness

**VERIFIED FROM LIVE CLOUD BILLING METADATA:**

| Check | Result |
| --- | --- |
| Accessible billing-account count | **0**, successful complete list; no continuation token |
| At least one accessible OPEN account | **No** |
| Production project-side billing-link permission | **Yes:** `resourcemanager.projects.createBillingAssignment` returned |
| Billing-account-side link permission | **NOT VERIFIED:** no accessible account on which to test `billing.resourceAssociations.create` |
| End-to-end ability to link a billing account | **Not established; blocked by account availability/access** |

This does not prove that the person or organization owns no billing accounts elsewhere; it establishes that the currently authenticated identity can see none through this API. No account identifiers were returned or reported. The previous report verified production billing disabled/no linked account; this task does not alter that state.

Billing linkage requires permissions on both the billing account and project. Possessing only the project-side permission is insufficient. An owner must identify an approved active billing account and arrange separately authorized access, or decide on separately authorized account setup. No billing-account creation is implied. See [Cloud Billing permission requirements](https://cloud.google.com/billing/docs/access-control).

## 2. Project-creation readiness and hierarchy

**VERIFIED FROM LIVE RESOURCE MANAGER METADATA:** production project `rokterbadhon-b247b` (number `941165503580`) has no parent in its successful project metadata response. Organization search returned zero accessible organizations and no continuation token. No accessible organization/folder parent was available for a project-creation permission test.

The observed production context is **without an Organization**. This is not proof the identity has no membership in an inaccessible organization. No parent ID or organization name is invented.

**Project creation capability: NOT VERIFIED.** Existing production export/billing-link permissions do not establish `resourcemanager.projects.create` on a future parent or available project quota. No creation request or dry-run mutation was attempted. For an organization/folder, test the create permission on the chosen parent; no such parent is currently visible. For the observed no-organization path, a parent-scoped IAM test cannot establish a global entitlement against an invented parent.

Minimum manual check: with the same Google identity, open the Cloud Console New Project form, inspect the available parent/No organization option and project-quota/permission messages, and stop **before Create**. Record the permitted parent and quota evidence. UI availability is still not a reservation or guarantee that creation will succeed. If an organization/folder is supplied later, recheck permission there and applicable policy. See [project creation requirements](https://cloud.google.com/resource-manager/docs/creating-managing-projects).

## 3. Project ID candidates

All candidates use lowercase letters, digits and hyphens, start with a letter, end with an alphanumeric character and are 27 characters long, within the project-ID length limit. Suffixes are proposed differentiators, not guarantees of global uniqueness.

| Candidate | Read-only project GET | Availability conclusion |
| --- | --- | --- |
| **`rokter-badhon-backup-7k9m2q`** | HTTP 403 | NOT VERIFIED; recommended candidate subject to validation |
| `rokter-badhon-backup-4v8n6r` | HTTP 403 | NOT VERIFIED |
| `rokter-badhon-backup-9p3x5t` | HTTP 403 | NOT VERIFIED |

A permission-denied lookup cannot distinguish an inaccessible existing project from an unavailable-to-this-caller lookup. None is declared available or reserved. Even a later not-found response cannot establish that a previously used/deleted project ID is reusable. Validate the recommended ID through the console's non-creating form validation; final creation remains separately authorized.

## 4. Bucket-name candidates

Candidates use the recommended project's `7k9m2q` suffix, contain only lowercase letters/digits/hyphens, meet normal bucket-name length rules, and avoid dot/domain-verification requirements.

| Candidate | Read-only Cloud Storage bucket metadata GET | Conclusion |
| --- | --- | --- |
| **`rokter-badhon-backups-7k9m2q`** | HTTP 404 | No bucket resolved at check time; recommended, not reserved |
| `rokter-badhon-backups-7k9m2q-a1` | HTTP 404 | No bucket resolved at check time; not reserved |
| `rokter-badhon-backups-7k9m2q-b2` | HTTP 404 | No bucket resolved at check time; not reserved |

These are existence observations, not atomic availability guarantees. Recheck immediately before any later approved creation; another actor can claim a name in the meantime. Do not create a bucket to test availability. If the project candidate changes, review bucket naming again. See [Cloud Storage bucket naming](https://cloud.google.com/storage/docs/buckets).

## 5. Firestore service-agent validation

| Check | Live result |
| --- | --- |
| Principal confirmed in IAM | **Yes**: `service-941165503580@gcp-sa-firestore.iam.gserviceaccount.com` has unconditional `roles/firestore.serviceAgent` on production |
| Firestore API/service | **ENABLED**, from Service Usage `projects/941165503580/services/firestore.googleapis.com` |
| Direct production-scoped service-account resolution | HTTP 404; account enabled-state **NOT VERIFIED** |
| Source export permission | `datastore.databases.export` returned again |
| Legacy account `rokterbadhon-b247b@appspot.gserviceaccount.com` lookup | HTTP 404 |
| Legacy account in production IAM policy | No matching binding found |
| App Engine application metadata lookup | HTTP 404 |

**Service identity resolvable: NOT VERIFIED.** The principal is concretely present in IAM, but that does not by itself prove a live enabled service account or which account export jobs use. The previous wildcard lookup returned 403; the current supported project-scoped lookup did not resolve it. No service-identity generation endpoint was called.

Google documents the older App Engine default export identity. Current metadata provides **no positive evidence that it is relevant here**: no resolved app, account or binding was returned. Do not grant access to that identity as a workaround. Absence in these reads is not a substitute for the selected export-job identity check.

Exact minimum manual check: in production Cloud Console, open **Firestore → `(default)` → Import/Export** and inspect **“Import/Export jobs run as”**. Record the principal without starting a job. In IAM, include Google-provided role grants and confirm the matching service-agent entry; inspect account state where the console exposes it. If permissions prevent this, the project owner must perform the read-only check. Do not press Generate identity, enable services or grant roles to diagnose it. See [Firestore service-agent guidance](https://firebase.google.com/docs/firestore/manage-data/export-import#service_agent_permissions).

## 6. Minimum services for the future project

This is a scope list, not a blanket API-enablement request. Inspect existing enablement first; enable only the services needed by the later approved workflow.

| Category | API/service | Where / why |
| --- | --- | --- |
| REQUIRED | Cloud Storage — `storage.googleapis.com` | Backup project: bucket management and receiving/exporting objects |
| REQUIRED for source operation | Cloud Firestore — `firestore.googleapis.com` | Production only for managed export; already verified enabled. A bucket-only backup project does **not** need a Firestore database or API solely to receive exports. |
| REQUIRED for project provisioning API workflow | Cloud Resource Manager — `cloudresourcemanager.googleapis.com` | Provisioning/control context: project creation and IAM/resource metadata; not a data-storage service |
| REQUIRED for API-enablement management if used | Service Usage — `serviceusage.googleapis.com` | Provisioning/control context: inspect/manage enablement under separate approval |
| REQUIRED for billing-link API workflow | Cloud Billing — `cloudbilling.googleapis.com` | Billing/provisioning context: approved account/project linkage and metadata |
| REQUIRED if configuring proposed budget by API | Cloud Billing Budget — `billingbudgets.googleapis.com` | Budget-management context: the approved alerts-only budget; account permission is also required |
| OPTIONAL | IAM — `iam.googleapis.com` | Needed if the selected workflow manages/inspects service accounts; bucket IAM policies use Storage API. Do not create a service account just to enable this API. |
| OPTIONAL | Cloud KMS, Secret Manager, Logging/Monitoring integrations | Only if approved key custody, secret custody or additional monitoring design needs them; not prerequisites of the basic Google-managed-at-rest bucket design |
| NOT NEEDED FOR INITIAL BACKUP | Firebase application registration/Management, Identity Toolkit in backup project, Firestore database in backup project, Functions, Cloud Run, Compute, Scheduler, Pub/Sub | No application workloads, automation or cloud Auth workspace selected. Future workspace/automation would need its own service design. |

Auth export uses the production Firebase Authentication service and approved operational credentials, not an Auth installation in the backup project. Control API enablement/consumer-project requirements depend on the chosen console/CLI/API execution context; do not indiscriminately enable every listed API on every project. A future recovery project needs its own Firestore setup only when a rehearsal is approved.

## 7. Concrete future IAM draft — NOT APPLIED

Resources below refer to the **recommended candidates**, subject to name/parent approval. Human operator, custodian and uploader principals remain to be named privately. No custom role is proposed, and no default application runtime account is selected for these duties.

| Principal purpose | Target | Proposed predefined role(s) | Reason | Duration / removal point |
| --- | --- | --- | --- | --- |
| Provisioning operator: project creation | Approved organization/folder, if selected | `roles/resourcemanager.projectCreator` | Create the backup project at that parent | Setup-only unless an ongoing duty is approved; no invented parent binding for No organization |
| Provisioning operator: billing | Selected active billing account; backup project | `roles/billing.user` on account; `roles/billing.projectManager` on project | Supply both sides of approved billing linkage | Remove after linkage/verification if not needed; source billing is a separate approved target |
| Provisioning operator: enablement | Backup project | `roles/serviceusage.serviceUsageAdmin` only if enablement is needed | Enable approved APIs | Temporary; reduce after setup |
| Provisioning operator: first bucket | Otherwise dedicated empty backup project, then the bucket | Temporary `roles/storage.admin` for creation/configuration, then bucket-scoped only if still needed | A role on a nonexistent bucket cannot authorize its creation; project-scope setup access must be explicitly bounded | Remove project-scope Storage Admin immediately after bucket creation and handoff; no source-project or ongoing project-wide Storage Admin proposed |
| Backup custodian | Dedicated backup bucket | `roles/storage.admin` | Reviewed bucket IAM, retention and recovery custody | Persistent restricted custodian role, periodically reviewed; handoff only after alternate recovery tested |
| Production Firestore service agent | Dedicated backup bucket | `roles/storage.admin` | Documented managed export access; subject to actual identity confirmation | Operation window; remove/reduce after terminal completion and verification where practical |
| Auth/config uploader | Dedicated backup bucket, supported narrower resource conditions if validated | `roles/storage.objectCreator` plus `roles/storage.objectViewer` | Upload new ciphertext/config and read/list for checksum verification; no delete/overwrite or bucket-IAM power | Upload window; remove after verification unless recurring custody explicitly approved |
| Future recovery Firestore service agent | Dedicated backup bucket | `roles/storage.admin` | Documented cross-project managed import access | Temporary rehearsal/incident window; remove after import validation |
| Future recovery operator | Separate recovery project | `roles/datastore.importExportAdmin` | Approved import and monitoring | Temporary; no production restore authority inferred |

Source operator already has the needed export permission; do not add a redundant role now. Backup-project IAM administration/custody must also be assigned through a separately named authorized project owner/admin; do not infer that bucket Storage Admin grants project-IAM authority. Review any automatic project-creator Owner grant during eventual setup and reduce only after alternate recovery custody is verified. A budget manager, if separate, can use `roles/billing.costsManager` on the selected billing account for budget duties; alert recipients need no bucket access. Validate current role definitions before execution.

The first-bucket bootstrap is the limited project-scope exception: bucket-scoped roles are used once a bucket exists. It is not authority for a production service agent to administer the whole backup project. If an already authorized custodian creates the bucket, do not grant redundant temporary project access to another operator.

Google explicitly documents **bucket-level Storage Admin for Firestore export/import service agents**. Do not invent a narrower object-only role as a supported replacement. The uploader's object-only roles are for ordinary encrypted uploads, not the managed Firestore service-agent workflow. Storage Admin remains broad even at bucket scope; unique prefixes are not an access boundary. Object Viewer also allows reading objects in its scope, so consider ciphertext-only upload and independent key custody, and validate any intended conditions before claiming prefix isolation. See [Firestore export/import permissions](https://firebase.google.com/docs/firestore/manage-data/export-import) and [Cloud Storage predefined roles](https://cloud.google.com/storage/docs/access-control/iam-roles).

## 8. Cost and retention defaults

| Proposal | Validation / concern |
| --- | --- |
| Region `asia-south1` | Matches production database region; no identified regional mismatch. Organization constraints still need checking once the parent is chosen. |
| Standard storage | Suitable baseline for frequent verification/rehearsal; storage and operation charges remain. |
| 90-day retention | Supported policy duration; an unlocked retention policy prevents early deletion/replacement while in force. Review compatibility/failed-export cleanup before execution. It is not automatic deletion at day 90. |
| Public access prevention enabled | Compatible with explicit authenticated operational IAM; keep public principals out. |
| Uniform bucket-level access enabled | Use IAM rather than object ACLs; compatible with this design. |
| Object versioning disabled initially | Avoids unreviewed version accumulation; unique runs preserve logical history. Soft delete must be separately reviewed. |
| Retention lock disabled initially | Avoids irreversible lock; unlocked retention is not protection against a sufficiently privileged administrator changing policy. |
| USD 5/month alerts at 50%, 90%, 100% | USD 2.50 / 4.50 / 5.00; currency, account and recipients still unselected. Alerts notify, not cap spending. |

No known inherent contradiction among these settings is established, but **compatibility is not runtime-tested**. Avoid Requester Pays and unsupported bucket types for managed export. Ensure unique export prefixes and no premature cleanup. Retention can keep accidental/partial uploads billable; lifecycle deletion and soft delete may extend actual storage duration. Verify retention-sensitive upload/cleanup behavior before scheduling exports. No policy or budget was created.

The immediate technical blockers are billing-account availability and unverified project-creation/service-identity readiness, not Standard storage or the proposed region. Budget scope must account for production read charges as well as backup storage and later recovery costs. A budget on the backup project alone misses source charges; budgets cannot be assumed to aggregate unrelated billing accounts. Capture frequency/RPO/RTO and retention privacy approval remain owner decisions.

## 9. Ranked Auth temporary-workspace options for this Windows machine

Neither option is approved for use. Firestore managed export needs no local plaintext; these gates apply specifically to Auth export/encryption.

**Rank 1 — A. Local protected temporary workspace, only after verification.** This is the simplest practical option with the already installed Firebase CLI and 7-Zip, provided the Windows administrator can establish protection. Before use verify:

- Active drive encryption/protection (not suspended), or an approved encrypted temporary volume; the current BitLocker result remains unverified.
- An exact path outside `C:\rokter_badhon`, no junction/shared/sync exposure, restrictive ACLs, sufficient space and no unprotected temporary/cache paths.
- Installed archive tool's security suitability, approved encryption settings and successful synthetic encryption/decryption test; separate recoverable key custody, no password in commands/logs.
- Plaintext exposure limited to the protected workspace; no debug dumps or exported credential contents in console/repository.
- Ciphertext upload/checksum/object-generation verification and a defensible plaintext cleanup/key-disposal process. SSD deletion alone is not proof of erasure.

**Rank 2 — B. Temporary controlled cloud workspace, if local protection cannot be established.** Before use verify named isolated environment/custodians, encrypted ephemeral storage, least-privilege temporary credentials, restricted access/network paths, no production outbound notifications, no credential-bearing logs, protected encryption/key recovery, cost budget, and complete teardown/snapshot/cache/key-disposal behavior. Do not assume ordinary Cloud Shell home storage is ephemeral or safely isolated. Its creation/APIs/IAM/cost are a separate approved scope, not part of the bucket minimum.

The ranking is conditional practicality, not a claim the unverified laptop is safe. If A cannot satisfy protection requirements, select B rather than exporting insecurely. For either: export → encrypt → upload ciphertext → verify → securely remove plaintext, with password-hash configuration separately protected. No local disk becomes long-term primary custody.

## 10. Remaining decisions and final gate

**PROVISIONING NOT READY.**

- No accessible billing account is available; account-side linkage authority cannot be established.
- No-organization project creation permission/quota is unverified; owner must confirm intended hierarchy.
- Recommended project-name availability is unverified; bucket names were not found but are not reserved.
- Actual export-job identity/enabled state needs the specific console check above, despite confirmed IAM binding and enabled Firestore API.
- Owner must accept recommended names/defaults and name operational custodians, uploader, billing owner and alert recipients. Review exact temporary setup permissions and their removal.
- Auth plaintext protection, capture schedule, isolated restore target and eventual independent second copy remain separately gated.

**Recommended project ID:** `rokter-badhon-backup-7k9m2q`.  
**Recommended bucket name:** `rokter-badhon-backups-7k9m2q`.

**Next safe step:** have the owner verify an accessible OPEN billing account and no-organization project-create/quota status without creating/linking anything; validate proposed project ID in the console form and confirm Firestore's “jobs run as” principal. Then finalize the named-principal/target approval record. We are ready to review those decisions, **not yet ready to request an executable all-in-one provisioning approval**. Individual provisioning, billing, API, IAM and budget mutations must later be explicitly scoped; no export or migration follows automatically. President login remains false and no admin state, access_role or auth_links change is proposed.

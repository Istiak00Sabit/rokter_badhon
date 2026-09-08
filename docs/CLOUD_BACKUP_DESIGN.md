# Rokter Badhon Ghatail — Cloud Backup Design

> **FUTURE / BLAZE OPERATIONAL REFERENCE — NOT ACTIVE IN FREE V1.** Production Architecture v1.2.1, Free V1 Implementation Profile, is FROZEN FOR IMPLEMENTATION on Spark. This document preserves dated cloud planning/verification evidence; it is not a current provisioning, billing, IAM or managed-export requirement or authorization. Current backup procedure: [BACKUP_AND_RECOVERY_PLAN.md](BACKUP_AND_RECOVERY_PLAN.md).

Production Architecture v1.2 remains FROZEN FOR IMPLEMENTATION.  
Operational strategy: **CLOUD-FIRST** — design only, 2026-09-07.

This document controls operational backup topology alongside [BACKUP_AND_RECOVERY_PLAN.md](BACKUP_AND_RECOVERY_PLAN.md). It changes no entity, authentication, capability or application Storage contract. No cloud operation, project/bucket creation, billing upgrade, IAM change, export, upload, restore or migration is authorized or performed.

## 1. Topology and isolation

| Component | Design |
| --- | --- |
| Production source | `rokterbadhon-b247b`; Firestore `(default)` in `asia-south1` |
| Primary backup custody | Dedicated Cloud Storage bucket in a **separate operational Google Cloud project**; project ID and globally unique bucket name remain unselected |
| Recommended bucket location | `asia-south1` |
| Rehearsal destination | A third, separate staging/recovery project; ID unselected; recommend a compatible Firestore database in `asia-south1` |
| Local machine | Temporary protected Auth export/encryption workspace only where required; never the sole long-term production backup |
| Eventual second copy | Independently recoverable restricted cloud project/bucket or encrypted offline media; option/destination not chosen |

The backup project must never be used by Flutter, added to google-services.json/firebase_options.dart, or configured as Firebase application Storage. It supplies no application-facing Firebase permissions. No application users, application runtime service accounts, organization leaders or application developer-admin roles receive bucket access by virtue of their application role.

Restricted operational administrators and independently recoverable custody own the backup project. Production application compromise must not automatically expose that custody. Avoid shared broad administration, application credentials or keys that collapse the separation. A cross-project service-agent grant is a specific operational exception, not an application grant; review its remaining blast radius explicitly.

## 2. Firestore managed export and billing

Preferred path: **production Firestore managed all-document export → backup-project bucket**. Firestore data does not pass through this laptop. BitLocker verification is not a prerequisite for this direct cloud path.

Managed export/import requires billing enabled on the Firestore source/destination project respectively; for the Firebase production source this means Blaze. Export incurs one Firestore read charge per exported document; Cloud Storage charges apply to stored objects. Restore writes and applicable operations/transfers must also be budgeted. Current billing status remains unverified and no billing change is authorized. See [Firebase managed export/import requirements](https://firebase.google.com/docs/firestore/manage-data/export-import).

When billing is separately approved, establish backup-project budgets, alerts, billing ownership and cost review; also monitor production export and staging restore costs. Alerts are monitoring, not an assumed hard spending cap. Choose capture frequency, retention, RPO/RTO and storage class before estimating recurring cost. No monetary estimate is invented from the tiny current dataset.

Use unique run prefixes, retain the complete managed-export hierarchy and terminal operation evidence, and reconcile source drift. Do not normalize legacy fields. Preserve the President's login_enabled false and the admin's original missing fields in backup. Managed export is not a cross-service atomic Firestore/Auth snapshot; retain bounded capture times and reconciliation evidence.

## 3. Required future IAM relationships — no policy created

| Principal | Future relationship / boundary |
| --- | --- |
| Approved export operator | Minimum source-project permissions to initiate/monitor export; no backup-project administration merely because they can export |
| Production **Firestore service agent** | Only necessary access on the dedicated cross-project bucket for managed export; no blanket backup-project role |
| Approved Auth/config uploader | Access needed to upload new encrypted Auth/config/run artifacts and verify them; no automatic deletion, IAM administration or access to unrelated backups |
| Independent backup custodians | Restricted administration/recovery and artifact verification under named custody, separate from app credentials |
| Recovery-project Firestore service agent | Required access to the export artifacts/bucket for the separately authorized cross-project import; not the production agent reused for staging |
| Approved restore operator | Required import/monitoring permissions on the isolated destination, with separately reviewed artifact access |
| Application principals | No bucket grant: neither Firebase users nor application runtime service accounts |

Verify the actual export service-agent identity before granting anything. Its expected naming pattern is `service-PROJECT_NUMBER@gcp-sa-firestore.iam.gserviceaccount.com`; source project number in the inventory is `941165503580`. This is a naming derivation, not a fresh verification of the active agent. Check for legacy App Engine export identity; do not grant access to every default service account.

Firebase documents bucket-scoped Storage Admin for export/import service agents. That role is broad. Select and validate the minimum supported permissions for each workflow before execution; do not assert that object-creator/viewer alone is sufficient without validation. If the supported workflow requires the documented broader bucket role, explicitly review that scope and use bounded access rather than silently granting project-wide Storage Admin. See [service-agent permissions](https://firebase.google.com/docs/firestore/manage-data/export-import#service_agent_permissions).

Review/reduce or remove cross-project access after terminal completion and verification where practical; never revoke mid-operation. An active broad bucket grant can reach more than the intended run, so unique prefixes alone are not an IAM isolation boundary. Evaluate supported conditions/scope controls and operational access windows before selecting the final binding. No IAM JSON, role assignment or impersonation grant is created here.

## 4. Bucket and run design

Logical object layout, **not an actual bucket name**:

```text
rokter-badhon/
  firestore/YYYY-MM-DDTHHMMSSZ_<run-id>/
  auth/YYYY-MM-DDTHHMMSSZ_<run-id>/
  config/YYYY-MM-DDTHHMMSSZ_<run-id>/
  manifests/YYYY-MM-DDTHHMMSSZ_<run-id>/
  verification/YYYY-MM-DDTHHMMSSZ_<run-id>/
```

Use the same logical run ID across categories. Preserve the provider-generated Firestore export filenames/hierarchy beneath its prefix. Runs are immutable by workflow: never overwrite a prior run; corrections produce a new run or separately named supplemental evidence. Unique names alone do not provide enforced retention/WORM protection.

Required proposed controls: uniform bucket-level access, public access prevention, least-privilege IAM, encryption at rest, restricted custodians and no app access. Approve storage class, retention/lifecycle rules, deletion ownership and retention periods before provisioning. Consider object versioning or retention lock only after reviewing cost, accidental-deletion recovery, privacy obligations and irreversible lock implications. Neither is enabled by this design. Encryption/key choice and independent key recovery need an explicit decision; Auth artifacts receive additional artifact encryption regardless of bucket at-rest encryption.

The bucket is not Firebase application Storage. Its controls are operational Cloud Storage IAM, not new Flutter Storage rules. Never copy the backup project/bucket into application configuration.

## 5. Auth workflow and temporary plaintext protection

Firebase Auth export is separate from managed Firestore export. Later authorized sequence:

1. Use supported `firebase auth:export`, explicitly scoped to the production project, writing a new file in an approved **temporary protected workspace outside the repository**.
2. Validate coverage privately. The output may contain password hashes/salts and is credential material. Preserve provider/disabled/verification state; do not change accounts to facilitate backup.
3. Encrypt the artifact with an approved authenticated-encryption workflow and recoverable key custody. Do not expose keys/passwords in commands, logs, documentation or process arguments. Protect filenames/metadata as needed.
4. Upload **only the encrypted Auth artifact** to its unique backup-bucket run prefix. Do not upload raw Auth JSON.
5. Verify the encrypted object's checksum, generation, size and successful completion against the local ciphertext; verify authorized decryption/recovery separately without logging contents. Keep plaintext checksums, if needed, inside protected metadata; never publish credential values.
6. After verified upload, securely remove the plaintext temporary artifact and record completion. If upload/verification fails, retain it only within the protected workspace for bounded recovery; do not mark the run complete.

Deletion on an SSD alone is not proof of secure erasure. Approve temporary storage protection and a defensible cleanup method in advance, such as a correctly managed encrypted temporary volume with cryptographic disposal, accounting for snapshots, caches and key copies. BitLocker verification remains desirable before local plaintext storage. If local protection cannot be established, select another controlled protected workspace; cloud-first does not permit an unprotected plaintext intermediate.

Firebase password-hash configuration is also sensitive recovery material. Place it under separate protected custody or a separately encrypted artifact with independent recovery controls; never plaintext in config/manifests. Exports may have algorithm-dependent recovery limits; verify the supported format and credential continuity during rehearsal. See [Firebase Auth import/export](https://firebase.google.com/docs/cli/auth).

## 6. Configuration and verification bundle

Preserve exact deployed Firestore rules/release identity, all index definitions, relevant Firebase configuration, Auth provider/recovery metadata, application/source/version manifest, migration manifest, capture bounds, operation IDs and checksums. Preserve observed absence of local rules files or Storage resources without inventing them. Restrict or encrypt metadata that contains sensitive identity information.

Exclude private keys, OAuth refresh tokens, CLI caches, plaintext secrets and debug payloads. Manifests reference protected recovery material without embedding it. Capture of insecure legacy rules is historical evidence, never approval to restore permissive authorization. Cloud object existence alone does not prove completeness: require operation success, manifest/object reconciliation and isolated restoration.

## 7. Restore isolation and location

Never rehearse into `rokterbadhon-b247b`. Select a separate staging/recovery project, distinct from both production and backup custody, with no app users or outbound production notifications. Confirm the destination database and bucket location compatibility before provision/import; recommend `asia-south1` for both to keep the regional pairing aligned. If another destination location is proposed, check current import constraints and transfer costs rather than assuming any cross-region pairing works. See [moving Firestore data between projects](https://firebase.google.com/docs/firestore/manage-data/move-data).

The destination Firestore service agent requires reviewed access to the cross-project export bucket; the restore operator needs destination import permissions. Inspect exact principals and current required scope, then time-bound/reduce access where practical. No project creation, service-agent grant or import is authorized. Keep immutable originals, validate raw types/IDs and disabled states, and test admin recovery in isolation. Preserve original export metadata layout when copying artifacts for restoration.

## 8. Second independently recoverable copy

After the primary cloud backup is verified, the eventual production policy includes a second independently recoverable copy. Options are another restricted cloud project/bucket or encrypted offline external media. Neither is selected or created. Approve distinct custody, encryption/key recovery, region/media failure coverage, retention and checksum/restore verification. Same-laptop partitions and a second prefix under identical custody are not an independent recovery strategy. Pending second-copy selection does not require falling back to local-first or block designing the first cloud capture; full recovery readiness must track it separately.

## 9. Decisions and exact next safe step

Pending decisions: named owner/backup and recovery custodians; actual backup project ID and bucket name; billing owner and explicit source Blaze approval; budgets/alerts; bucket controls, storage class and retention; least-privilege supported IAM scope; Auth temporary workspace, encryption/key custody and cleanup; capture schedule/RPO/RTO; staging project/location; second-copy choice. Do not infer approval of any from this document.

**NEXT SAFE STEP:** have the owner complete a non-secret design decision record naming the backup/recovery custodians and proposed project/bucket identities, billing owner and budget, retention, and Auth protected-workspace method. Then perform separately permitted read-only validation of existing billing, service-agent identities and organization constraints. No project, billing, bucket, IAM or export mutation follows automatically. Present a concrete provisioning change set for separate approval only after those decisions are reviewed.

Current outcome: cloud topology approved as a strategy; execution **NOT READY** until resource/custody/billing/IAM gates are resolved. Local encryption uncertainty does not block direct Firestore export once its cloud gates pass, but Auth temporary-plaintext handling remains gated. The existing administrator and President remain unchanged; no access_role or auth_links operation is part of this strategy change.

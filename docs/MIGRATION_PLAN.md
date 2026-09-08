# Rokter Badhon Ghatail — Migration Plan

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: FROZEN FOR IMPLEMENTATION

## 1. Scope and Execution Boundary

This is the future migration plan from the audited Flutter/Firebase implementation to the frozen v1.2.1 architecture. It does not execute migration, implement registration, change rules, or confirm production readiness.

The audit inspected source/configuration, not deployed Firestore data, rules, Auth settings, IAM, or App Check enforcement. Inventory must verify actual deployed state before execution.

No separate Member entity or multi-organization layer is introduced. Prefer additive changes and preserve existing application document IDs and historical references.

## 2. Non-Negotiable Migration Invariants

- users.access_role is the ONLY current application authorization authority.
- Valid roles: developer_admin, leader, executive, committee, member.
- User contains no committee position, committee_year, or auth_uid in the target schema.
- CommitteeAssignment contains committee history only; no authorization field is migrated into it.
- auth_links/{firebaseAuthUid} is the only authoritative authentication mapping.
- One Firebase identity maps to one User; a User has at most one active auth link.
- Missing security-sensitive fields never imply active status, login permission, or a privileged role.
- Required invalid/missing dates never become DateTime.now(); production machine dates are Timestamp.
- Privileged transitions use the required trusted execution and audit evidence.
- Prefer deactivation/archive over destructive deletion when references exist.
- V1.2.1 retains the approved six-field user_directory projection with atomic controlled synchronization; it never grants authorization. No other speculative split or donation archive schema is introduced.
- At most one active assignment per User per term; shared position keys are allowed.
- Ordinary targets are member/committee/executive; listed leader-target account operations are developer_admin-only.
- Own-profile six-field edits and pre-admission E follow CAPABILITY_MATRIX.md.

## 3. Phase 1 — Complete the Implementation Contract

Before implementing production authorization rules:

1. Complete and review the concrete capability matrix in [PERMISSIONS.md](PERMISSIONS.md), including all five roles, target scopes, field allowlists, transitions, and tests.
2. Use draft/published/archived notice states and the approved one-active-assignment-per-User-per-term constraint; do not impose a shared-position occupancy limit.
3. Approve identity-matching and administrative recovery procedures.
4. Apply active user_directory reads and terminal blood-request reads for developer_admin/leader/executive. Validate privacy/retention and the projection's exact field exclusions.
5. Decide how to preserve legacy membership joining dates, unknown audit provenance, and pre-application donation history.
6. Specify and test backend concurrency for auth-link uniqueness and assignment uniqueness, sensitive-workflow idempotency, and the approved atomic User/directory transaction.

Exit: reviewed implementation decisions consistent with the frozen architecture; unresolved capabilities remain denied.

## 4. Phase 2 — Inventory, Backup, and Restore Rehearsal

Capture the actual deployed:

- Firestore collections/documents, field types, references, rules, and indexes.
- Firebase Auth identities, verification/disabled state, and existing linkage evidence.
- Storage data/rules and operational IAM/configuration relevant to recovery.

Identify duplicate or conflicting auth links, ambiguous legacy roles, missing active/login state, malformed dates, orphaned references, and conflicting donor counters/history.

Create access-controlled backups and a migration manifest. Demonstrate restoration in an isolated environment. Minimize personal data in reports.

Exit: restorable backup, reconciled inventory, and explicit unresolved-record list. Source-code references alone are not sufficient evidence of deployed schema.

## 5. Phase 3 — Staging, Security Tests, and Compatible Client

Use an emulator and/or isolated staging Firebase project. Prepare repeatable migration tooling with dry-run output, deterministic mappings, checkpoints, and reconciliation reports.

Prepare compatible readers, revised services/queries, trusted execution workflows, rules, and indexes together. Normal data writes continue through authorized Firestore paths; sensitive account writes cannot remain arbitrary client operations.

Test positive/negative capabilities, malformed/missing values, forged actor/role fields, direct requests bypassing UI, concurrent linking/assignment creation, retry behavior, and revocation. Include admitted own User reads/edits, E's unlinked request-only boundary, directory privacy, and terminal request audiences.

Exit: staging migration and authorization tests pass. Do not grant broad authenticated access to keep old clients working.

## 6. Phase 4 — Explicit Administrative Recovery and Identity Backfill

Verify the intended developer administrator's identity and provision explicit users.access_role, account state, and auth link through the controlled administrative procedure. Use trusted operational controls rather than ordinary application UI. Test recovery before removing the legacy fallback; do not add developer_admin to normal role dropdowns.

Preserve existing User document IDs where possible. An ID equal to an Auth UID may remain as an opaque application ID, but its equality grants no access.

Backfill authoritative auth links from verified evidence. Enforce at most one active link per User. Preserve explicit disabled state. Missing login/active state requires review or explicit denial, never inferred access.

Keep legacy fields temporarily only for controlled compatibility; do not let old and new mappings compete as authorities after cutover.

Exit: verified administrator/recovery access and reviewed link map, with ambiguous identities excluded from automatic activation.

## 7. Phase 5 — User Schema and Role Mapping

| Current field/value | Target handling |
|---|---|
| users.auth_uid | Verified auth_links document; retire legacy field after cutover |
| users.role | Explicit reviewed users.access_role; organizational office separately becomes assignment.position |
| users.committee_year | Verified committee term/assignment mapping |
| users.photo | photo_url after checking URL versus storage-path meaning |
| users.joined_date | Preserve as membership history in the migration archive unless a reviewed schema extension is approved; do not automatically equate it with created_at |
| Legacy uid fields | Resolve their actual meaning before retirement; never use them as implicit identity authority |
| Missing profession/preferred_language | Null where allowed; do not invent values |
| Missing audit fields | Use trustworthy provenance only; unresolved required values block automatic conversion |

Candidate role/position mappings require review:

| Legacy value | Candidate access role | Candidate committee position |
|---|---|---|
| admin | developer_admin only for independently verified system administrators | None |
| president | leader | president |
| vp | executive | vice_president |
| gs | leader | general_secretary |
| assistant_gs | executive | assistant_general_secretary after terminology review |
| treasurer | executive after review | finance_secretary only if organization terminology agrees |
| organizing_secretary | executive | organizing_secretary |
| committee | committee after review | member only where committee membership is evidenced |
| member | member | No assignment unless documented |

These candidates are not permission grants. Historical officeholding does not justify current privilege. Unknown values are quarantined/denied rather than promoted.

Backfill user_directory/{userId} from the authoritative User using only name, phone, blood_group, profession, photo_url, active. Inventory malformed/missing source values; never infer directory active = true. Include this projection in all authorized User write transactions before enabling directory reads. Verify exact field exclusion, ID equality, concurrent retries, and no stale reactivation. Do not add security/sync metadata to directory records.

Exit: validated User schema, reviewed current roles, and synchronized safe directory projections without invented identity, dates, or privileges.

## 8. Phase 6 — Authentication and Authorization Cutover

Coordinate the compatible client, trusted execution, and matching rules:

1. Require verified email, explicit active link/User/login state, and recognized users.access_role.
2. Use only auth_links lookup.
3. Activate v1.2.1 capabilities: own User read; controlled six-field own-profile edits; active directory reads; explicit developer-admin leader-target operations; terminal request reads for developer_admin/leader/executive.
4. Revalidate restored/current sessions and clear protected state on access loss.
5. Remove UID-path login inference, users.auth_uid lookup, and the legacy admin exception.
6. Stop legacy clients from writing outdated or security-sensitive fields.

For controlled testing, a short maintenance window may be safer than prolonged dual writing. Checkpoints must preserve administrative recovery without reintroducing permissive rules.

Exit: all admitted roles pass their allowed/denied tests; disabled, unverified, unlinked, and malformed accounts cannot access protected data.

## 9. Phase 7 — Committee History

Create committee_terms and committee_assignments from verified records. Do not infer a multi-year term's boundaries or a missing year from the current date.

Preserve ended assignments and inactive people needed for history. The assignment schema contains user_id, term_id, position, active, assigned_at, assigned_by, and ended_at only.

Reject duplicate active user_id + term_id assignments before cutover; retain conflicting evidence for review rather than silently choosing a winner. Shared position keys are valid and must not be deduplicated across different Users.

Switch committee views to term/assignment data joined with active user_directory records. Inactive/missing entries do not permit private User-profile fallback.

Retire User position/year fields after reconciliation. Committee changes do not update current access roles automatically.

Exit: verified term/assignment references and history, with no permission effects from committee data.

## 10. Phase 8 — Donors, Donations, Notices, and Requests

| Current collection/field | Target |
|---|---|
| donors.photo | photo_url |
| donors.upazilla | upazila |
| donors.last_donated | last_donated_at as Timestamp/null |
| donors.gender labels | Reviewed stable keys with localized labels |
| donors missing profession/linked_user_id | Null or verified reference |
| donations.donor_name | donor_name_snapshot |
| donations.blood_group | blood_group_snapshot |
| donations.date | donation_date as Timestamp |
| donations.recorded_by | Verified application User ID |
| notices.posted_by | created_by after identity verification |
| notices.date | created_at only after confirming meaning |
| notices missing status | Reviewed state; do not automatically publish |
| requests | blood_requests with preserved IDs and verified schema |

Add missing entity-specific audit fields and nullable fields only with documented provenance/defaults.

Reconcile donor total_donations and last_donated_at against donation events. The old add-donor flow permits a last-donation date without a corresponding event; do not erase legacy history or fabricate events to make counters match.

Preserve event snapshots. Normalize timestamp/string mixtures using explicit timezone handling. Monthly donation queries must use donation_date Timestamp bounds for the start of the month and start of the next month.

Deploy matching notice status/date queries, request queries, ranking queries, and required indexes. Verify counts and prevent missing indexes/permission failures from masquerading as empty data.

Exit: document counts, references, event snapshots, historical totals, and report boundaries reconcile.

## 11. Phase 9 — Localization and Later Registration Work

Localization can proceed alongside the compatible-client phase:

- Default bn, optional en, local preference persistence.
- Stable database keys, localized labels/results/dates.
- Preserved user-entered content.
- No translated label used as an authorization key.

The E contract is now explicit: Firebase-authenticated caller with no auth-link document may create/read only its own request. Input is name/phone/email; Rules constrain auth_uid, token email, pending state, request.time and null decision/linkage fields exactly on create; only trusted execution subsequently changes decision/linkage state. No applicant update/delete/list or overwrite is permitted. E cannot read private/directory Users or business collections.

Implement registration/approval only in a separately authorized future implementation task, after the identity-verification procedure, backend concurrency, and recovery contracts pass tests. This documentation update does not implement registration.

## 12. Phase 10 — Verification, Retirement, and Rollback

Before retiring legacy fields/collections:

- Compare source/target counts and inspect every unresolved record.
- Verify auth-link uniqueness, active assignment uniqueness per User/term, all references, disabled states, and current roles.
- Verify user_directory has exactly the approved safe fields, matches current Users, and becomes inactive atomically with User deactivation.
- Test leader denial on self/leader/admin targets and developer_admin-only approved leader-target actions.
- Test terminal request reads and absence of terminal modification/reopen rights.
- Test concurrent sensitive operations and retried requests.
- Verify audit evidence and restoration.
- Exercise supported APK/AAB clients and session revocation.
- Observe the controlled release through monitoring.

Retain backups/manifests according to the privacy/retention policy. Archive legacy evidence before cleanup; destructive cleanup needs explicit scope and reference review.

Rollback uses a security-compatible client/backend/schema checkpoint or maintenance mode. It must not restore inferred admin access, permissive rules, or ambiguous identity mapping. Account/role revocations made after a checkpoint must be preserved or reconciled before access is reopened.

## 13. Production Exit Gate

Complete [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md), including App Check, Firestore rules tests, denied-by-default Storage and its future enablement gates, release signing, crash monitoring, backup/restore validation, administrative recovery, and privacy/retention policy.

The architecture is frozen; deployment readiness is established only by recorded validation evidence.

## 14. Deferred Operations and Storage Enablement

V1 uses controlled donation-history correction only; no deletion, archive field, or archive collection is added.

NOT ACTIVE IN FREE V1: historical future Storage paths are profile_photos/{userId}/... and donor_photos/{donorId}/.... Do not infer access from a stored photo_url or from path ownership alone. Before any production enablement, define/test readers/writers, file size, MIME/content type, ownership/role restrictions, replacement/removal, account-disable behavior, Storage Security Rules, and App Check.

This migration plan grants no new production Storage access or compatibility exception. Inventory any strictly necessary existing compatibility separately before deciding its exact scope. Unspecified operations remain denied.

## 15. Free V1 Implementation Dependencies

Use Spark Authentication and Firestore only. No billing, Firebase Storage, hosted Functions/Run, managed export/import or paid scheduling is required. The approved phase order in FREE_TIER_IMPLEMENTATION_PLAN remains the implementation roadmap; the phases above describe migration dependencies, not execution authorization.

Before any data cutover: implement and test the local Rules foundation in emulators; review the operator-local trusted tool with independent capability/target/field checks, atomic/idempotent transactions and audit; capture the type-preserving raw Firestore/Auth/config backup and rehearse isolated recovery under BACKUP_AND_RECOVERY_PLAN. Use an emulator or separately approved no-cost isolated environment, never a paid managed import requirement.

Test H exact own-link get independently of admission; E exact create-only fixed-state request without requiring verified email until approval; Q existing-own six-input profile update and exact atomic directory projection. Q client creation/repair, photo/security edits and standalone projection writes remain denied. Privileged changes remain trusted execution.

After committee history and external image abstraction are ready, introduce nullable CommitteeTerm.group_photo_url, committee_media, events and event_media using DATA_MODEL schemas and explicit matrix capabilities. Do not fabricate legacy photos, dates or publication state. Provider remains unselected; operator-only external upload and trusted HTTPS publication initially. Prove parent-hide child visibility, immutable media identity and audit before enabling editorial operations; direct Flutter upload and Firebase Storage stay disabled.

Preserve President login_enabled = false and organization-only status unless independently approved later. No candidate legacy position mapping grants a role. Current evidence remains CURRENT_FIREBASE_INVENTORY; refresh it before any authorized capture rather than rewriting its dated facts.

Terminology for this Free V1 profile: references to backend/server authorization or backend-owned audit mean trusted execution, implemented by the reviewed operator-local tool now; they do not require a hosted paid service. Firestore Rules remain the enforcement path for explicitly permitted ordinary client operations only.

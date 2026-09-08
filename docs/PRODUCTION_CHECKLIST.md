# Rokter Badhon Ghatail — Production Checklist

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: FROZEN FOR IMPLEMENTATION

## 1. Checklist Status and Evidence

All items below are release requirements, not claims of completed implementation. Record an owner, validation evidence, and review date for each completed gate.

Architecture freeze does not mean production readiness. Unresolved authorization decisions block production rules implementation.

## 2. Architecture and Capability Contract

- [ ] users.access_role is the sole current authorization authority; all five roles are validated.
- [ ] User contains no committee position, committee_year, or auth_uid.
- [ ] CommitteeAssignment stores committee history only, with no authorization field.
- [ ] Concrete capability matrix reviewed before production authorization rules implementation.
- [ ] Every operation specifies allow/deny per role, target scope, editable fields, transitions, enforcement path, audit requirement, and tests.
- [ ] Notice states follow the matrix; assignment creation enforces one active assignment per User per term, with shared positions allowed and no global occupancy limit.
- [ ] Active user_directory records expose exactly name, phone, blood_group, profession, photo_url, active; no private/security metadata.
- [ ] Committee/member display joins use user_directory and never broaden private users reads.
- [ ] user_directory is never an authorization input; private users remains authoritative.
- [ ] No position-derived privileges or implicit grants remain.

## 3. Authentication and Trusted Account Workflows

- [ ] Authentication mapping resolves only through auth_links/{firebaseAuthUid}.
- [ ] Verified email, explicit active link/User/login state, and recognized role gate protected access.
- [ ] Missing/malformed security values and dangling/inconsistent links fail closed.
- [ ] One Firebase identity maps to one User; a User has at most one active auth link.
- [ ] Concurrent link creation/replacement tests prove uniqueness enforcement.
- [ ] Concurrent assignment attempts allow only one active User/term assignment; different Users may hold the same position.
- [ ] Approval verifies identity matching before linking to an existing User.
- [ ] E admits only Firebase-authenticated requesters with no auth-link document; inactive/broken links do not qualify.
- [ ] E creates/reads only the caller's exact registration request, with name/phone/email input and Rules-fixed auth_uid/token email/pending/request.time/null decision/linkage fields on create; no extra fields, overwrite, applicant update/delete/list. Verification is required before approval/admission.
- [ ] E cannot read private/directory Users, donors, committee, donations, notices, or blood requests.
- [ ] Applicants cannot select role, position, linked identity, approval, or login state.
- [ ] Approval/rejection, linking, role changes, login changes, and account disablement use authorized trusted execution workflows.
- [ ] Backend verifies current caller/target permissions independently of client rules and assertions.
- [ ] Sensitive Firestore mutations and committed audit evidence are atomic where applicable; retries are idempotent.
- [ ] Existing links/disabled users are not silently replaced/reactivated during approval.
- [ ] Partial Auth/email/Firestore onboarding failures have tested recovery.
- [ ] Registration, when implemented, passes these gates before release.
- [ ] Password reset works; passwords are not transformed, stored, revealed, or logged.
- [ ] Session restoration and ongoing revocation handling prevent unauthorized protected access.
- [ ] Legacy UID-path/admin fallback has been removed after explicit recovery validation.

## 4. Firestore Rules, Queries, and Tests

- [ ] Deployed rules and indexes are captured and reproducible.
- [ ] Rules deny unspecified operations and unauthenticated protected access.
- [ ] Onboarding/status exceptions are limited to the authenticated requester.
- [ ] Direct client security-field/auth-link/audit-log writes are rejected; directory writes are denied except the exact existing-own Q atomic projection.
- [ ] All admitted roles can read only their own private User under own-read capability.
- [ ] Own-profile input permits exactly name, phone, blood_group, profession, address, preferred_language; photo_url/email/security/creation fields are rejected and updated actor/time are Rules-bound.
- [ ] Own-profile Q writes validate exact post-User six-field directory via getAfter; pre-state must be valid, with no client create/repair/standalone directory write. Privileged changes use trusted execution.
- [ ] Terminal request reads allow developer_admin/leader/executive only; no terminal edits/reopening are authorized.
- [ ] Field allowlists, types, references, controlled values, and transitions are validated.
- [ ] Actor and creation metadata cannot be forged or overwritten.
- [ ] Queries match permitted audiences/statuses; local filtering is not relied on for security.
- [ ] Rules tests cover all roles with positive and negative cases.
- [ ] Tests include unverified/pending/rejected/unlinked/disabled users and malformed/missing security fields.
- [ ] Tests include forged role/link/actor fields and direct requests bypassing UI.
- [ ] Independent backend authorization, concurrency, and retry tests pass.
- [ ] Required indexes and Timestamp-based report queries are verified.
- [ ] Permission/index/network failures are distinguishable from empty successful results.

## 5. Data Integrity, History, and Audit

- [ ] All machine dates use Timestamp/null as declared; malformed required dates are rejected.
- [ ] No DateTime.now() fallback fabricates historical dates.
- [ ] Missing security state did not create active accounts or privileges during migration.
- [ ] Legacy identity/role/date mappings and unresolved records have been reviewed.
- [ ] Donation snapshots and legacy counters/history are reconciled without invented events.
- [ ] Calendar reports use validated Asia/Dhaka Timestamp boundaries.
- [ ] Historical references survive permitted deactivation/archive; donation history uses correction only, with no deletion or invented archive schema.
- [ ] User creation/profile/active changes atomically synchronize the exact directory projection; stale retries/repairs cannot reactivate a disabled directory entry.
- [ ] Privileged security/business actions produce trustworthy audit_logs.
- [ ] Audit records are backend-owned, minimal, append-only during retention, and correlated for retries.
- [ ] Audit readers and retention are explicitly authorized.
- [ ] No passwords, tokens, verification links, or unnecessary personal data appear in audit/error logs.

## 6. External Images and Inactive Firebase Storage

- [ ] Firebase Storage is unused/denied in Free V1; older profile_photos/donor_photos paths are NOT ACTIVE IN FREE V1.
- [ ] Provider remains unselected until free-tier, credential, content/size/type, deletion/replacement, privacy and stable-URL review passes.
- [ ] Direct Flutter upload is disabled; no reusable provider secret enters APK, Firestore or logs.
- [ ] Authorized operator uploads and validates content; explicit trusted editorial capabilities publish HTTPS URLs with audit.
- [ ] Profile null/load error uses a bundled local avatar; replacement remains usable if old-provider deletion fails.
- [ ] Gallery parent/asset identity is immutable, required dates are validated, historical media retained and no biometric data stored.
- [ ] Active/hidden event and media audiences and parent-hide child-read tests pass without rewriting every child.
- [ ] Every event/media mutation has an explicit matrix row; hard deletion and unlisted operations deny.

## 7. Firebase App Check

- [ ] App Check is integrated for supported production services.
- [ ] Legitimate controlled APK and Play release clients are validated.
- [ ] Enforcement is enabled after validation; debug bypass is not production policy.
- [ ] Monitoring distinguishes rejected abuse from legitimate-client failures.
- [ ] Authentication, rules, and backend capability checks remain independently enforced.

## 8. Release Signing and Distribution

- [ ] Production application identity/configuration is finalized.
- [ ] Release uses protected production signing, not debug signing.
- [ ] Signing credentials and recovery access are controlled.
- [ ] Controlled APK and production AAB builds pass end-to-end tests.
- [ ] Old incompatible clients cannot continue unsafe legacy writes.
- [ ] Play Store release preparation and required privacy disclosures are complete.

## 9. Crash Monitoring and Operational Security

- [ ] Crash monitoring and actionable backend error reporting are enabled.
- [ ] Logs/crash reports redact sensitive account, donor, and patient information.
- [ ] Users see localized safe errors rather than raw backend exceptions.
- [ ] Alerts and operational ownership exist for authorization failures, audit failures, and abuse/cost anomalies.
- [ ] Backend/IAM permissions are least-privilege and production access is controlled.
- [ ] Testing/migration environments are isolated from production data and configuration.

## 10. Current Free-V1 Backup and Restore Validation

Follow BACKUP_AND_RECOVERY_PLAN. Cloud managed export/provisioning documents are FUTURE / BLAZE OPERATIONAL REFERENCE, not current release prerequisites.

- [ ] Approved operator, protected temporary workspace, encryption/key custody and independent no-cost cloud/offline destination are concrete.
- [ ] Reviewed raw Firestore capture preserves all paths/subcollections and native types, missing/null/false distinctions, pagination and capture consistency.
- [ ] Supported Auth export and protected recovery/hash configuration coverage are verified; no credentials are printed or committed.
- [ ] Deployed Rules/index/config, source/version and migration manifests and checksums are captured.
- [ ] Encrypted artifacts and an independently recoverable copy are verified; this laptop is not sole custody.
- [ ] An explicitly approved isolated raw restore rehearsal passes; emulator limitations, especially Auth credential continuity, are recorded.
- [ ] Manual checkpoints precede major migration/release; privacy/retention, rollback and later revocation reconciliation are verified.
- [ ] No managed export/import, billing, paid backup resource or Firebase Storage is needed for the current path.

## 11. Administrative Recovery

- [ ] Developer-admin identity/link is explicitly verified and provisioned through trusted operational controls, never ordinary application UI.
- [ ] developer_admin is absent from normal role-assignment dropdowns.
- [ ] Administrative strong authentication, recovery custodians, and least-privilege access are documented.
- [ ] Leaders cannot grant, take over, relink, or disable developer-admin identities.
- [ ] Leaders cannot change leader roles or manage leader/self login, active state, or auth links.
- [ ] Only developer_admin may invoke the explicitly listed leader-target account operations.
- [ ] Accidental loss of all administrative recovery access is prevented.
- [ ] Recovery and compromised-account/link replacement have been rehearsed and audited.
- [ ] Recovery never depends on missing-field privileges or the legacy admin exception.

## 12. Privacy, Retention, and Offline Data

- [ ] Collection audiences are suitable for every field returned to them.
- [ ] Donor contact/blood data, patient/recipient details, requests, photos, and audit data have approved collection/use policies.
- [ ] Privacy/retention policy defines archive, deletion, historical-reference, and rejected-request handling.
- [ ] Retention-driven deletion uses an explicit reviewed procedure.
- [ ] Shared-device, logout/account switching, local cache, and offline behavior are documented and tested.
- [ ] Disable/revocation messaging does not imply already downloaded data can be retracted.
- [ ] Any future field-level audience split receives a deliberate architecture review.

## 13. Localization and Final Release Review

- [ ] First launch defaults to Bangla (bn); English (en) is available.
- [ ] Local language preference persists and changes without reinstalling.
- [ ] Production labels, validation, dialogs, statuses, dates, and counts are localized.
- [ ] Controlled keys and permissions remain unchanged by language selection.
- [ ] User-generated content remains unchanged.
- [ ] Current model tests and end-to-end tests cover the implemented production flows.
- [ ] Migration reconciliation, security tests, recovery, monitoring, and controlled release evidence are reviewed.
- [ ] Every required gate above is complete before production release.

## 14. Free-V1 Trusted Execution and Session Exceptions

- [ ] Reviewed local trusted tool is operator-only, not Flutter/distributed, uses approved operational credentials and independently enforces capability, target, state and field contracts; administrative SDK access does not rely on Rules.
- [ ] Required state/audit transactions are atomic and idempotent, fail closed and have concurrency/retry tests. Sequential Console writes do not substitute for them.
- [ ] audit_logs rejects every direct Flutter write; ordinary Rules-bound actor/time metadata is not privileged audit evidence.
- [ ] H permits only authenticated exact own auth-link get; no list, other-link read or mutation. H alone does not admit anyone.
- [ ] President remains organization-only/login-disabled; developer_admin recovery remains protected and absent from normal UI.
- [ ] Spark quotas and App Check provider limits are assessed; no hosted paid execution or scheduler is required for release.

Terminology for this Free V1 profile: references to backend/server authorization or backend-owned audit mean trusted execution, implemented by the reviewed operator-local tool now; they do not require a hosted paid service. Firestore Rules remain the enforcement path for explicitly permitted ordinary client operations only.

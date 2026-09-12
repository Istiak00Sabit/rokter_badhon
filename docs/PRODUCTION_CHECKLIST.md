# Rokter Badhon Ghatail — Production Checklist

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: CODE RELEASE CANDIDATE — PRODUCTION GATES OPEN

## 1. Checklist Status and Evidence

All items below are release requirements, not claims of completed implementation. Record an owner, validation evidence, and review date for each completed gate.

Architecture freeze does not mean production readiness. Unresolved authorization decisions block production rules implementation.

For checked code-only gates below, implementation/review evidence is the release-candidate lineage beginning at commit `4e8e767`, including the commit that contains this checklist update, plus the 2026-09-11–12 release-candidate audits: 73 Flutter model/service/source checks, 94 trusted-operator tests, 82 Firestore Rules emulator tests, full Flutter frontend compilation, 81-file analyzer validation with zero diagnostics, dependency/legacy/secret scans, and clean diff checks. Implementation reviewer: Codex. Production, owner-account, policy, device, signing, provider, deployment and migration gates remain deliberately unchecked.

Unchecked-item classification was repeated on 2026-09-12. Category A means repository code, local test, emulator, or synthetic trusted-tool evidence can complete the gate; every identified Category A gate is now checked. Every remaining unchecked item is labeled **[B—OWNER/PRODUCTION]** and states the external evidence required. An unchecked B item must never be inferred complete from synthetic evidence.

## 2. Architecture and Capability Contract

- [x] users.access_role is the sole current authorization authority; all five roles are validated.
- [x] User contains no committee position, committee_year, or auth_uid.
- [x] CommitteeAssignment stores committee history only, with no authorization field.
- [x] Concrete capability matrix reviewed before production authorization rules implementation.
- [x] Every operation specifies allow/deny per role, target scope, editable fields, transitions, enforcement path, audit requirement, and tests.
- [x] Notice states follow the matrix; assignment creation enforces one active assignment per User per term, with shared positions allowed and no global occupancy limit.
- [x] Active user_directory records expose exactly name, phone, blood_group, profession, photo_url, active; no private/security metadata.
- [x] Committee/member display joins use user_directory and never broaden private users reads.
- [x] user_directory is never an authorization input; private users remains authoritative.
- [x] No position-derived privileges or implicit grants remain.

## 3. Authentication and Trusted Account Workflows

- [x] Authentication mapping resolves only through auth_links/{firebaseAuthUid}.
- [x] Verified email, explicit active link/User/login state, and recognized role gate protected access.
- [x] Missing/malformed security values and dangling/inconsistent links fail closed.
- [x] One Firebase identity maps to one User; a User has at most one active auth link.
- [x] Concurrent link creation/replacement tests prove uniqueness enforcement.
- [x] Concurrent assignment attempts allow only one active User/term assignment; different Users may hold the same position.
- [x] Approval verifies identity matching before linking to an existing User.
- [x] E admits only Firebase-authenticated requesters with no auth-link document; inactive/broken links do not qualify.
- [x] E creates/reads only the caller's exact registration request, with name/phone/email input and Rules-fixed auth_uid/token email/pending/request.time/null decision/linkage fields on create; no extra fields, overwrite, applicant update/delete/list. Verification is required before approval/admission.
- [x] E cannot read private/directory Users, donors, committee, donations, notices, or blood requests.
- [x] Applicants cannot select role, position, linked identity, approval, or login state.
- [x] Approval/rejection, linking, role changes, login changes, and account disablement use authorized trusted execution workflows.
- [x] Backend verifies current caller/target permissions independently of client rules and assertions.
- [x] Sensitive Firestore mutations and committed audit evidence are atomic where applicable; retries are idempotent.
- [x] Existing links/disabled users are not silently replaced/reactivated during approval.
- [x] Partial Auth creation, verification-email, Firestore request-write, and post-commit sign-out failures have injected recovery tests; Firestore failure retains the authenticated identity for an exact retry without reporting a submitted request.
- [x] Registration, when implemented, passes these code and emulator gates before release.
- [x] Password reset is wired through Firebase Auth; passwords are not transformed, stored, revealed, or logged.
- [x] Startup and app-resume session refresh fail closed for disabled User, disabled login, inactive/missing/malformed link or User, invalid role, Auth/error state, and an already-authenticated user losing access; a role change forces reauthentication and local protected state clears even if remote sign-out fails.
- [x] Legacy UID-path/admin fallback has been removed and synthetic recovery validation passes.

## 4. Firestore Rules, Queries, and Tests

- [ ] **[B—OWNER/PRODUCTION]** Capture the actually deployed production Rules, indexes, single-field settings, Firebase project/database identity, release/version and checksums; evidence requires an authorized production read and comparison with reviewed source.
- [x] Rules deny unspecified operations and unauthenticated protected access.
- [x] Onboarding/status exceptions are limited to the authenticated requester.
- [x] Direct client security-field/auth-link/audit-log writes are rejected; directory writes are denied except the exact existing-own Q atomic projection.
- [x] All admitted roles can read only their own private User under own-read capability.
- [x] Own-profile input permits exactly name, phone, blood_group, profession, address, preferred_language; photo_url/email/security/creation fields are rejected and updated actor/time are Rules-bound.
- [x] Own-profile Q writes validate exact post-User six-field directory via getAfter; pre-state must be valid, with no client create/repair/standalone directory write. Privileged changes use trusted execution.
- [x] Terminal request reads allow developer_admin/leader/executive only; no terminal edits/reopening are authorized.
- [x] Field allowlists, types, references, controlled values, and transitions are validated.
- [x] Actor and creation metadata cannot be forged or overwritten.
- [x] Queries match permitted audiences/statuses; local filtering is not relied on for security.
- [x] Rules tests cover all roles with positive and negative cases.
- [x] Tests include unverified/pending/rejected/unlinked/disabled users and malformed/missing security fields.
- [x] Tests include forged role/link/actor fields and direct requests bypassing UI.
- [x] Independent backend authorization, concurrency, and retry tests pass.
- [x] Required source indexes and Timestamp-based report query shapes are verified.
- [x] Permission/index/network failures are distinguishable from empty successful results.

## 5. Data Integrity, History, and Audit

- [x] All machine dates use Timestamp/null as declared; malformed required dates are rejected.
- [x] No DateTime.now() fallback fabricates historical dates.
- [ ] **[B—OWNER/PRODUCTION]** Reconcile production migration results and prove that missing security state created no active account or privilege; evidence requires authorized pre/post manifests and audit records.
- [ ] **[B—OWNER/PRODUCTION]** Approve every real legacy identity/role/date mapping and unresolved record; evidence requires a dated owner-reviewed production reconciliation report.
- [ ] **[B—OWNER/PRODUCTION]** Reconcile real donation snapshots, counters and history without invented events; evidence requires production source totals, exceptions and reviewer sign-off.
- [x] Calendar reports use validated Asia/Dhaka Timestamp boundaries.
- [x] Historical references survive permitted deactivation/archive; donation history uses correction only, with no deletion or invented archive schema.
- [x] User creation/profile/active changes atomically synchronize the exact directory projection; stale retries/repairs cannot reactivate a disabled directory entry.
- [x] Privileged security/business actions produce trustworthy audit_logs.
- [x] Audit records are backend-owned, minimal, append-only during retention, and correlated for retries.
- [x] Audit readers are explicitly authorized; production retention policy remains an owner gate.
- [x] No passwords, tokens, verification links, or unnecessary personal data appear in audit/error logs.

## 6. External Images and Inactive Firebase Storage

- [x] Firebase Storage is unused/denied in Free V1; older profile_photos/donor_photos paths are NOT ACTIVE IN FREE V1.
- [x] Provider remains unselected until free-tier, credential, content/size/type, deletion/replacement, privacy and stable-URL review passes.
- [x] Direct Flutter upload is disabled; no reusable provider secret enters APK, Firestore or logs.
- [ ] **[B—OWNER/PRODUCTION]** Select and approve the external image provider, operator account and content/privacy/deletion policy, then demonstrate a validated upload and audited HTTPS URL publication in a controlled environment.
- [x] Profile null/load error uses an app-local initials avatar; URL replacement remains usable independently of old-provider deletion.
- [x] Gallery parent/asset identity is immutable, required dates are validated, historical media retained and no biometric data stored.
- [x] Active/hidden event and media audiences and parent-hide child-read tests pass without rewriting every child.
- [x] Every event/media mutation has an explicit matrix row; hard deletion and unlisted operations deny.

## 7. Firebase App Check

- [ ] **[B—OWNER/PRODUCTION]** Select/configure App Check providers for the real Firebase apps and integrate their production configuration; evidence requires owner-controlled Firebase configuration and release-client attestation.
- [ ] **[B—OWNER/PRODUCTION]** Validate legitimate signed APK and Play release clients against App Check; evidence requires device/build matrix results and Firebase metrics.
- [ ] **[B—OWNER/PRODUCTION]** Enable App Check enforcement only after validation and prove no production debug bypass; evidence requires exported enforcement configuration and rollback procedure.
- [ ] **[B—OWNER/PRODUCTION]** Configure monitoring that distinguishes rejected abuse from legitimate-client failures; evidence requires alert routing and an exercised test signal.
- [x] Authentication admission, Firestore Rules, and trusted-operator capability/target/state validation remain independently enforced in source and local/emulator tests.

## 8. Release Signing and Distribution

- [ ] **[B—OWNER/PRODUCTION]** Finalize the production package/application identity and Firebase app configuration; evidence requires owner approval and matched Firebase/Android configuration.
- [ ] **[B—OWNER/PRODUCTION]** Build with protected production signing rather than debug signing; evidence requires signed-artifact verification.
- [ ] **[B—OWNER/PRODUCTION]** Establish signing-key custody, access and recovery; evidence requires named custodians and a rehearsed recovery record.
- [ ] **[B—OWNER/PRODUCTION]** Pass controlled signed APK and production AAB end-to-end tests; evidence requires artifact hashes, device matrix and results.
- [ ] **[B—OWNER/PRODUCTION]** Deploy the strict Rules/client cutover and prove incompatible clients cannot make unsafe legacy writes; local emulator denial is complete, but production deployment/version evidence is required.
- [ ] **[B—OWNER/PRODUCTION]** Complete Play Store preparation and required privacy/data-safety disclosures; evidence requires owner-approved store records.

## 9. Crash Monitoring and Operational Security

- [ ] **[B—OWNER/PRODUCTION]** Select, configure and exercise crash monitoring/actionable operational error reporting; evidence requires a controlled release signal and named responder.
- [ ] **[B—OWNER/PRODUCTION]** Verify configured production logs/crash reports redact sensitive account, donor and patient information; source exposes only safe localized UI errors, but provider-side captured-event evidence is required.
- [x] Users see localized safe errors rather than raw backend exceptions.
- [ ] **[B—OWNER/PRODUCTION]** Configure alerts and operational ownership for authorization failures, audit failures and abuse/cost anomalies; evidence requires routing, thresholds and an exercised notification.
- [ ] **[B—OWNER/PRODUCTION]** Review production backend/IAM least privilege and access controls; evidence requires an authorized IAM export and owner approval.
- [x] Automated test environments use the explicit `demo-*` project and emulator guards; production configuration was not contacted.

## 10. Current Free-V1 Backup and Restore Validation

Follow BACKUP_AND_RECOVERY_PLAN. Cloud managed export/provisioning documents are FUTURE / BLAZE OPERATIONAL REFERENCE, not current release prerequisites.

- [ ] **[B—OWNER/PRODUCTION]** Name the approved operator/custodians and verify a protected temporary workspace, encryption/key recovery and independent no-cost destination; evidence requires owner approval and access/recovery checks.
- [ ] **[B—OWNER/PRODUCTION]** Review and run an authorized raw Firestore capture that preserves every path/subcollection, native type, missing/null/false distinction, page and consistency bound; evidence requires manifests, checksums and reconciliation.
- [ ] **[B—OWNER/PRODUCTION]** Verify supported Auth export plus protected recovery/hash configuration coverage without logging credentials; evidence requires encrypted artifacts and a coverage report.
- [ ] **[B—OWNER/PRODUCTION]** Capture deployed Rules/index/config, source/version, migration manifests and checksums from the authorized production project.
- [ ] **[B—OWNER/PRODUCTION]** Verify encrypted artifacts and an independently recoverable second copy; evidence requires checksum and recovery-custodian confirmation outside this laptop.
- [ ] **[B—OWNER/PRODUCTION]** Authorize and pass an isolated raw restore rehearsal, explicitly recording Auth credential-continuity limits and cleanup evidence.
- [ ] **[B—OWNER/PRODUCTION]** Approve manual migration/release checkpoints and verify privacy/retention, rollback and post-checkpoint revocation reconciliation.
- [x] Free V1 source/config/plan requires no managed export/import, billing, paid backup resource, hosted scheduler or Firebase Storage; any data-bearing backup still requires the owner gates above.

## 11. Administrative Recovery

- [ ] **[B—OWNER/PRODUCTION]** Privately verify and provision the real developer-admin identity/link through approved operational controls, never ordinary UI; evidence requires owner/custodian attestation and committed audit reference.
- [x] developer_admin provisioning and role assignment are absent from ordinary Flutter UI/dropdowns; only the guarded local recovery/bootstrap path contains that capability.
- [ ] **[B—OWNER/PRODUCTION]** Approve administrative strong authentication, primary/alternate recovery custodians and least-privilege access; evidence requires named custodians and an exercised recovery route.
- [x] Leaders cannot grant, take over, relink, or disable developer-admin identities.
- [x] Leaders cannot change leader roles or manage leader/self login, active state, or auth links.
- [x] Only developer_admin may invoke the explicitly listed leader-target account operations.
- [ ] **[B—OWNER/PRODUCTION]** Prevent loss of all administrative recovery access; evidence requires independent provider/project recovery custody and a tested break-glass procedure.
- [x] Synthetic recovery and compromised Auth-link replacement are transactionally tested, audited, idempotent, preserve history and deny ambiguous/healthy/ordinary-account takeover states.
- [ ] **[B—OWNER/PRODUCTION]** Rehearse the approved real recovery and compromised-account/link procedure in an isolated owner-controlled environment; evidence requires identities, timestamps, audit references and rollback results.
- [x] Recovery code never depends on missing-field privileges or the legacy admin exception.

## 12. Privacy, Retention, and Offline Data

- [ ] **[B—OWNER/PRODUCTION]** Approve each collection audience against every returned field; evidence requires privacy/security owner sign-off on the field/audience matrix.
- [ ] **[B—OWNER/PRODUCTION]** Approve collection/use policies for donor contact/blood data, patient/recipient details, requests, photos and audit data; evidence requires published policy references.
- [ ] **[B—OWNER/PRODUCTION]** Approve a retention policy covering archive, deletion, historical references and rejected requests; evidence requires owner/legal review and effective dates.
- [ ] **[B—OWNER/PRODUCTION]** Approve and rehearse an explicit retention-driven deletion procedure against non-production data; evidence requires scoped manifests, audits and rollback/retention results.
- [ ] **[B—OWNER/DEVICE]** Test shared-device logout/account switching, Firestore local cache and offline behavior on supported release devices; evidence requires a device matrix including previously cached data.
- [ ] **[B—OWNER/POLICY]** Approve revocation/user messaging that accurately states already downloaded data cannot be retracted; evidence requires reviewed copy and device verification.
- [ ] **[B—OWNER/ARCHITECTURE]** Require documented privacy/security review before any future field-level audience split; evidence belongs to that future change request.

## 13. Localization and Final Release Review

- [x] First launch defaults to Bangla (bn); English (en) is available.
- [x] Local language preference persists and changes without reinstalling.
- [x] Production labels, validation, dialogs, statuses, dates, and counts are localized.
- [x] Controlled keys and permissions remain unchanged by language selection.
- [x] User-generated content remains unchanged.
- [x] Current strict-model/source tests, chained trusted identity workflow, registration recovery workflow and real Firestore Rules emulator admission→revocation flow cover the implemented Free V1 flows practical without production/device credentials.
- [ ] **[B—OWNER/PRODUCTION]** Review production migration reconciliation, recovery rehearsal, monitoring and controlled-release evidence together with the completed local security tests.
- [ ] **[B—OWNER/PRODUCTION]** Record final owner approval only after every B gate above has its required evidence; this is the production-release decision.

## 14. Free-V1 Trusted Execution and Session Exceptions

- [x] Reviewed local trusted tool is outside Flutter/distribution, refuses non-demo projects or missing emulators before Admin SDK initialization, and independently enforces capability, target, state and field contracts without relying on Firestore Rules; all mutation modules transactionally audit and are source-regression tested.
- [ ] **[B—OWNER/PRODUCTION]** Approve the real operator identity, operational credentials, workstation and execution ceremony before adapting the intentionally demo-only tool for any production operation; evidence requires least-privilege custody and dry-run/review records.
- [x] Required state/audit transactions are atomic and idempotent, fail closed and have concurrency/retry tests. Sequential Console writes do not substitute for them.
- [x] audit_logs rejects every direct Flutter write; ordinary Rules-bound actor/time metadata is not privileged audit evidence.
- [x] H permits only authenticated exact own auth-link get; no list, other-link read or mutation. H alone does not admit anyone.
- [x] Synthetic legacy migration tests prove `president` is never an access role, missing security state grants nothing, normal role assignment rejects President, organization-only Users start login-disabled, and developer_admin recovery remains protected outside normal UI.
- [ ] **[B—OWNER/PRODUCTION]** Verify the real President record remains organization-only/login-disabled with no Auth link and approve any eventual mapping; evidence requires an authorized production reconciliation record.
- [x] Source/config dependency review confirms Free V1 has no Cloud Functions, Cloud Run, hosted paid execution, Pub/Sub scheduler, Firebase Storage or direct upload dependency.
- [ ] **[B—OWNER/PRODUCTION]** Assess real Spark usage/quota headroom and selected App Check provider limits against expected traffic; evidence requires current console metrics, projections and owner acceptance.

Terminology for this Free V1 profile: references to backend/server authorization or backend-owned audit mean trusted execution, implemented by the reviewed operator-local tool now; they do not require a hosted paid service. Firestore Rules remain the enforcement path for explicitly permitted ordinary client operations only.

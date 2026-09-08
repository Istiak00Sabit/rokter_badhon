# Rokter Badhon Ghatail — Authentication and Security

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: FROZEN FOR IMPLEMENTATION

## 1. Security Principle

Authentication and authorization are separate. Firebase Authentication establishes identity; users.access_role is the ONLY current application authorization authority.

Protected access additionally requires verified email, an active authoritative auth link, an existing active User, and login_enabled = true. Missing, malformed, or inconsistent security-sensitive values fail closed. Committee position and history never establish permissions.

## 2. Registration Flow

The future registration flow collects full name, phone, email, password, and password confirmation.

Applicants must never choose a committee position or access_role. They cannot approve themselves, select a linked User, or enable login.

Flow:

1. Create a Firebase Authentication account.
2. Send the verification email.
3. Create the exact own registration request through Firestore Security Rules, using name/phone/email and the constrained structural values below.
4. Sign out and await organization approval.

Pre-admission exception E: a Firebase-authenticated requester with no auth_links/{request.auth.uid} document may create their own request and read only that exact request/status. This is identity-based, not a member role or a missing-role privilege default; verified email is not required for E, but remains required for approval and protected admission.

The Firebase-authenticated requester must have NO auth_links/{request.auth.uid} document of any state. E is not an application role. The requester may create only registration_requests/{request.auth.uid}, with applicant-editable name, phone and email. Rules require the complete exact stored schema: auth_uid == request.auth.uid; email == authenticated Firebase token email; status == "pending"; requested_at == request.time using serverTimestamp; approved_by, approved_at, rejected_by, rejected_at and linked_user_id all null. No extra fields, overwrite, applicant update/delete/list or other request access is allowed. The client supplies structural fields, but Rules enforce their single permitted values; they are not applicant choices. Email verification is not required for E, but remains required before approval and protected admission. Own status get remains permitted while unlinked; a present inactive/broken link requires recovery. E grants no private User, directory, committee, donor, donation, notice, blood-request, event or media access. Approval/rejection and all linking remain trusted execution.

E permits no reads of users, user_directory, donors, committee terms/assignments, donations, notices, or blood_requests. A present inactive/broken link does not qualify; use recovery. The read-own exception ends when an auth link exists. Authenticated callers cannot claim an arbitrary userId or role to obtain it.

Auth creation, email delivery, and Firestore persistence are not one transaction. Define retry/recovery for partial failures without creating duplicate requests or granting access. Resending verification must be abuse-controlled.

Passwords must never be stored in Firestore, audit logs, or application logs, or shown to organization leaders. This specification does not mean registration is implemented.

## 3. Approval Flow

Approval/rejection uses a narrowly scoped trusted execution operation; Free V1 uses the reviewed local operational tool, not a hosted endpoint. The concrete capability matrix determines eligible reviewers and permitted target roles.

The backend must:

1. Validate the caller's Firebase identity, email verification, current active link/User state, and specific approval capability.
2. Read authoritative request and Firebase identity information; confirm the applicant's verified email and eligible pending state.
3. Search for an existing organization User and verify identity matching before linking. Submitted name, phone, or email alone is not sufficient proof.
4. Record minimal identity-verification evidence through the audit reason and an approved review procedure; avoid unnecessary identity-document storage.
5. Reuse the verified existing User or create a new User if no match exists. Do not automatically replace an existing link, reactivate a disabled User, or elevate an existing role.
6. Assign users.access_role only within the caller's allowed grant scope. A committee assignment is optional and handled as a distinct committee-history operation.
7. Enforce one active auth link per application User, including concurrent approvals/replacements.
8. Commit the approved request, required User/login/link state, and committed-action audit event atomically within Firestore.
9. Support idempotent retries and reject contradictory or stale decisions.

Link replacement requires its own authorized, identity-verified recovery workflow. A new registration must not silently take over an existing identity.

## 4. Login Flow

Authenticate using email and the password exactly as entered; do not trim or otherwise transform the password.

Then resolve:

Firebase UID → auth_links/{firebaseAuthUid} → user_id → users/{userId}

Require:

- Verified Firebase email.
- Existing link with active = true.
- Existing User with active = true and login_enabled = true.
- A recognized users.access_role.

No users/{authUid} fallback, users.auth_uid query, implicit legacy-admin permission, or position-derived access is allowed.

When no link document exists, E permits the requester's exact own-request/status read. A present inactive/broken link does not qualify for E. A missing request, approved request with a missing link, inactive link, dangling link, or inconsistent state denies application access and routes to controlled recovery where appropriate.

Session restoration uses the same gate as login. Do not open protected screens or initiate protected data loads before it completes.

## 5. Email Verification

Verified email is required for protected production functionality in Flutter, Firestore rules, and trusted execution checks.

Verification refresh must use authoritative Firebase state/token handling. A Firestore email string is not proof of email ownership. An unverified authenticated requester receives only the narrowly defined onboarding access.

## 6. Authorization and Trusted Execution Boundary

All layers implement the reviewed capability matrix from [PERMISSIONS.md](PERMISSIONS.md).

- Flutter: capability-based visibility, navigation, and workflow controls.
- Firestore Security Rules: authoritative enforcement for direct client reads/writes.
- Trusted execution: independent authorization for server operations, which bypass client Security Rules.

The backend owns registration decisions, auth-link creation/replacement, access-role changes, login enable/disable, and privileged account disablement. Clients cannot directly write these security transitions.

Normal application data operations may continue through Firestore where rules authorize them. Keep the trusted layer narrowly scoped; a server wrapper around every normal operation is not required.

Backend authorization resolves the caller through auth_links and users.access_role on each sensitive operation. It never trusts a client-supplied role, actor ID, target permission, or committee position. Authorization changes during a workflow must be detected before committing.

TRUSTED EXECUTION means a reviewed operator-invoked local trusted tool in Free V1, or a hosted trusted backend in a separately approved future Blaze architecture. The local tool is not Flutter, is not distributed to application users and never embeds credentials in the APK. It runs only on an authorized operator machine using approved operational Google/Firebase credentials. It independently enforces capability, caller/target, state, field and provenance rules; implements required atomic/idempotent Firestore transactions and audit evidence; and fails closed. Operational credentials bypass client Security Rules and therefore require independent enforcement and protected custody. Ordinary application roles confer no operational IAM privilege. Sequential Console edits are not an atomic substitute.

H — minimal identity self-read: any Firebase-authenticated identity may get exactly auth_links/{request.auth.uid} to resolve admission, even before G can pass. No list/query, other-link get or client create/update/delete. The identity-based read is not an application role grant, and the link alone never grants admission. Protected operations still require verified email, active link, existing active User, login_enabled true and recognized users.access_role.

## 7. Sensitive Fields and Identity Linking

Protect users.access_role, users.login_enabled, users.active, all auth-link fields, registration decision/linkage fields, and audit logs.

Only trusted execution may change account security state or provider-controlled photo_url. Admitted own-profile direct updates are limited to name, phone, blood_group, profession, address and preferred_language. DATA_MODEL §14 defines exact Q post-state validation and Rules-bound updated metadata. No client security/creation metadata, email, link, active/login/role change, missing-directory creation or repair.



Relationship policy:

- One Firebase Auth identity maps to one application User.
- One application User may have at most one active auth link.
- All link writers use a common backend concurrency strategy that serializes competing operations for the target User. A check-then-write query without concurrency protection is insufficient.
- Relinking deactivates the previous link and preserves audit evidence; it never infers identity from a User document path.

## 8. Developer Administrator and Recovery

developer_admin is a system-level application role, not a committee position or an automatic Firebase/IAM privilege.

Provisioning/recovery is an operational protected procedure using trusted administrative controls, never ordinary application management UI. Do not expose developer_admin in normal role-assignment dropdowns. Holding an application developer_admin role alone is not authority to call an operational provisioning endpoint. Provision it explicitly through an audited operational procedure. Organization leaders cannot grant developer_admin or use profile/link/account operations to take over or disable a developer-admin identity.

Define recovery custodians, strong administrative authentication, least-privilege backend/IAM access, and a tested emergency recovery procedure. Recovery must not depend on the legacy admin login exception or broadly permissive rules. Protect against accidental loss of all recovery access.

## 9. Account States

Registration status: pending, approved, rejected.

User state: active = true/false; login_enabled = true/false.

AuthLink state: active = true/false.

These states have different meanings. A Firebase account with a pending request and no application access is valid. Approval alone does not grant access; the complete current login gate must pass.

Missing or inconsistent values do not imply an active account or any access role. Reject contradictory approval/rejection metadata and fail closed on broken relationships.

## 10. Password Reset

Forgot Password uses Firebase Authentication password reset email.

The app and organization leaders must never reveal or manually assign a user's password. Use localized, non-sensitive responses and control reset abuse. Password reset does not change application roles, approval status, or auth-link ownership.

## 11. Account Disable and Session Lifecycle

active = false, login_enabled = false, or an inactive auth link denies protected access even when Firebase authentication succeeds.

Account-state and permission changes must affect subsequent backend requests. Flutter must observe/revalidate session state, stop protected workflows, and clear protected in-memory state when access is lost.

Define token/session revocation in administrative recovery and account-disable procedures. Server denial cannot retract data already downloaded.

Prefer deactivation/archive over destructive deletion where references exist. Define account-switching, logout, device-cache, offline access, and shared-device handling in the privacy policy.

## 12. Firestore Rules and Validation

Complete and review the concrete capability matrix before production authorization rules are implemented.

Rules must:

- Deny unauthenticated protected access and unknown operations/roles.
- Enforce verified email and explicit active link/User/login state.
- Permit E's exact create-own and status get with rule-fixed state/identity/time; permit H's exact own-link get. Neither grants protected data access.
- Prevent arbitrary User creation, applicant-selected privileges, and direct account-management transitions.
- Protect auth links, security fields, audit logs, and private registration requests.
- Enforce whole-document collection audiences and allowed record scopes, including admitted own User reads and active user_directory reads. Deny directory writes except the exact atomic own-profile Q exception.
- Validate field allowlists, types, controlled values, references, and permitted state transitions.
- Bind actor metadata to the authenticated application User and protect creation metadata.
- Require Timestamp machine dates; never compensate for malformed data with the current time.
- Protect donation history and aggregate consistency.

Rules are not query filters: queries must match permitted result sets. Full-document reads cannot hide individual sensitive fields. V1.2.1 deliberately separates the approved six-field user_directory projection; it never contains private User/security fields or supplies authorization. Use the audiences in [PERMISSIONS.md](PERMISSIONS.md).

Rules tests must cover allowed and denied operations, forged fields, missing values, direct requests bypassing UI, and revoked access. Backend workflows require separate authorization/concurrency tests because server writes bypass client rules.

## 13. Firebase App Check

Integrate Firebase App Check and validate enforcement for supported production services before release.

Validate legitimate controlled APK and Play-distributed clients before enabling enforcement. Do not ship debug bypass configuration as the production policy. App Check complements authentication and authorization; it does not replace them or eliminate all abuse.

## 14. Audit Metadata and Audit Logs

Use the entity-specific created_at/created_by/updated_at/updated_by fields and audit_logs defined in [DATA_MODEL.md](DATA_MODEL.md).

V1 requires trusted audit evidence for privileged security/business actions, including registration decisions, auth linking, role/login changes, privileged disablement, committee changes, donor deactivation/archive, and historical donation correction.

Committed sensitive Firestore changes and their audit events must be atomic where possible. Other privileged business operations require reliable backend capture, retries, and deduplication. Clients cannot forge, alter, or delete audit events.

Use server timestamps, authenticated actor identities, correlation IDs, and minimal relevant changes. Never log passwords, tokens, or unnecessary personal data. Define privileged audit-reader scopes and retention.

## 15. Storage and Production Operations

Before release require:

- Firebase Storage is unused and denied in Free V1; no compatibility exception is granted. Legacy future paths profile_photos/{userId}/... and donor_photos/{donorId}/... are NOT ACTIVE IN FREE V1. Before production enablement, approve and test readers/writers, size limits, MIME/content type, ownership/role checks, replacement/removal, account-disable behavior, Storage Security Rules, and App Check.
- Production signing and protected signing credentials.
- Crash monitoring with redacted errors and logs.
- Backups and a successful isolated restore rehearsal.
- Tested administrative recovery and least-privilege operational access.
- Privacy/retention policy covering donors, patients, registration requests, photos, audit logs, and cached data.
- Controlled release validation and abuse/cost monitoring.

Do not turn permission errors into successful empty results or expose raw backend exceptions to users. See [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md).

## 16. Leader Targets, Directory Updates, and Committee Uniqueness

Ordinary targets are member, committee, executive. A leader may manage them only under explicit matrix capabilities and may not use account-management operations on self, another leader, or developer_admin.

Explicit leader-target disable/reactivate, login enable/disable, and auth-link create/replace operations are developer_admin-only trusted execution capabilities. Existing developer_admin targets remain exclusively operational/protected, not generic application targets.

All authoritative User writes satisfy Q in DATA_MODEL §14: narrow Rules-constrained own-profile exception; trusted execution for privileged changes/repair. Role/login fields never enter the projection; User.active updates propagate atomically. A directory record's content or existence never grants access.

committee.assign enforces at most one active assignment per user_id + term_id under concurrent creation. Multiple Users may hold the same position key, with no global occupancy limit. Assignment lifecycle still cannot change users.access_role.

Terminal blood-request reads are developer_admin/leader/executive only and never authorize terminal modification. Donation hard deletion is denied; V1 uses historical correction by developer_admin/leader and introduces no donation archive schema.

## 17. Free-V1 Enforcement and External Media

Spark/no-cost only. No Firebase Storage, hosted Functions, Cloud Run, managed paid export/import or scheduler is required for current V1. H — minimal identity self-read: any Firebase-authenticated identity may get exactly auth_links/{request.auth.uid} to resolve admission, even before G can pass. No list/query, other-link get or client create/update/delete. The identity-based read is not an application role grant, and the link alone never grants admission. Protected operations still require verified email, active link, existing active User, login_enabled true and recognized users.access_role.

External provider remains unselected. Initial operator upload/content validation/trusted editorial HTTPS publication contains no reusable secret in Flutter. No direct app upload; provider URLs never authorize. Event/media reads and trusted editorial actions use explicit matrix rows, no position-derived authority. Direct audit_logs writes remain denied. Rules-constrained ordinary writes may carry validated actor/time metadata; that is not privileged tamper-resistant audit evidence. Trusted operational writes require independent authorization, atomic/idempotent transactions and trustworthy audit/custody. President remains organization-only/login-disabled unless independently approved later.

Terminology for this Free V1 profile: references to backend/server authorization or backend-owned audit mean trusted execution, implemented by the reviewed operator-local tool now; they do not require a hosted paid service. Firestore Rules remain the enforcement path for explicitly permitted ordinary client operations only.

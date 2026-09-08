# Rokter Badhon Ghatail — Permission Model

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: FROZEN FOR IMPLEMENTATION

## 1. Access Roles and Authority

users.access_role is the ONLY current application authorization authority.

Valid roles:

- developer_admin
- leader
- executive
- committee
- member

A valid role is necessary but not sufficient: verified email, an active auth link, active User, and login_enabled = true are also required for protected access.

Committee position, assignment history, term status, and client-supplied values never grant permissions. Missing or unknown roles fail closed.

## 2. Developer Admin

Purpose: system-level application administration and emergency recovery.

The role is eligible only for the explicit application capabilities in the matrix, including the listed leader-target account operations. Developer-admin provisioning/recovery is an operational protected procedure, not a capability exposed by normal application management UI; developer_admin must not appear in ordinary role-assignment dropdowns.

It is not a committee position, a Security Rules bypass, or an automatic Firebase Console/IAM grant. Administrative recovery must be explicitly provisioned, tested, and audited.

## 3. Leader

Purpose: authorized organization management.

The matrix may grant organization-user viewing, registration review, committee management, permitted role assignment, and donor/donation/notice/blood-request management.

Constraints:

- Cannot grant developer_admin.
- Cannot take over, relink, or disable a developer-admin identity.
- Cannot bypass the trusted execution for account management.
- Ordinary targets are member, committee, executive. May act on them only where the matrix permits.
- Cannot change another leader's role, disable/reactivate a leader, enable/disable a leader's login, or create/replace a leader's auth link.
- Cannot perform these account-security operations on self. Explicit leader-target account operations are developer_admin-only.

President, Senior Vice President, and General Secretary are organizational offices often associated with leadership responsibilities, but none automatically confers this software role.

## 4. Executive

Purpose: donor, donation, and blood-request operations.

The matrix may grant committee viewing, donor viewing/creation/editing, donation recording/history viewing, notice viewing, and specified blood-request transitions.

No account approval, auth-link management, access-role assignment, login management, or system-security configuration capability is implied.

Vice President and secretary positions are offices, not authorization inputs.

## 5. Committee

Purpose: committee participation and permitted operational access.

The matrix may grant committee viewing, donor search/viewing, active blood-request viewing, and notice viewing.

Committee donor creation and donation recording are explicitly allowed. Donor editing and donation-history reads remain denied. Committee may create/edit/fulfill/cancel active blood requests as specified in the matrix, but cannot read terminal request history.

No user approval, role assignment, auth-link management, or account management.

## 6. Member

Purpose: ordinary organization participation.

The matrix may grant donor search/viewing within the V1 audience policy, committee viewing, published-notice viewing, and specified blood-request viewing.

Every admitted role may read its own private User and edit only name, phone, blood_group, profession, address, preferred_language through Rules-constrained atomic Q. photo_url is operational/provider-controlled initially. Email, access_role, active, login_enabled, creation metadata, security/audit actor fields, and auth links are forbidden caller inputs. Directory-visible fields synchronize atomically. This does not grant edits to another User.

No user/committee management, privileged donor modification, or authorization changes.

## 7. High-Risk Actions and Enforcement Path

| Operation | Required enforcement path |
|---|---|
| Registration approval/rejection | Authorized trusted execution, verified identity matching for linking, audit event |
| Auth-link creation/replacement | Authorized trusted execution, identity verification, concurrency-safe link uniqueness, audit event |
| Access-role changes | Authorized trusted execution, caller/target/granted-role checks, audit event |
| Login enable/disable | Authorized trusted execution, target-scope checks, audit event |
| Account security-state changes, including privileged disablement | Authorized trusted execution, target-scope and recovery protections, audit event |
| Committee-history changes | Elevated matrix capability, trusted execution, reliable trusted audit evidence |
| Donor deactivation/archive and historical donation correction | Explicit matrix capability, trusted execution only, reliable trusted audit evidence |
| Retention-driven destructive deletion | Explicit reviewed capability and reference/privacy procedure; never implied by edit permission |

Normal application data operations may use Firestore directly when rules authorize them. Server SDK operations require backend authorization independently of client rules.

## 8. Access Role vs Position

Position describes organizational office. users.access_role describes software permission.

For example, a User may have users.access_role = leader and a separate committee assignment whose position = president. Either may change without automatically changing the other.

CommitteeAssignment stores only committee history and contains no authorization data. Historical security changes belong in audit_logs, which are evidence and never a current permission source.

## 9. Mandatory Concrete Capability Matrix

The authoritative V1 operation-level contract is [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md). Use its role decisions, scopes, field allowlists, transitions, enforcement paths, audit requirements, and test cases for Flutter, Firestore Rules, and trusted execution. Its explicit V1 decisions resolve the conditional capabilities below; its documented unresolved gates remain denied until reviewed.

The frozen architecture requires a completed, reviewed capability matrix BEFORE production authorization rules are implemented. Sections 2–6 describe role boundaries, not an executable authorization specification.

Every matrix row must state:

- Stable operation key and target collection/resource.
- Allow or deny for EACH of the five roles.
- Record scope: own, organization-wide, active/published only, or explicit target subset.
- For account management: caller role, existing target role, and proposed role/state.
- Allowed changed fields and forbidden security fields.
- Preconditions, permitted state transitions, and invariant checks.
- Enforcement path: direct Firestore rules or trusted execution.
- Audit requirement and corresponding positive/negative test cases.

The reviewed matrix must cover:

| Capability group | Decisions that must be explicit |
|---|---|
| Users | Own read and six-field own edit; explicit target-scoped account operations; no broad private User reads for directory display |
| Registration | E: authenticated unlinked create/read-own only, server-controlled decision state; reviewer access; approve/reject; retry/reapplication |
| Links and roles | Create/replace/deactivate links; grant/revoke each role; peer/self-management restrictions |
| Committee | Read/assign under at most one active assignment per User per term; shared positions allowed; unlisted lifecycle operations denied |
| Donors | Read/search; create; exact editable fields; user linkage; deactivate/archive |
| Donations | Read history; record; correct history; update aggregates; any archival action |
| Notices | Enumerated status keys; create/edit/publish/archive transitions; published versus unpublished reads |
| Blood requests | Read scopes by status; create/edit/fulfill/cancel; actor/time requirements |
| Audit logs | Reader roles and target scope; no direct client writes; retention procedure |
| Storage | Unused/denied in Free V1; historical future paths are NOT ACTIVE IN FREE V1. External media grants no Storage access. |

No row may remain "manage," "work with," "critical," "permitted," or "policy allows" without the concrete scope and decision. Unresolved entries deny access and block production rules implementation. The matrix cannot override the frozen invariants.

Flutter checks, Firestore rules tests, and trusted-execution authorization tests must derive from the same reviewed matrix. Committee position must never be a matrix authorization input.

## 10. V1 Collection Audiences

"Admitted roles" means the five valid roles after the complete protected-access gate. No collection below is publicly readable.

These are V1 audience boundaries; the concrete matrix specifies exact record and operation scopes within them.

| Collection | V1 read audience |
|---|---|
| users | Own User for admitted users; other-target access only inside explicitly authorized backend account/approval workflows, not broad client listing |
| user_directory | All admitted roles may read active six-field directory records for organization/committee display; never an authorization source |
| committee_terms | Admitted roles, within approved current/history scope |
| committee_assignments | Admitted roles, within approved current/history scope |
| auth_links | Own mapping for identity resolution; authorized developer_admin/leader management through the trusted execution |
| registration_requests | Authenticated requester for own request/status under the onboarding exception; authorized developer_admin/leader reviewers |
| donors | Admitted roles for authorized donor records; all fields in an allowed document are visible to that audience |
| donations | developer_admin, leader, executive for permitted history scopes; no committee/member history access unless explicitly reviewed as an audience revision |
| notices | Admitted roles for published records; authorized developer_admin/leader managers for unpublished records |
| blood_requests | All admitted roles for active records; developer_admin, leader, executive for fulfilled/cancelled records; no terminal mutation/reopen grant |
| audit_logs | developer_admin only in V1; trusted execution is the only writer |

The minimum own-link read needed to resolve a session does not grant protected collection access. It cannot be used to read other identities or mutate mappings.

Committee/member directory views resolve committee_assignment.user_id → user_directory/{userId}. Only active directory records are readable; inactive/missing entries do not permit a private users fallback.

V1.2.1 approves user_directory as a deliberate safe-data split because Firestore reads whole documents. It contains only name, phone, blood_group, profession, photo_url, active; no private/security fields. users remains authoritative. Q preserves exact synchronization: six-field own-profile Rules exception; all privileged User changes/repair use trusted execution. No generic directory writes.

## 11. Denial and Lifecycle Rules

Missing security state, unknown roles, broken links, unapproved transitions, and unspecified operations deny access.

Term rollover does not grant/revoke application roles. Account disablement and login/link revocation are explicit audited operations. Prefer deactivation/archive where references exist.

Role changes and account revocation must be enforced on subsequent backend requests and reflected in Flutter session state. Historical audit logs and committee records never override the current users.access_role.

## 12. Pre-Admission and Storage Boundaries

The Firebase-authenticated requester must have NO auth_links/{request.auth.uid} document of any state. E is not an application role. The requester may create only registration_requests/{request.auth.uid}, with applicant-editable name, phone and email. Rules require the complete exact stored schema: auth_uid == request.auth.uid; email == authenticated Firebase token email; status == "pending"; requested_at == request.time using serverTimestamp; approved_by, approved_at, rejected_by, rejected_at and linked_user_id all null. No extra fields, overwrite, applicant update/delete/list or other request access is allowed. The client supplies structural fields, but Rules enforce their single permitted values; they are not applicant choices. Email verification is not required for E, but remains required before approval and protected admission. Own status get remains permitted while unlinked; a present inactive/broken link requires recovery. E grants no private User, directory, committee, donor, donation, notice, blood-request, event or media access. Approval/rejection and all linking remain trusted execution.

H — minimal identity self-read: any Firebase-authenticated identity may get exactly auth_links/{request.auth.uid} to resolve admission, even before G can pass. No list/query, other-link get or client create/update/delete. The identity-based read is not an application role grant, and the link alone never grants admission. Protected operations still require verified email, active link, existing active User, login_enabled true and recognized users.access_role.

NOT ACTIVE IN FREE V1: legacy future Storage paths are profile_photos/{userId}/... and donor_photos/{donorId}/.... Their names grant no permissions. Unspecified reads/uploads/replacement/removal are denied. No compatibility exception or Firebase Storage capability is active in Free V1. Production enablement requires explicit readers/writers, file size, MIME/type, ownership/role restrictions, replacement/removal behavior, account-disable handling, Storage rules tests, and App Check.

## 13. Free-V1 Trusted Execution and Media Audiences

TRUSTED EXECUTION means a reviewed operator-invoked local trusted tool in Free V1, or a hosted trusted backend in a separately approved future Blaze architecture. The local tool is not Flutter, is not distributed to application users and never embeds credentials in the APK. It runs only on an authorized operator machine using approved operational Google/Firebase credentials. It independently enforces capability, caller/target, state, field and provenance rules; implements required atomic/idempotent Firestore transactions and audit evidence; and fails closed. Operational credentials bypass client Security Rules and therefore require independent enforcement and protected custody. Ordinary application roles confer no operational IAM privilege. Sequential Console edits are not an atomic substitute.

| Collection | Read audience | Editorial authority |
| --- | --- | --- |
| committee_media | Active, existing readable term: all admitted roles; hidden: developer_admin/leader. Past inactive terms remain readable committee history. | Explicit trusted developer_admin/leader add/caption-order/hide rows; no unhide/delete. |
| events | Active: all admitted roles; hidden: developer_admin/leader. | Explicit trusted developer_admin/leader create/edit/hide/cover rows. |
| event_media | Active child with existing readable parent: admitted roles within parent audience. Hidden child/hidden parent review: developer_admin/leader only. | Explicit trusted developer_admin/leader add/caption-order/hide rows on active parents. |

CommitteeTerm group-photo update is an explicit trusted editorial capability for developer_admin/leader, not term create/end authority. Profile-photo URL update uses the dedicated operational row and Q, never a general account-security grant. All URLs are HTTPS/provider-controlled, never authorization. No Firebase Storage or direct Flutter upload. See DATA_MODEL §§15–18 and CAPABILITY_MATRIX §17. Unlisted operations remain denied.

Terminology for this Free V1 profile: references to backend/server authorization or backend-owned audit mean trusted execution, implemented by the reviewed operator-local tool now; they do not require a hosted paid service. Firestore Rules remain the enforcement path for explicitly permitted ordinary client operations only.

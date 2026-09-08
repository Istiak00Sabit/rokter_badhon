# Rokter Badhon Ghatail — Application Architecture

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: FROZEN FOR IMPLEMENTATION

## 1. Product

Full Organization Name:

রক্তের বাঁধন ঘাটাইল

English:

Rokter Badhon Ghatail

The application is a blood donation and organization management system.

Current scope is only Rokter Badhon Ghatail.

Multi-organization support is a possible future feature and must not be implemented yet.

---

## 2. Technology Stack

- Frontend: Flutter / Dart.
- State management: GetX.
- Authentication: Firebase Authentication.
- Database: Cloud Firestore.
- Plan: Firebase Spark / no-cost only; no billing linkage.
- Images: external provider, unselected; HTTPS URLs/non-secret metadata. No Firebase Storage.
- Local preferences: SharedPreferences.
- Sensitive workflows: reviewed operator-invoked local trusted execution.
- Initial distribution: Android APK for controlled testing.
- Production distribution: Google Play Store using Android App Bundle (AAB).

---

Current Free V1 uses no hosted Cloud Functions, Cloud Run, paid managed export/import or paid scheduler/background infrastructure. Security is not weakened to avoid paid services.

TRUSTED EXECUTION means a reviewed operator-invoked local trusted tool in Free V1, or a hosted trusted backend in a separately approved future Blaze architecture. The local tool is not Flutter, is not distributed to application users and never embeds credentials in the APK. It runs only on an authorized operator machine using approved operational Google/Firebase credentials. It independently enforces capability, caller/target, state, field and provenance rules; implements required atomic/idempotent Firestore transactions and audit evidence; and fails closed. Operational credentials bypass client Security Rules and therefore require independent enforcement and protected custody. Ordinary application roles confer no operational IAM privilege. Sequential Console edits are not an atomic substitute.

## 3. Architecture Principles

The application follows separation of concerns:

View → Controller → Service → Firebase / Data Source

- View: UI, input, visual state, and localization.
- Controller: application state, workflow coordination, and validation coordination.
- Service: Firebase communication, persistence, and authentication operations.
- Model: application/domain data.
- Firebase: identity, persistence and Security Rules; privileged workflows use trusted execution.

Business logic must not be embedded in widgets. Firebase calls must not be scattered through views.

Normal application data operations may use Firestore directly through services where Security Rules authorize them. Registration approval, auth-link creation/replacement, access-role changes, login enable/disable, and privileged account disablement use the trusted execution; clients must not perform arbitrary direct writes for these workflows.

---

## 4. Core Business Modules

The application contains these primary modules:

1. Authentication
2. User Management
3. Committee Management
4. Donor Management
5. Donation Management
6. Emergency Blood Request Management
7. Notice Management
8. Dashboard / Reports
9. Profile
10. Settings
11. Localization
12. Events and external photo galleries

---

## 5. Core Domain Entities

- User
- UserDirectory
- CommitteeTerm
- CommitteeAssignment
- AuthLink
- RegistrationRequest
- Donor
- Donation
- Notice
- BloodRequest
- AuditLog
- CommitteeMedia
- Event
- EventMedia

Organization members are Users. A separate Member entity must not be created.

user_directory/{userId} is a deliberately separated safe presentation projection of User. It is never an identity or authorization authority. Committee views resolve assignment.user_id through active user_directory records, not broad private users reads.

CommitteeAssignment stores committee history only. It contains no access-role field or authorization history. Users contain no committee position, committee_year, or auth_uid. See [DATA_MODEL.md](DATA_MODEL.md).

---

## 6. Authentication vs Authorization

Firebase Authentication establishes identity. Authentication success does not automatically grant application access.

The only authoritative authentication mapping is:

Firebase Auth UID → auth_links/{firebaseAuthUid} → users/{userId}

One Firebase Auth identity maps to one application User. One application User may have at most one active auth link.

Protected access requires verified email, an active link, an existing active User, login_enabled = true, and a valid users.access_role. Missing, malformed, or inconsistent security-sensitive values deny access.

---

## 7. Access Roles

users.access_role is the ONLY current application authorization authority.

Valid values:

- developer_admin
- leader
- executive
- committee
- member

Committee position describes organizational office. access_role describes software permission. Position, committee membership, term status, and translated labels never grant access.

Flutter capability checks, Firestore Security Rules, and trusted execution authorization must implement the same concrete capability matrix. That matrix must be reviewed and completed before production authorization rules are implemented; see [PERMISSIONS.md](PERMISSIONS.md).

---

## 8. Committee Positions

Committee positions are stored in CommitteeAssignment using stable language-neutral keys (English identifiers).

Examples:

president
senior_vice_president
vice_president
general_secretary
joint_secretary
assistant_general_secretary
organizing_secretary
assistant_organizing_secretary
publicity_secretary
assistant_publicity_secretary
finance_secretary
assistant_finance_secretary
office_secretary
assistant_office_secretary
sports_cultural_secretary
education_literature_publication_secretary
social_welfare_secretary
religious_affairs_secretary
health_secretary
international_affairs_secretary
environment_secretary
women_affairs_secretary
assistant_women_affairs_secretary
member

UI labels are translated through localization. Assignments contain only committee-history data. A User may have at most one active assignment per CommitteeTerm. Multiple Users may share a position key; V1 imposes no global position occupancy limit. The trusted assignment workflow rejects a second active assignment for the same user + term under concurrency.

Appointment, reassignment, and term rollover do not change users.access_role; any access change is a separate authorized, audited backend operation.

---

## 9. Data Flow

Normal authorized data operation:

User → View → Controller → Service → Firestore Security Rules → Firestore

Sensitive account operation:

Eligible initiator → verified operational instruction → local trusted execution → Firestore

The trusted execution validates identity, current account/link state, capability, target scope, input, and workflow invariants. It does not trust a role or actor ID submitted by the client. Server credentials bypass client Security Rules, so backend authorization is mandatory.

Own-profile client updates use the narrow atomic Q exception in DATA_MODEL §14; privileged User changes and directory repair use trusted execution. H — minimal identity self-read: any Firebase-authenticated identity may get exactly auth_links/{request.auth.uid} to resolve admission, even before G can pass. No list/query, other-link get or client create/update/delete. The identity-based read is not an application role grant, and the link alone never grants admission. Protected operations still require verified email, active link, existing active User, login_enabled true and recognized users.access_role.

Responses return through Service → Controller → reactive state → View. Privileged security/business actions produce audit_logs.

---

## 10. Security Philosophy

UI permission checks improve usability; backend enforcement provides security.

- Deny unspecified operations and missing security-sensitive values.
- Require verified identity matching before linking an applicant to an existing User.
- Applicants never choose their own position or access_role.
- Enforce at most one active auth link per User under concurrent operations.
- Make sensitive workflows retry-safe, with atomic Firestore state changes and audit evidence.
- Prefer deactivation/archive over destructive deletion when historical references exist.
- Define collection audiences in [PERMISSIONS.md](PERMISSIONS.md). The approved user_directory split exposes only name, phone, blood_group, profession, photo_url, and active. A permitted document read exposes every field; private User/security fields must never enter the directory.
- All admitted Users may read their own private User and update only the approved own-profile fields through the Rules-constrained Q exception. Directory-visible changes and deactivation synchronize atomically with the authoritative User.
- Pre-admission requesters have only the explicit create-own/read-own-request contract; it grants no protected collection reads.
- Ordinary targets are member/committee/executive. Leaders cannot manage leader/developer_admin targets or their own account security. Explicit leader-target operations are developer_admin-only; developer-admin provisioning/recovery is operational, outside ordinary application UI.
- Firestore machine dates use Timestamp consistently. Missing/malformed required dates must not become DateTime.now().

---

## 11. UI Independence

UI design is intentionally separated from application logic.

The application may be visually redesigned later without changing:

- authentication
- authorization
- services
- database structure
- domain models
- security rules

UI redesign must not require business-system redesign.

---

## 12. Localization

Default application language: Bangla (bn). Optional language: English (en).

UI text uses localization resources. Controlled database values use stable language-neutral keys, independent of the selected language.

For example, position = "general_secretary" displays as "সাধারণ সম্পাদক" in Bangla and "General Secretary" in English. User-entered content is preserved.

Local language preference is sufficient for V1; see [LOCALIZATION.md](LOCALIZATION.md).

---

## 13. Production Requirements

Production release requires:

- Verified-email authentication for admitted application access, the narrow pre-admission exception, and secure session/account lifecycle.
- Verified identity matching, trusted approval/linking, and administrative recovery.
- A completed capability matrix and consistent client/backend authorization.
- Firestore Security Rules, rules tests, and required query indexes.
- Deny unspecified Storage operations. No new production Storage read/upload grant is made; future profile_photos/{userId}/... and donor_photos/{donorId}/... are NOT ACTIVE IN FREE V1 and would require a reviewed policy and tested Storage rules/App Check before enablement.
- Firebase App Check integration and validated enforcement for supported services.
- Input validation, Timestamp consistency, fail-closed security parsing, and actionable error handling.
- Privileged-action audit_logs and trustworthy write metadata.
- Production release signing and controlled APK/AAB testing.
- Crash monitoring with sensitive-data redaction.
- Backup/restore validation.
- Privacy, retention, archive, and shared-device/offline-data policies.
- Play Store release preparation.

The release gates are recorded in [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md). Architecture freeze does not imply these gates have passed.

---

## 14. Development Rule

This document set is Rokter Badhon Ghatail Production Architecture v1.2.1, Status: FROZEN FOR IMPLEMENTATION.

A change to the frozen architecture requires a documented revision explaining:

1. The problem.
2. The proposed change.
3. Benefits.
4. Trade-offs.
5. Migration impact.

Implementation must preserve working functionality within the frozen security constraints. Unresolved capability entries remain denied and must be concretely reviewed before production authorization rules are implemented.

[MIGRATION_PLAN.md](MIGRATION_PLAN.md) defines the future migration sequence. These documents specify future work; they do not indicate that registration, backend workflows, rules, or data migration have been implemented.

---

## 15. Free-V1 Media and Operational Profile

External URLs never authorize. Initial workflow: authorized operator uploads externally, validates content/consent and records HTTPS URL through the explicit trusted editorial capability. No reusable provider secret in Flutter; no direct Flutter upload until provider-specific review. Null/error profile images use a bundled local avatar. Replacement switches User/directory atomically before old-asset cleanup; cleanup failure must not break the app. Committee covers belong to individual terms; rollover never overwrites historical photos. Events/galleries use explicit matrix audiences and operations. No image bytes/base64 or biometric identification.

Current backups use raw type-preserving Firestore capture, supported Auth export, Rules/index/config manifests, encrypted artifacts and independent no-cost cloud/offline custody. Manual checkpoints precede major migration/release; managed cloud infrastructure is FUTURE / BLAZE OPERATIONAL REFERENCE. Inventory and FREE_TIER_IMPLEMENTATION_PLAN remain preserved evidence/rationale. President remains organization-only/login-disabled unless independently approved later.

Terminology for this Free V1 profile: references to backend/server authorization or backend-owned audit mean trusted execution, implemented by the reviewed operator-local tool now; they do not require a hosted paid service. Firestore Rules remain the enforcement path for explicitly permitted ordinary client operations only.

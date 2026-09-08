# Rokter Badhon Ghatail — Data Model

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: FROZEN FOR IMPLEMENTATION

## 1. User

Collection:

users/{userId}

A User represents a person associated with the organization.

Fields:

name: string
phone: string
email: string | null
blood_group: string | null
profession: string | null
address: string | null
photo_url: string | null

access_role: string

active: boolean
login_enabled: boolean

preferred_language: string | null

created_at: Timestamp
created_by: string | null
updated_at: Timestamp
updated_by: string | null

Important:

User document ID is the application's internal User ID.

Firebase Authentication UID must not be treated as the User ID.

Authentication linking is authoritative only through auth_links/{firebaseAuthUid}.

users.access_role is the ONLY current application authorization authority. Valid values are developer_admin, leader, executive, committee, and member.

User must not contain committee position, committee_year, or auth_uid. It must not duplicate the authentication mapping.

All admitted Users may read their own User. Own-profile input may change only name, phone, blood_group, profession, address, and preferred_language. photo_url is initially operational/provider-controlled. It may not change email, roles, active/login state, creation metadata, audit actors, or auth links. Rules-bound updated_at/updated_by are effects of the own-profile Q exception; privileged changes use trusted execution. Email/account-identity changes need a separate authenticated identity workflow.

Missing or malformed access_role, active, or login_enabled must fail closed. Migration must not infer privileges from absent values.

---

## 2. Committee Term

Collection:

committee_terms/{termId}

Fields:

name: string

Example:
"2025-2027"

start_year: number
end_year: number

start_date: Timestamp | null
end_date: Timestamp | null

active: boolean

group_photo_url: string | null

created_at: Timestamp
created_by: string

Example:

name = "2025-2027"
start_year = 2025
end_year = 2027
active = true

---

## 3. Committee Assignment

Collection:

committee_assignments/{assignmentId}

This stores a user's committee position for a particular term.

Fields:

user_id: string
term_id: string

position: string

active: boolean

assigned_at: Timestamp
assigned_by: string

ended_at: Timestamp | null

Example:

user_id = "USER_001"
term_id = "TERM_2025_2027"
position = "president"
active = true

Reason:

A user's position can change between committee terms.

CommitteeAssignment contains only the committee-history fields listed above. No authorization field is allowed.

Do not store committee positions in User. Appointment, assignment expiry, and term rollover do not grant or revoke software permissions. A change to users.access_role requires a separate authorized backend operation and audit log.

Preserve ended assignments and referenced Users/terms. Per CommitteeTerm, a User may have at most ONE active CommitteeAssignment. Creation must reject a second active assignment for the same user_id + term_id, including concurrent attempts. Ended assignments do not consume the active slot. Multiple Users may share any position key; no global or per-position occupancy limit is imposed in V1. No cross-term uniqueness restriction is introduced. These constraints do not grant term creation, assignment ending, or historical-correction capabilities.

---

## 4. Authentication Link

Collection:

auth_links/{firebaseAuthUid}

Fields:

user_id: string
active: boolean
created_at: Timestamp
created_by: string

Purpose:

Maps Firebase Authentication identity to application User identity. This collection is the sole authoritative mapping.

Relationship policy:

- One Firebase Auth identity maps to one application User.
- One application User may have at most one active auth link.
- user_id must reference an existing User.
- active must be explicitly true for protected application access.
- Link creation/replacement occurs only through the trusted execution, with verified identity matching and concurrency-safe uniqueness enforcement.
- Replacement deactivates the previous active link as part of the controlled workflow. Preserve mapping-change evidence in audit_logs.
- A coincidentally equal User document ID and Auth UID does not establish a link.

Authenticated identity may get exactly its own auth_links/{request.auth.uid} for resolution. No list/query, another-link read or client link write. This read alone never grants admission.

Login lookup:

Firebase Auth UID
    ↓
auth_links/{uid}
    ↓
user_id
    ↓
users/{userId}

---

## 5. Registration Request

Collection:

registration_requests/{firebaseAuthUid}

Fields:

auth_uid: string

name: string
phone: string
email: string

status: string

Values:

pending
approved
rejected

requested_at: Timestamp

approved_by: string | null
approved_at: Timestamp | null

rejected_by: string | null
rejected_at: Timestamp | null

linked_user_id: string | null

Applicants must not select:

- committee position
- access role

Positions and access roles are assigned only through their respective authorized management workflows. A committee assignment is optional and is not a prerequisite for approving an ordinary member.

The Firebase-authenticated requester must have NO auth_links/{request.auth.uid} document of any state. E is not an application role. The requester may create only registration_requests/{request.auth.uid}, with applicant-editable name, phone and email. Rules require the complete exact stored schema: auth_uid == request.auth.uid; email == authenticated Firebase token email; status == "pending"; requested_at == request.time using serverTimestamp; approved_by, approved_at, rejected_by, rejected_at and linked_user_id all null. No extra fields, overwrite, applicant update/delete/list or other request access is allowed. The client supplies structural fields, but Rules enforce their single permitted values; they are not applicant choices. Email verification is not required for E, but remains required before approval and protected admission. Own status get remains permitted while unlinked; a present inactive/broken link requires recovery. E grants no private User, directory, committee, donor, donation, notice, blood-request, event or media access. Approval/rejection and all linking remain trusted execution.


---

## 6. Donor

Collection:

donors/{donorId}

Fields:

name: string
phone: string
blood_group: string
gender: string | null

photo_url: string | null

village: string | null
union: string | null
upazila: string
district: string

profession: string | null

linked_user_id: string | null

active: boolean

last_donated_at: Timestamp | null
total_donations: number

created_at: Timestamp
created_by: string
updated_at: Timestamp
updated_by: string

Important:

A Donor does not need an application login account.

A User may optionally also be linked to a Donor. linked_user_id must reference an existing User when populated.

total_donations is a nonnegative integer count. Counter and last_donated_at updates must follow a consistent, authorized donation-recording/correction policy. Legacy counts/dates may precede recorded events; migration must reconcile rather than discard them.

Prefer active = false over deleting a Donor referenced by Donations. A date-based interval does not establish clinical suitability or current availability.

---

## 7. Donation

Collection:

donations/{donationId}

Fields:

donor_id: string

donor_name_snapshot: string
blood_group_snapshot: string

donation_date: Timestamp

location: string | null
hospital: string | null

recipient_name: string | null
recipient_contact: string | null

recorded_by: string

created_at: Timestamp
updated_at: Timestamp | null

Important:

Donation is an event/transaction.

Do not store donation history directly inside the Donor document.

Snapshots preserve event-time values and must not be overwritten from a later donor profile. recorded_by references the recording application User. Historical corrections require elevated capability and audit evidence. Preserve donor references. V1 permits controlled historical correction by developer_admin/leader only; hard deletion remains denied. No donation archive field or archive collection is introduced.

---

## 8. Notice

Collection:

notices/{noticeId}

Fields:

title: string
body: string

important: boolean

status: string

created_by: string
created_at: Timestamp

updated_by: string | null
updated_at: Timestamp | null

Notice status values are draft, published, archived, with the transitions defined in CAPABILITY_MATRIX.md. Unrecognized/missing statuses must not be exposed as published notices. Do not assume every legacy notice is published.

---

## 9. Blood Request

Collection:

blood_requests/{requestId}

Fields:

blood_group: string

patient_name: string | null
hospital: string
location: string

contact_name: string
contact_phone: string

required_at: Timestamp | null

status: string

Values:

active
fulfilled
cancelled

created_by: string
created_at: Timestamp

fulfilled_by: string | null
fulfilled_at: Timestamp | null

Active request reads are available to all admitted roles. Terminal (fulfilled/cancelled) reads are limited to developer_admin, leader, executive. History read grants no reopen or terminal modification capability. Cancellation and fulfillment preserve historical references and produce audit evidence when privileged. Actor/time metadata for privileged transitions is retained in audit_logs.

---

## 10. Relationship Overview

User
  |
  +---- CommitteeAssignment
  |
  +---- UserDirectory projection (same userId; presentation only)
  |
  +---- at most one active AuthLink
  |
  +---- optional Donor

CommitteeTerm
  |
  +---- many CommitteeAssignments

Donor
  |
  +---- many Donations

RegistrationRequest
  |
  +---- may be linked to an existing User
---

## 11. Audit Log

Collection:

audit_logs/{eventId}

Privileged security/business actions must be recorded for V1. AuditLog is historical evidence, never a source of current authorization.

Minimum event fields:

```text
action: string
actor_user_id: string | null
actor_auth_uid: string | null
target_path: string
occurred_at: Timestamp
operation_id: string
outcome: string
changes: map
reason: string | null
```

- action and outcome use a reviewed stable-key vocabulary.
- changes contains only the minimal relevant before/after values or changed-field evidence, not complete private document copies.
- Actor identity and occurred_at are set by the trusted execution, not accepted on client assertion.
- Null actors are reserved for documented system/recovery operations with attributable operational evidence and a reason.
- operation_id supports correlation and idempotent recording across retries.
- Clients cannot create, update, or delete audit logs. Backend-owned records are append-only during their retention period.
- The backend records committed account changes together with their audit event atomically where the Firestore boundary permits. Other privileged business writes require reliable backend audit capture with retry/deduplication.
- Failed privileged attempts must have trustworthy operational evidence; they must not be mislabeled as committed changes.
- Never record passwords, tokens, verification links, or unnecessary patient/contact information.

Required events include approval/rejection, auth-link creation/replacement, access-role change, login enable/disable, privileged account disablement, committee-history modification, donor deactivation/archive, and historical donation correction.

Read audiences and retention are defined in [PERMISSIONS.md](PERMISSIONS.md) and the production privacy/retention policy.

## 12. Shared Data Invariants

- Firestore machine dates are Timestamp values, or null only where explicitly allowed. Do not store ISO strings as production machine dates.
- Missing/malformed required dates are validation errors; never silently substitute DateTime.now().
- New audit/write timestamps are server-generated. Historical event dates are validated input, not automatically the write time.
- Define timezone conversion for legacy date strings and use Asia/Dhaka organization boundaries for calendar reports. Monthly queries use Timestamp lower and exclusive upper bounds.
- created_by, updated_by, assigned_by, recorded_by, approved_by, rejected_by, and fulfilled_by reference application User IDs when non-null. auth_uid and explicitly named actor_auth_uid refer to Firebase identities.
- Do not fabricate legacy actors or creation dates. Unresolved required provenance blocks automatic promotion of that record; retain the original in the migration archive for review.
- Controlled values use stable language-neutral keys. User-entered content remains unchanged.
- Missing security-sensitive values fail closed; no implicit active or privileged defaults.
- Retain referenced identities and events through deactivation/archive. Retention-driven deletion requires a reviewed reference-preservation/privacy procedure.
- V1 deliberately separates user_directory from private users for the approved directory audience. No other speculative public/private duplicates or donation archive schema are introduced. See [PERMISSIONS.md](PERMISSIONS.md).

## 13. User Directory

Collection: user_directory/{userId}

The document ID equals the authoritative application User ID. Fields are exactly:

```text
name: string
phone: string
blood_group: string | null
profession: string | null
photo_url: string | null
active: boolean
```

Do not include email, address, access_role, login_enabled, authentication/link information, created/updated metadata, audit actors, or other security metadata.

users/{userId} remains the authoritative private/application profile and sole current authorization source. user_directory is presentation/directory data only and NEVER an authorization source. Its active field controls directory visibility, not application admission.

All admitted roles may read active directory records for organization/committee display:

committee_assignment.user_id → user_directory/{userId}

Inactive/missing directory entries must not trigger a fallback read of someone else's private User. Show an unavailable/hidden directory entry instead. History does not override the active directory audience.

## 14. Controlled Directory Synchronization

Q preserves exact User/directory equality. Privileged User creation/state/security/photo changes and projection backfill/repair use trusted execution: reread current authoritative User, validate the originating capability, and commit the User, exact six-field directory projection and required audit evidence atomically. No stale asynchronous repair is allowed.

Free-V1 exception: an admitted caller may update an existing own User's name, phone, blood_group, profession, address and preferred_language only. Rules bind updated_at to request.time (serverTimestamp) and updated_by to the resolved own User ID; those metadata effects are not applicant-selected audit authority. photo_url remains operational/provider-controlled. Email, roles, active/login, links, creation metadata and all other security fields remain immutable in this client path.

For a directory-visible change, an atomic batch/transaction must include both users/{ownUserId} and user_directory/{ownUserId}. Rules use getAfter() to prove the directory post-state equals exactly name, phone, blood_group, profession, photo_url, active from the authoritative User post-state, with no extra fields. Both existing pre-state documents must be valid and synchronized; clients cannot create a missing projection or repair corruption. The directory rule independently binds the actor, exact own path, originating allowed User change and post-state metadata. No other-user, standalone, forged or stale directory writes pass. Non-directory-only edits may omit a directory write if exact post-state equality remains true.

Validate both sides, complete schema/changed-field allowlists, pre-state admission and rule-access-call limits. No client User/projection deletion, no generic directory writer and no directory authorization authority are introduced. Privileged and operational writers still apply trusted Q. If the Rules proof fails, the affected client write remains denied; there is no asynchronous or permissive fallback.

## 15. Committee Media

Collection: committee_media/{mediaId}. Exact fields:

```text
term_id: string
image_url: string
caption: string | null
sort_order: integer
active: boolean
uploaded_at: Timestamp
uploaded_by: string
provider: string | null
provider_public_id: string | null
```

Existing term required; HTTPS image_url; sort_order >= 0 with document ID tie-break. Parent, image_url, provider, provider_public_id, uploaded_at and uploaded_by are immutable after creation. Replacement creates a new asset record; hide/retain the old one. Creation active = true; caption/order edits and active true → false require trusted execution/audit. No unhide or hard-delete grant. All admitted roles read active media associated with readable committee history, including past inactive terms. Hidden media is developer_admin/leader only. Term.active describes current/historical term, not photo visibility.

CommitteeTerm.group_photo_url is nullable HTTPS. Each term retains its own cover. Cover update does not grant term creation/ending; rollover must not overwrite past terms.

## 16. Event

Collection: events/{eventId}. Exact fields:

```text
title: string
description: string | null
event_type: string
event_date: Timestamp
location: string | null
cover_image_url: string | null
active: boolean
created_at: Timestamp
created_by: string
updated_at: Timestamp | null
updated_by: string | null
```

event_type keys: meeting, blood_donation_campaign, awareness_program, social_activity, celebration, emergency_activity, other. Unknown required event_date blocks publication; never DateTime.now fallback. Creation: active true, trusted created metadata, updated pair null. Edit/hide/cover update sets both updated fields; creation metadata remains immutable. Past event_date does not hide history. Active events: all admitted roles; hidden events: developer_admin/leader. Trusted create/edit/hide/cover capabilities are separate. No unhide or hard deletion.

## 17. Event Media

Collection: event_media/{mediaId}. Exact fields:

```text
event_id: string
image_url: string
caption: string | null
sort_order: integer
active: boolean
uploaded_at: Timestamp
uploaded_by: string
provider: string | null
provider_public_id: string | null
```

Existing parent required. Same media type/immutability/timestamp/provider/retention rules as CommitteeMedia. Active child reads require an existing readable parent and media.active true. Parent hide removes ordinary child access without rewriting children. Explicit developer_admin/leader hidden review covers media hidden itself or by its hidden parent. Ordinary add/edit/hide requires an active parent; hidden-parent review does not grant mutations. No unhide or hard deletion.

## 18. External Image Invariants

Firebase Storage is unused/denied in Free V1. External provider remains unselected. All photo_url/group_photo_url/cover_image_url/image_url values are approved HTTPS URLs, or null only where declared. No empty-string URL, image bytes/base64, API credentials, administrative signatures or biometric/face-recognition data. URL/provider metadata never authorizes.

provider/provider_public_id are nullable non-secret identifiers; a non-null public ID requires a non-null approved provider. They assist controlled replacement/removal but confer no provider API authority. Non-null actors reference real application Users. uploaded_at is trusted server time when the workflow registers an uploaded asset, not a guessed historical photo date. Caption/order changes require trusted audit because media has no update fields.

Titles/captions <= 200 characters, descriptions <= 5000, location <= 300, URLs <= 2048, provider_public_id <= 512; tighter provider validation may apply. No extra entity fields. Provider review must cover free tier, upload security, byte/MIME/type/size checks, secret custody, deletion/replacement, privacy and URL stability. Rules cannot inspect remote bytes; trusted editorial validation is required. Public URLs can be copied outside Firestore audiences; never claim hiding a record retracts copied images.

Initial workflow: operator uploads externally → validates → trusted editorial URL write. Direct Flutter upload disabled. Profile photo_url is operational initially; Q switches User/directory atomically. Null/error uses bundled local avatar. Upload replacement first, commit references second, clean up unreferenced old asset last. Cleanup failure cannot break the application. Retained historical references prevent destructive asset removal.

Terminology for this Free V1 profile: references to backend/server authorization or backend-owned audit mean trusted execution, implemented by the reviewed operator-local tool now; they do not require a hosted paid service. Firestore Rules remain the enforcement path for explicitly permitted ordinary client operations only.

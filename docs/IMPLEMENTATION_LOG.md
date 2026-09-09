# Implementation Log

Production Architecture v1.2.1 — Free V1. Architecture status: frozen for implementation.

## Phase 1A — Core Firestore Security

- **Status:** Complete.
- **Main changes:** Added deny-by-default Firestore Rules, the verified admission gate, exact own registration/link reads, own private User reads, active directory reads, and atomic own-profile/User-directory synchronization.
- **Tests:** Rules emulator suite passed 44/44 with synthetic data. Flutter analysis had 0 errors and 0 warnings; 14 pre-existing information-level lints remained.
- **Known gaps:** Legacy User/Auth records did not meet strict admission. Client identity lookup, private-User queries, profile writes, bootstrap, and migration still required coordinated adaptation.
- **Production deployment:** Not performed; no production Firebase/Auth/data change or migration.

## Phase 1B — Business Firestore Rules

- **Status:** Complete; Phase 1 ready.
- **Main changes:** Added committee, event/media, donor, donation, notice, blood-request, audit-log, legacy-request, and unknown-collection enforcement. Direct trusted-execution-only writes remain denied. Donor create/edit schemas and protected aggregates/link/state were enforced.
- **Indexes:** Added `committee_media(term_id, active, sort_order)`, `events(active, event_date desc)`, `event_media(event_id, active, sort_order)`, `donors(active, name)`, and `donors(active, total_donations desc)`. Status-only notice/blood-request queries required no composite index.
- **Tests:** Rules emulator suite passed 76/76 with synthetic data. Flutter analysis had 0 errors and 0 warnings; 14 pre-existing information-level lints remained.
- **Known gaps:** Legacy donor records/payloads may fail exact v1.2.1 validation. Indexed audience filters are required. Donation, editorial, terminal-transition, audit-write, linkage, aggregate, archive, and media-write workflows remain trusted-execution-only.
- **Production deployment:** Not performed; no production Firebase/Auth/data change or migration.

## Phase 2A — Auth + User Session

- **Status:** Complete.
- **Main changes:** Added strict v1.2.1 User, AuthLink, and six-field UserDirectory models; removed `users/{authUid}`, `users.auth_uid`, legacy role/admin, position, committee-year, and directory admission fallbacks; preserved passwords exactly for Firebase sign-in; added strict startup/login session resolution.
- **Session states:** `unauthenticated`, `emailUnverified`, `unlinked`, `linkInactive`, `userMissing`, `userInactive`, `loginDisabled`, `invalidRole`, `admitted`, `error`. Permission, network, and schema failures map to `error`, never `userMissing`.
- **Tests:** Flutter tests passed 16/16 with synthetic data. Flutter analysis had 0 errors and 0 warnings; 9 pre-existing information-level lints remained.
- **Known legacy-admin compatibility gap:** The legacy production administrator intentionally cannot pass strict admission until a reviewed bootstrap/migration creates the exact v1.2.1 User and active auth link. No compatibility bypass was added.
- **Production deployment:** Not performed; no production Firebase/Auth/data change or migration.

## Phase 2B — Registration, Profile and Directory

- **Status:** Complete; Phase 2B ready.
- **Main files changed:** Registration/profile models, Auth and User services/controllers, registration/login/profile/member-directory/add-member UI, dashboard directory count, synthetic tests, and this implementation log.
- **Registration flow:** Creates Firebase Auth first, writes only `registration_requests/{firebaseAuthUid}` with the exact pending schema and server timestamp, sends email verification, exposes own-document status only, supports resend/refresh, and reports/retries the Auth-created/Firestore-failed partial state.
- **Profile/directory behavior:** Active lists query only `user_directory where active == true`; directory data is presentation-only. Own edits are limited to name, phone, blood group, profession, address, and preferred language, with server audit metadata and atomic User/projection writes. Missing, malformed, or unsynchronized projections fail for trusted repair; `photo_url` and security fields are not client-editable.
- **Legacy privileged client write:** Direct organization User creation and client role/position/year assignment were removed from normal service/controller logic; the historical add-member screen is retained as unavailable pending trusted operator tooling.
- **Tests:** `flutter test` passed 22/22 synthetic tests.
- **Analyzer:** `flutter analyze --no-pub` reported 0 errors, 0 warnings, and 9 pre-existing information-level lints.
- **Known gaps:** Reviewed trusted operator registration approval/rejection, User/directory/auth-link creation, audit evidence, and directory repair tooling remain unavailable; no client fallback was added.
- **Production deployment:** NOT performed; no production Firebase/Auth/data change or migration.
- **Exact next task:** Phase 2C — implement reviewed trusted operator registration decision/admission tooling with atomic User, `user_directory`, `auth_links`, and audit-log handling.

## Phase 2C — Trusted Registration Admission Tool

- **Status:** Complete; Phase 2C ready.
- **Tool location:** `tools/operator/`; local Node.js CLI using Firebase Admin SDK, excluded from the Flutter APK.
- **Approval/rejection behavior:** `approve` validates a pending exact request, verified matching applicant Auth identity, current admitted reviewer, target-role boundary, link uniqueness, operation ID, and review reason, then atomically creates the exact User, directory projection, auth link, approval decision, and audit event. `reject` atomically records only the pending-to-rejected decision fields and audit event without deleting the Auth account or request.
- **Security boundaries:** Explicit operator Firebase UID is resolved through `auth_links` to the authoritative User on every transaction; malformed/inactive/unrecognized state, self-review, duplicate links, stale decisions, unauthorized target roles, and normal `developer_admin` creation fail closed. Credentials are runtime-only and ignored locally. The CLI prints the target project and currently refuses every non-`demo-*` project or missing Firestore/Auth emulator host.
- **Tests:** Operator synthetic transaction/policy suite passed 12/12; `npm audit` reported 0 vulnerabilities. Flutter regression tests passed 22/22.
- **Analyzer:** `flutter analyze --no-pub` reported 0 errors, 0 warnings, and 9 pre-existing information-level lints.
- **Production execution:** NOT performed; the Phase 2C safety guard prevents production access.
- **Legacy administrator:** Current legacy-admin bootstrap/migration remains intentionally deferred.
- **Exact next task:** Phase 2D — define and review the protected legacy `developer_admin` bootstrap/recovery procedure, then validate it against emulator-only synthetic data before any production execution.

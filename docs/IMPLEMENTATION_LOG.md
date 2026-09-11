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

## Phase 2D — Developer Admin Bootstrap and Recovery

- **Status:** Complete; Phase 2D ready for demo/emulator use only.
- **Bootstrap behavior:** Added `bootstrap-developer-admin`; it requires an explicit verified, enabled Firebase Auth identity and exact intended profile, rejects existing links, identity conflicts, existing developer-admin records, and reused operations, then atomically creates the generated-ID User, exact directory projection, auth link, and `admin.provision` audit record without creating a registration request.
- **Recovery behavior:** Added `recover-developer-admin`; it accepts only one explicitly identified broken current developer-admin, rejects healthy or ambiguous authority and ordinary-User promotion, preserves historical records, atomically deactivates the superseded User/directory/active link, creates a separate verified replacement authority, and records `admin.recover` audit evidence.
- **Safety boundaries:** Existing explicit `demo-*` project and Firestore/Auth emulator requirements remain mandatory; production-like projects fail before Firebase initialization. Runtime credentials only; no secrets are stored or printed.
- **Tests:** Operator synthetic policy/transaction suite passed 21/21; `npm audit` remains at 0 vulnerabilities. Flutter regression tests passed 22/22. Analyzer reported 0 errors, 0 warnings, and 9 pre-existing information-level lints.
- **Production execution:** NOT performed; no Firebase deployment or production Auth/Firestore mutation occurred.
- **Legacy administrator:** The current real legacy administrator was NOT migrated; its unverified email and missing backup/checkpoint remain explicit blockers, with later production preconditions added narrowly to `MIGRATION_PLAN.md`.
- **Exact next task:** Phase 2E — create a separately authorized, access-controlled backup/checkpoint and complete an isolated restore rehearsal before any real legacy-admin migration is considered.

## Phase 2 — Final Integration Review

- **Status:** READY.
- **Issues found/fixed:** Completed registration and partial-failure retry now sign out explicitly; password confirmation was added; contradictory registration decision metadata and Rules-incompatible photo URLs fail strict parsing; stale session state and obsolete Phase-2 aliases were removed. Trusted approval now creates only a member, rejects existing email/phone identity conflicts atomically, and leaves later role assignment to its separate audited capability.
- **Auth/admission flow verified:** Firebase Auth account → exact own pending request → email verification → trusted atomic approval → exact User/directory/auth link → strict Phase 2A session resolution. No normal Flutter User/auth-link/role/security-state creation path or UID/User fallback remains.
- **Trusted-tool boundaries verified:** Normal approval cannot create or elevate to `developer_admin`; bootstrap/recovery remain separate, demo/emulator-only, audited, transactional, and fail closed. No committed secret was found.
- **Tests:** Operator synthetic tests passed 22/22. Flutter regression validation passed 24/24 tests using the installed Flutter engine and existing package configuration; no package resolution or installation was performed. Rules were unchanged, so Rules tests were not run.
- **Analyzer:** Flutter analyzer validation completed with 0 errors, 0 warnings, and 9 pre-existing information-level diagnostics using the installed analysis server and existing package configuration.
- **Production:** Untouched; no deployment, credentials, production Firebase access, Auth change, or Firestore mutation was performed.
- **Exact next task:** Phase 3A Organization Structure.

## Phase 3A — Committee Structure and History

- **Status:** Complete; Phase 3A ready.
- **Models/services/UI:** Added strict exact-schema CommitteeTerm and CommitteeAssignment models, a display-only committee member projection, scoped read-only committee service/controller logic, current/past committee screens, and committee navigation. Added the required term/assignment query indexes.
- **Current committee:** Resolves exactly one active term, reads only active assignments for that term, and joins presentation data through active `user_directory` records. Missing directory entries and missing/invalid photos use safe unavailable/local-avatar states.
- **Past committees:** Lists inactive terms newest-first and reads all assignments for the selected historical term. Historical position always comes from the preserved CommitteeAssignment record, never current User state.
- **Authorization boundary:** Committee position, term, assignment history, and directory data never map to `users.access_role`. Flutter committee code is read-only and does not create/end/correct terms or assignments, set group photos, query private Users, or perform backfills.
- **Rules/indexes:** Existing Phase 1B Rules already allow admitted committee/history reads and active-directory presentation reads; Rules were unchanged. Added composite indexes for past-term ordering and active assignment lookup.
- **Tests:** Offline Flutter engine validation passed 37/37 synthetic tests. The `flutter test --no-pub` wrapper was skipped because its SDK-cache lock requires write permission outside the repository; no approval was requested and no packages were resolved or installed.
- **Analyzer:** Installed analyzer-server validation completed with 0 errors, 0 warnings, and 9 pre-existing information-level diagnostics. The `flutter analyze --no-pub` wrapper was skipped for the same external SDK-cache permission requirement.
- **Production:** Untouched; no deployment, credentials, production Firebase access, Auth change, or Firestore mutation was performed.
- **Exact next task:** Phase 3B — trusted committee assignment operation for existing active terms only.

## Phase 3B — Trusted Committee Assignment Management

- **Status:** READY. Phase 3B implementation exposed a genuine assignment-lifecycle capability gap; the matrix received one narrow amendment granting `committee.assignment_end` only to developer_admin and leader, with executive, committee and member denied. This did not add a wildcard or reopen other architecture.
- **Trusted tool operations:** `assign-committee-position` and `end-committee-assignment` are implemented outside Flutter. Every operation resolves Firebase Auth UID → exact active `auth_links` record → exact active, login-enabled User with a recognized `users.access_role`; committee position, directory, term and history never authorize.
- **Assignment/end behavior:** Assignment retains its exact active User/directory/term checks, machine position key, one-active-User/term transaction guard, shared-position allowance, atomic audit and unchanged `users.access_role`. Ending requires an existing active assignment, existing parent term, unused operation ID and reason, then atomically changes only `active` and `ended_at` and creates audit evidence. Historical user, term, position and assignment provenance remain exact.
- **Tests:** Operator synthetic suite passed 35/35, covering developer_admin/leader ending, all lower-role denials, immutable history, already-ended/reused-operation rejection, atomic failure, assignment regression, unchanged access role and production-target refusal. Flutter committee mutation scan found no `.add`, `.set`, `.update` or `.delete` path.
- **Flutter validation:** No Flutter source changed. The external-cache Flutter wrapper remained unavailable without approval; the Phase 3A 37/37 offline baseline remains the latest Flutter test run. No package resolution or installation occurred.
- **Analyzer:** Direct installed analysis-server validation for the unchanged Flutter sources reported 0 errors, 0 warnings and 10 existing information-level diagnostics.
- **Production:** Untouched; no deployment, credentials, network access, Firebase Auth/Firestore access or production data mutation occurred. The demo/emulator-only safety guard remains enforced.
- **Exact next task:** Phase 3C — committee media and group photos.

## Phase 3C — Committee Media and Group Photos

- **Status:** Complete; Phase 3C ready.
- **CommitteeMedia/read flow:** Added strict exact-schema media parsing with required HTTPS URL, Firestore Timestamp, nonnegative integer ordering and generic nullable provider metadata. Current and historical rosters query only the selected term's active media and order by `sort_order` with document-ID tie-break; malformed media fails closed.
- **Group photo/gallery behavior:** Existing nullable HTTPS term cover now renders for both current and past terms with local fallback for null or load failure. The minimal gallery shows stable active images, optional captions, an empty state and broken-image fallback. Flutter remains read-only.
- **Trusted media operations:** Added operator-only `add-committee-media`, `edit-committee-media-caption`, `set-committee-media-order`, `deactivate-committee-media` and `set-committee-group-photo`. Developer_admin/leader authorization is resolved only through Auth UID → active auth link → admitted `users.access_role`; media add/editorial state/cover changes and audit evidence commit atomically, with immutable media identity/provider/upload metadata, no hard deletion and no unrelated field changes.
- **External provider boundary:** No provider was selected or contacted. Firestore receives only approved HTTPS URLs and nonsecret generic metadata; no image bytes, upload path, credentials or Firebase Storage were added.
- **Rules/indexes:** Existing Rules already allow admitted active-media reads, restrict hidden media to developer_admin/leader and expose no Flutter media writes. The existing `committee_media(term_id, active, sort_order)` index is exact; no Rules or index change was needed.
- **Tests:** The expanded operator synthetic suite passed 50/50, including add/caption/order/hide/group-photo authorization, exact schema/audit, invalid/missing state, rollback, retry rejection, unchanged access role, term rollover and production refusal. Added Flutter model/service/source tests for strict parsing, time/URL validation, scoped ordered historical galleries, safe fallbacks and the read-only boundary; the Flutter wrapper remained blocked on its external SDK-cache lock, so these new Flutter tests were not claimed as executed.
- **Analyzer:** Direct installed analysis-server validation completed with 0 errors, 0 warnings and 10 existing information-level diagnostics.
- **Production:** Untouched; no network, deployment, credentials, provider call, production Firebase access or data mutation occurred.
- **Exact next task:** Phase 3 — final organization-structure integration review.

## Phase 3 — Organization Structure Final Integration

- **Status:** READY after closing two implementation-discovered lifecycle gaps narrowly: assignment ending and composite term rollover. Standalone term creation/ending remain denied.
- **Committee lifecycle:** Added trusted `rollover-committee-term` for developer_admin/leader only. It creates the first active term only when none exists, or atomically deactivates the exactly matched single current term while creating one generated-ID active successor and audit evidence. It never changes assignments, Users, roles, login state or Auth links.
- **Media completion:** Completed every affirmative committee-media editorial operation: add, caption edit/clear, order update, hide, and group-photo set/clear. Media identity, parent, URL, provider/public ID and upload provenance remain immutable after creation; no unhide/delete exists.
- **Authorization:** All trusted committee operations resolve current admitted authority exclusively through `users.access_role`; position, term, assignment, directory, uploader and media fields never authorize, and no developer_admin wildcard was introduced.
- **Tests:** Operator synthetic suite covers term initialization/rollover concurrency state, stale/multiple current terms, role denials, exact successor schema, rollback/idempotency and assignment preservation, alongside all assignment/media regression tests.
- **Validation:** Operator tests passed 50/50 and direct Flutter analysis remained at 0 errors/0 warnings. Rules/index code was unchanged; the offline Rules rerun could not spawn the installed Java process under the repository sandbox, so the prior 76/76 emulator result remains the latest Rules execution evidence.
- **Production:** Untouched. All operator commands retain the explicit demo-project plus Firestore/Auth emulator guard.
- **Exact next task:** Phase 4A — strict donor schema and donor lifecycle integration.

## Phase 4A — Strict Donor Schema and Lifecycle

- **Status:** Implemented and validated in local/synthetic paths; no production execution.
- **Schema/client:** Replaced the legacy donor parser with the exact frozen 18-field schema. Required fields, Firestore Timestamps, nullable values, nonnegative totals, document/actor IDs and HTTPS photo URLs now fail closed. Removed runtime `photo`, `upazilla`, `last_donated`, implicit active/default values and the clinical-eligibility badge.
- **Create/edit UX:** New donors use the Rules-compatible initial state (`active = true`, null link/date, zero total, trusted server timestamps and current linked User actors). The form no longer accepts a historical donation date. Creation is available only to developer_admin/leader/executive/committee; profile editing is available only to developer_admin/leader/executive. Member mutation controls are absent. Read/query/schema errors no longer become successful empty lists.
- **Trusted deactivation:** Added operator-only `deactivate-donor` for developer_admin/leader. It validates exact current donor and admitted operator state, changes only active/updated metadata, retains the donor, and writes the minimal append-only audit in the same transaction. Inactive, malformed, lower-role and reused-operation attempts fail without partial writes.
- **Related cleanup:** Dashboard active requests now references canonical `blood_requests`; ranklist consumes nullable canonical donor presentation fields. Existing donor indexes still match active-name and active-total query shapes.
- **Tests:** Operator synthetic suite passed 53/53. Firestore Rules emulator suite passed 76/76. The focused donor Flutter/model suite passed 4/4 through direct offline frontend compilation and `flutter_tester`; the standard Flutter wrapper remains blocked by sandbox child-process execution, not a test failure.
- **Analyzer:** Direct installed analysis-server validation reported 0 errors and 0 warnings; existing information-level diagnostics remain outside this unit.
- **Production:** Untouched; no Firebase/Auth/provider access, deployment, migration, production data mutation or paid service occurred. Operator production guard remains intact.
- **Exact next task:** Phase 3 Events + Event Media — strict models/read UX and trusted audited editorial operations.

## Phase 4B — Events and Event Media

- **Status:** Implemented and validated in local/synthetic paths; no production execution.
- **Schema/read UX:** Added exact-schema Event and EventMedia parsing with recognized event types, strict Firestore Timestamps/nullability, bounded text, HTTPS-only image URLs, nonnegative deterministic media ordering, and consistent event update metadata. Admitted users can reach active events from the dashboard, open details, and view ordered active galleries. Developer_admin/leader can also review hidden events; empty, denied, malformed, offline, query-unavailable, and broken-image states fail safely with retry/fallback UI.
- **Flutter boundary:** Event Flutter code is read-only. It queries `events(active, event_date desc)` and `event_media(event_id, active, sort_order, document ID)` only; no client create/edit/hide/delete or upload path was added.
- **Trusted editorial operations:** Added emulator-guarded operator commands for event create/edit/hide, cover set/clear, and event-media add/caption edit/order change/hide. Every command resolves Auth UID → exact active auth link → admitted User and authorizes only developer_admin/leader. Mutations and minimal audit evidence are transactional and operation-ID protected; event/media identity and creation/upload provenance stay immutable, and no delete/unhide command exists.
- **External provider boundary:** No provider was selected or contacted. Only approved HTTPS URLs and optional generic provider metadata can be stored; no image bytes, credentials, Firebase Storage, Functions, Run, billing, or paid service was added.
- **Rules/indexes:** Existing Rules already enforce admitted active-event/media reads, developer_admin/leader hidden review, and deny all Flutter event/media writes. Existing event and media indexes match the implemented query shapes; no Rules/index change was required.
- **Tests:** Operator synthetic regression suite passed 61/61. Focused Flutter event/model/source suite passed 4/4 through direct offline frontend compilation and `flutter_tester`. Full Flutter application frontend compilation completed successfully.
- **Analyzer:** Direct installed analysis-server validation reported 0 errors and 0 warnings. New event files were clean after lint correction; existing information-only diagnostics remain outside this unit.
- **Production:** Untouched; no deployment, credentials, network/provider call, production Firebase/Auth/Firestore access, data mutation, or migration occurred. The operator demo-project plus Firestore/Auth emulator guard remains mandatory.
- **Exact next task:** Phase 4C — strict Donation lifecycle, atomic donor aggregate maintenance, history UX, and trusted correction handling.

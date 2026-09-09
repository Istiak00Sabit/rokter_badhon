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

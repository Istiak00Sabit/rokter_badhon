# Phase 1B — Business Firestore Rules

- Completed before resume: business collection rules, five justified indexes, emulator configuration, 76-test synthetic suite, donor edit hardening, and this report were already complete.
- Completed now: inspected the current files, confirmed no partial or invalid edit, reran both required validations, and made no Rules/test/Flutter code changes.
- Files changed: `firestore.rules`, `firestore.indexes.json`, `firebase.emulator.json`, `rules-tests/firestore.test.cjs`, and this report.
- Indexes added: `committee_media(term_id, active, sort_order)`; `events(active, event_date desc)`; `event_media(event_id, active, sort_order)`; `donors(active, name)`; `donors(active, total_donations desc)`. No notice or blood-request composite index was added because Phase 1B uses status-only queries.
- Tests: `npm run test:rules` — **76 passed, 0 failed** with synthetic data on the local demo-project emulator. `flutter analyze --no-pub` — **exit 1**, 14 existing unrelated info-level lints; **0 errors, 0 warnings**. Rules/test syntax and index JSON checks passed.
- Compatibility gaps: legacy donor documents or client payloads missing the exact v1.2.1 fields/metadata are rejected. Business list queries must include the audience filters represented by the indexes. Donation, editorial, terminal blood-request, audit-write, linkage, aggregate, archive, and media-write workflows remain trusted-execution-only. Flutter adaptation and data migration were not performed.
- **Production deploy NOT performed.** No production Firebase/Auth/data, Storage, Functions, Blaze, migration, or Flutter UI change was made.
- **Phase 1 READY.**
- Exact next task: Phase 2 — adapt Flutter data services to the v1.2.1 collection names, constrained read queries, and exact donor/blood-request client payloads; keep trusted-execution-only mutations out of Flutter and do not deploy until separately authorized.

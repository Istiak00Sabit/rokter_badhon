# Phase 1A — Core Firestore Security

Implemented locally against frozen v1.2.1: deny-by-default admission, own registration/link reads, private own-User access, active directory reads, and atomic own-profile projection with valid synchronized pre-state and Rules-bound update metadata. All other collections remain denied.

- Added: `firestore.rules`, `firebase.emulator.json`, `package.json`, `package-lock.json`, `rules-tests/firestore.test.cjs`, this report.
- Updated: `.gitignore` (local dependencies/emulator artifacts), `analysis_options.yaml` (exclude third-party `node_modules` only).
- No composite index needed: Phase 1A uses document gets and a single-field `active == true` directory query. No index manifest added. Existing `firebase.json` is unchanged; tests explicitly use the separate emulator config.
- Rules tests: `npm run test:rules` — **44 passed, 0 failed**, synthetic data only, `demo-rokter-badhon`, loopback Firestore emulator; emulator shut down afterward. Covers required cases, five roles, missing/malformed gate state, projection repair attacks, metadata spoofing, revocation and atomic rollback. Rules were not weakened.
- `flutter analyze --no-pub` — **exit 1**, 14 existing info-level lints (6 `avoid_print`, 6 deprecated `withOpacity`, 2 `unnecessary_underscores`); **0 errors, 0 warnings** on the final run. Flutter source/UI unchanged.
- Compatibility gaps: inventoried legacy Users/Auth do not satisfy strict admission/schema; existing client identity lookup, broad private-User queries and profile writes need later coordinated adaptation. Profile edits require an existing valid exact projection and server timestamp/application-User actor metadata. Projected changes require an atomic batch. Deferred business collections remain inaccessible. No migration, bootstrap or repair performed.
- Source files are ready for version control, but this workspace has no `.git` repository; no commit was possible.
- **Production deploy NOT performed.** No production Firebase/Auth/data changes, Storage, hosted Functions, Blaze, or web search.
- Exact next task: Phase 1B — implement and emulator-test the deferred donor/donation, committee, notice, blood-request and event/media Rules against the frozen capability matrix, retaining this core gate and Q invariant. Await that phase's authorization; no deployment.

Stopped after Phase 1A.

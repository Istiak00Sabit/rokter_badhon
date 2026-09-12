# Rokter Badhon Ghatail

Rokter Badhon Ghatail is a Bangla-first Flutter/Firebase application for the Ghatail blood-donor organization. Free V1 includes donor and blood-request workflows, donation history, notices, events and galleries, committee history, a public-safe member directory, localized profile management, and role-scoped administrative review.

## Free V1 security model

- `users.access_role` is the only current authorization authority.
- Firebase identities resolve through `auth_links/{firebaseAuthUid}` and fail closed on missing or inconsistent state.
- Firestore Rules protect ordinary client reads and writes; sensitive account, lifecycle, and editorial mutations run only through the local trusted operator tool.
- Trusted operations are transactionally audited and refuse non-`demo-*` projects or missing Auth/Firestore emulators.
- Firebase Storage and direct image uploads are intentionally absent. Approved HTTPS image URLs may be published by trusted editorial operations after an external provider is selected.
- Bangla (`bn`) is the first-launch default; English (`en`) is optional and persisted locally.

The frozen architecture, capability matrix, implementation history, recovery plan, and remaining production gates are in [`docs/`](docs/). In particular, [`docs/PRODUCTION_CHECKLIST.md`](docs/PRODUCTION_CHECKLIST.md) distinguishes completed code gates from owner-controlled deployment, migration, privacy, credentials, device, signing, and provider decisions.

## Local validation

Use a Flutter SDK compatible with the lockfile, Node.js, and Java 21. Resolve packages without changing the locked dependency graph, then run:

```text
flutter pub get
flutter analyze
flutter test
npm --prefix tools/operator test
npm run test:rules
```

The Rules suite starts an isolated Firebase emulator against the explicit demo project. The trusted operator CLI is implemented under [`tools/operator/`](tools/operator/); keep both emulator hosts configured and never weaken its production guard.

## Production boundary

The repository is a code release candidate, not a deployed production release. Before distribution, the project owner must complete every unchecked item in the production checklist, including real Firebase project provisioning/deployment, App Check, production application identity and signing, privacy/retention approval, backup/recovery rehearsal, migration reconciliation, monitoring, external image-provider policy, and controlled APK/AAB device acceptance.

# Rokter Badhon Ghatail — Free V1 execution tracker

Updated: 2026-10-12. Target: Android APK on Firebase Spark (no Blaze upgrade, Cloud Functions, paid SMS OTP, Firebase Storage, or paid server).

## Frozen product decisions

- Single organization: রক্তের বাঁধন ঘাটাইল.
- Flutter + Dart, GetX, Firebase Auth email/password with normalized phone-derived internal email, Cloud Firestore, Bangla/English.
- Official 2025–2027 committee roster: **51 unchanged source rows** in `data/committee_2025_2027.json`; exactly **2 leaders, 31 executives, 18 committee**. President and general secretary retain leader role. A committee position is not a security role.
- Privileged auth-link/role/login transitions and append-only privileged audits need independently authorized local operator execution on Spark. Never put Admin SDK credentials in the Android app.
- The app can display pending registration requests, but approving registration through a safe mobile-only API is **not** currently implemented. Do not represent review-list access as a working approval action.
- User-authorized production deployments/imports are separate from GitHub source changes. No production mutation is implied by green emulator tests.

## Stage / acceptance gates

| Stage | Work | Status | Completion evidence |
| --- | --- | --- | --- |
| 1. Scope and source-of-truth | Freeze schema, five access roles, existing screens and 51-person roster | **Source reviewed; product decisions frozen** | ARCHITECTURE, DATA_MODEL, CAPABILITY_MATRIX, JSON roster |
| 2. Security Rules | Remove blanket developer_admin client override; deny direct security/audit and committee mutations; keep intended read + ordinary business paths | **Code fixed; emulator regression tests added** | `firestore.rules`, `rules-tests/firestore.test.cjs`, CI; production not published |
| 3. Authentication and administrative bootstrap | Real verified developer_admin identity, safe recovery and trusted registration decisions; Auth UID → auth_links → users mapping | **Code gate added; owner-approved production execution blocked** | explicit project/action/UID confirmation tests, owner-approved protected trusted operation and real-device login |
| 4. Registration | Form, phone, Ghatail Union/Village, exact pending request; protected decisions and login status feedback | **Code integration and tests added; live approval/login blocked** | synthetic pending/rejected/approved-unlinked→admitted tests, Firestore Rules tests, then owner-approved real admission on device |
| 5. Dashboard | Donor/member/request aggregation counts, notices, Dhaka month boundaries, role-aware/error states | **Code fixed; tests added; real-device pending** | Flutter tests + Rules aggregate-count emulator tests + Android build; owner-approved live data verification still needed |
| 6. Donors | Search, submission, reviewer approval/rejection, edits, safe archive workflow | **Approval UI, bounded queue and decision rules improved; full directory search/archival and live tests pending** | Emulator approval/role/pagination tests; later scalable donor search, authorized archive and controlled real-device flow |
| 7. Committee | Preserve approved 51-person source and preview, guard trusted import, view authoritative live term safely | **Code and safety tests improved; production import not authorized or performed** | identical JSON previews, two frozen leaders, directory collision tests, no-login import confirmations and CI; real import and device review pending |
| 8. Remaining modules | Blood Requests, Donations, Notices, Events, Ranklist and protected admin actions | **First integration fixes and tests added; remaining module workflows/live tests pending** | ranklist retry tests, bounded donation history, double-request-submit guard, role-based emulator reads and Android CI; remaining history/publishing workflows and device tests |
| 9. Quality | Bangla/English, error/loading/offline, pagination, Rules tests, Flutter analyzer/widget tests, Android devices | **Ongoing** | automated CI + physical Android acceptance matrix |
| 10. Release | Owner-approved Rules, signed Android APK, install/retest and instructions | **Not complete** | release signed APK and owner/device verification |

## Work already performed on 2026-10-10

1. Removed overlapping broad `developer_admin` Firestore match clauses which formerly permitted direct arbitrary account/auth-link/audit mutation. Existing scoped Firestore Rules now authorize only specific admitted-role operations.
2. Replaced tests that previously expected broad privileged success with negative security regressions, including denied cross-user reads, direct account security writes, audit history edits/deletes, and unauthorized committee writes. Kept atomic donor approval coverage.
3. Replaced the misleading in-app committee-add action with an explicitly localized operator-only notice. No roster, role or Firebase production data was changed.

## Stage 3 implementation — trusted production CLI safeguards

- Explicitly scoped commands: `bootstrap-developer-admin`, `approve`, `reject`, `link-registration`. Other routine account, donor and editorial commands remain emulator-only (existing separately reviewed committee/legacy provisioning exceptions are unchanged).
- Before Firebase Admin SDK initialization, production requests require: exact known project confirmation, `--allow-production true`, exact `--confirm-command`, explicit protected credential path, operation ID and a meaningful reason. Registration additionally requires two matching operator/applicant UIDs; linking requires a confirmed target User ID; bootstrap requires matching Auth UID and `--confirm-first-admin true`.
- The underlying trusted module independently rechecks Firebase Auth, active operator User/link role, applicant/target identity, duplicate states and collision risks, then commits audited transactions. Production credentials never enter the app.
- The mobile registration review stays read-only, labels the trusted boundary, and lets a reviewer copy the applicant UID.
- No command has been executed against production. The owner must explicitly approve the reviewed real identity and account mutations before any operator uses this path. Admin provisioning can change a Firebase Auth email alias and account access, so it requires a separate identity review; a successful synthetic test is not authorization.

## Stage 4 implementation — applicant-facing registration integration

- `AuthService.resolveSession()` now reads only the **authenticated unlinked applicant's own** registration request when the auth link does not exist. Strict parsing distinguishes pending, rejected, and approved-without-link states; none grants application admission or dashboard access.
- Login provides Bangla/English messages for those states and a button leading to the existing request status/recovery screen. A registered applicant who is still signed in can sign out safely from that screen.
- Added a pure registration→request→approved identity→admitted session integration test, plus a Firestore Emulator test proving pending/rejected/approved-but-unlinked requests cannot read protected data. The actual trusted operator transaction is covered separately in operator tests.
- This work does not remotely approve a real applicant, deploy rules or bypass bootstrap: **production approval and real-device login remain owner-controlled acceptance gates**.

## Stage 5 implementation — count queries and truthful display

- Four summary counters (`donors.active`, `user_directory.active`, current Dhaka month `donations.donation_date`, `blood_requests.status=active`) now use Firestore `count().get()` aggregations rather than downloading every matching document. Latest published notices remain strictly filtered and limited to three.
- A pure `DhakaMonthWindow` computes the UTC+06:00 month start and exclusive end, with tests for midnight boundaries, year rollover and leap-day behavior.
- A `member` or `committee` cannot read donation history under the existing Rules. Previously the dashboard presented `0`; it now reports restricted access, without attempting the forbidden donation count.
- A missing/disabled current User is not reported as zero donations and stale previous User names are cleared before refresh. Other independent dashboard sections can still show their own successes/errors.
- User-facing dashboard errors are localized; raw Firebase/internal exception messages are not displayed in the dashboard cards.
- Firestore Emulator regressions execute the exact count queries and verify filters, roles and unlinked-account denial. Unit tests validate controller states and month math.
- **Production still unchanged:** these changes are not evidence that the deployed Firebase Rules match GitHub or that live records have been reconciled. Counts reflect only existing Firestore data, not the source committee roster until an authorized import occurs.

## Stage 6 implementation — donor approval and protected directory

- `DonorListScreen` is now a Stateful screen and triggers its initial Firestore donor query only once per screen opening; name/blood-group/search widget state is disposed with the screen. Explicit refresh and return from the Add/Edit screen still reload the list.
- `DonorService.getPendingSubmissionsPage` requests status-scoped, ordered pages of 30 with a Firestore document cursor (and an extra record to detect more pages); `PendingDonorApprovalsScreen` has an explicit Load More control, a reload retry, and a busy guard to prevent duplicate review taps.
- Review errors now distinguish stale/missing decisions, permissions and connection failures. Approval of a removed request checks existence before parsing. Unforeseen donor form/list errors no longer leave a blank success state.
- `DonorSubmissionModel` validates decision invariants: Pending has no decision metadata, Approved has matching approver/timestamp/donor ID only, Rejected has rejector/timestamp/nonempty reason only.
- Firestore Emulator coverage verifies bounded pending review pages, correct editorial vs committee access, atomic donor approval, and refusal of repeated approval/rejection. Strict model tests cover malformed terminal records.
- **Unfinished deliberately:** the active donor directory's current name/phone substring search downloads all active records. Limiting it silently would cause donors to be missed in emergency searches; a correctly indexed/searchable and paginated solution remains to design and test. Phone-level duplicate prevention across two different submissions is also not transactionally enforced. Active donor archive/deactivation is not exposed to the Flutter client by Rules and requires an authorized audited workflow.
- **Not production verified:** no actual donor submitted/approved and no Rules published to the live Firebase project. Automated emulator tests are not proof that current deployed Rules match source.

## Stage 7 implementation — committee integrity and trusted import safety

- The canonical official source and in-app bundled preview are byte-identical and contain 51 unique committee phones, two frozen leader assignments at serials 001 and 009, 31 executives, and 18 committee members. Automated Node tests assert both file parity and unchanged president/general-secretary identities.
- Source validation now rejects invalid Bangladeshi phone numbers, unsupported blood groups and any changed/reordered/promoted leader, even when overall role totals still match. Validation errors avoid printing member phone numbers.
- The transactional initial import now rejects a conflicting phone number in either `users` **or** `user_directory` before writing anything, not just in `users`. A synthetic collision regression confirms no committee assignments are created.
- A production import launched through the operator CLI requires explicit `--confirm-command seed-official-committee`, `--confirm-roster 51:2:31:18`, `--confirm-leaders 001,009`, `--acknowledge-no-login true`, and a meaningful `--reason`, in addition to the already required production project confirmation. It records the provided reason in new audit entries. The guard runs **before Firebase initialization**.
- If no active Firestore committee term exists, Flutter displays the clearly labeled unsynced 51-person bundled preview. Once a live term exists, the live roster is authoritative even if empty; the app no longer silently replaces it with bundled profiles. A Flutter regression tests this preview selection.
- Committee management documentation no longer claims that the removed in-app Add Member button works. Sensitive member/role changes remain separately authorized operator operations. No production operation was performed.
- **Acceptance gates still open:** verify deployed Firestore Rules and real accounts, approve an operator and intended 51-member import, inspect the result and run Android device tests. Source CI/emulator success alone does not establish production readiness.

## Stage 8 implementation — blood requests, donation history and ranklist

- Ranklist is now a stateful screen with **one cached initial query**. Retry and pull-to-refresh await a real new Firestore request instead of calling `Element.markNeedsBuild`, which previously reloaded on arbitrary rebuild. Its leaderboard remains explicitly top 50 active donors, not a claim about every donor. Widget regressions cover single load and retry.
- Donation History now loads ordered Firestore pages of **30 records** (plus one lookahead), preserves a document cursor, and displays Load More / retry. A failed later page preserves already visible history, and unauthorized reads do not masquerade as a genuine zero-record history. Paging controller tests and Rules emulator authorization tests have been added.
- Emergency Blood Request creation now blocks a second in-flight submit in the controller and form. Network, session, malformed data and unknown errors are surfaced through the existing safe error UI. A synthetic concurrent write test asserts only one Firestore creation can run at once.
- Notices and Events remain read-only client features, with authorized edit/publish/visibility operations delegated to the independently guarded operator system. Their controllers now catch unexpected plugin failures, clear stale content, and allow retry rather than leaving a spinner.
- Security emulator tests exercise bounded `donations` queries with Firestore document cursor and confirm only authorized history roles can read, while an admitted ordinary member can read active but not fulfilled Blood Requests.
- **Outstanding:** Blood Requests, Notices, Events and media still use unbounded list reads; their scalable pagination must retain access to all valid records rather than silently truncating them. Full request fulfil/cancel, event/notice publishing and donation-recording workflows remain trusted operator commands, not buttons that claim to work in the Flutter client. Release-grade live tests remain blocked by production bootstrap/rules approval.
- **No production write:** Firebase Rules, real requests/donations, Auth identities, committee roster, and project billing were not changed.

## Stage 9 start — acceptance preparation and device-test guide

- The final Stage 8 GitHub Actions run for commit `a67dfbc9` passed both the Flutter and backend jobs (run 148, 2026-10-10). This includes Flutter analyze/tests, backend tests, Firestore Rules emulator tests, a debug Android APK build and artifact upload.
- The physical-phone guide now distinguishes the **normal debug APK (real Firebase target)** from the separate emulator-only APK helper. It fixes the emulator project ID to `demo-rokter-badhon` and removes an inaccurate instruction to test a Flutter Committee Add button that is intentionally unavailable.
- An operator regression checks the phone guide's demo project ID, read-only committee workflow and exact 2/31/18 live-roster expectation.
- A redacted manual acceptance checklist was added for identity admission, committee, donors, emergency requests, donation history, translations, offline errors and application restart. **No physical-device execution has been claimed.**
- The 51-person official roster and the two approved leaders remain untouched. No Firebase production write, Rules deploy or committee import was performed in this work.

## Stage 9 Batch 2 — bounded emergency blood-request lists

- Replaced unbounded status list reads with `BloodRequestPage` (30 displayed records plus one lookahead) and Firestore snapshot cursor pagination. The status filter and descending `created_at` ordering remain unchanged; the corresponding composite index already exists in source.
- The controller now tracks distinct active, fulfilled and cancelled cursors. Only developer_admin, leader and executive query terminal statuses; ordinary committee/member users fetch active requests only.
- Active and terminal lists expose separate Load More/Retry controls. A failed later page retains previously visible records and the original cursor. Terminal batches commit both status pages together so a partial network failure cannot skip one status on retry.
- Added Flutter regression tests for member-scoped paging, active retry and atomic privileged-terminal retry. Expanded the Firestore Rules emulator regression for ordered cursor reads by executive and member without widening terminal access.
- Removed a redundant reload after leaving the request form. Existing duplicate request-submission protection remains in place.
- Code changes are committed on `main`. This is **not** evidence of physical-device validation or real Firebase deployment. CI for this batch must be evaluated against its final commit before marking it passed.
- Remaining Stage 9 work includes bounded Notice/Event/media lists, donor search/archive gaps and real Android-phone acceptance.

## Stage 9 Batch 3 — bounded Notice and Event lists

- Notice published/draft/archived lists now use 30-record pages and one lookahead with Firestore snapshot cursors. Ordinary admitted users fetch **published only**; only developer_admin/leader may fetch draft/archived. Multiple review statuses commit cursor updates together so a failed second status cannot drop records from Retry.
- Event lists now paginate **active** and independently **hidden** events with separate cursors. Only developer_admin/leader fetch hidden events. The existing status filters, event-date ordering and source composite indexes remain unchanged.
- Notice/Event screens display Load More and retryable later-page errors while preserving records already shown. Duplicate IDs from an overlapping page are ignored; first-page errors remain distinct from genuinely empty lists.
- Flutter controller regression tests cover member/reviewer access, multi-status failure recovery, and active/hidden cursor behavior. Firestore Rules emulator tests check two-page status-scoped queries for published, draft, active and hidden states.
- **Still outstanding:** Event and Committee media/gallery reads are not yet paginated. Trusted event/notice publishing remains outside the Flutter client. Device/production acceptance, deployment and official committee import remain owner-controlled and unperformed by this batch.
- CI for the final batch commit must pass before marking code verification complete.

## Stage 9 Batch 4 — paginated event and committee galleries

- Event media is fetched as **20-item status-scoped cursor pages** (plus one lookahead) with event_id, active state, sort_order and document ID ordering. Ordinary members read active media only; leader/developer_admin can separately review hidden media when authorized. Both cursors commit only after successful retrieval, preserving visible images after a network error.
- Both **current** and **past** Committee rosters now load their own gallery as 20-item active-media cursor pages; initial bundled preview remains read-only, with no server import. Current/past member lists, approved 51-person JSON and two frozen leaders remain unchanged.
- Both gallery widgets show Load More, retain earlier images on failed next pages, and allow Retry. A generation guard discards stale pagination responses after a refresh or roster change; duplicate image IDs are deduplicated.
- Added event/committee gallery widget retries, source contract assertions, and Firestore Rules emulator cursor/role regressions. The existing media composite indexes and deployed Rules files were **not** modified.
- This is a source-only batch. Real Android device acceptance, production Rules validation, official committee import and donor search/archive remain **open gates**, not claims of completion. Verify the latest batch CI before treating code tests/APK as passed.

## Stage 9 Batch 5 — donor directory and duplicate/archival gates

- The Flutter active donor directory now uses 30-record cursor pages (plus a lookahead) and **server-side blood-group filtering** rather than downloading all active donors on initial screen open. Each filter change starts a new generation; an old response cannot overwrite the selected group's records. Later-page network errors retain existing donors and the original cursor, with retry and ID deduplication.
- Name/phone substring matching is intentionally **limited to pages already loaded**. The interface explicitly warns when pages remain and offers Load More. An empty loaded-page match must never be described as a complete global search. Truly complete substring search still requires exhausting all pages or a separately indexed search design; no unsupported global-search guarantee is made.
- Active phone collision preflights have been added for submission, donor edit and approval; approval also checks that the target donor document does not already exist before transaction.set. These checks fail closed on query failure. **They are NOT a transactional uniqueness guarantee** for concurrent, separately submitted applications or differently normalized phone formats. A trusted phone-key reservation and reviewed migration of existing records are still required before production duplicate-free guarantees.
- `firestore.indexes.json` now declares the active+group+name and active+phone composite indexes required by the new queries. Source index changes do **not** deploy indexes to real Firebase; until owner-authorized index deployment, the production version of these queries may return `query_unavailable` and block writes rather than skip the check.
- Donor deactivation remains an existing authenticated, audited **trusted operator transaction** (`tools/operator/src/donor.js`), deliberately unavailable as an unrestricted mobile delete. The operator CLI remains emulator-only for `deactivate-donor`; production archive cannot be declared enabled without separate owner-approved safeguards.
- New Flutter controller tests cover retry without duplicates, blood-group switch and stale request protection. Firestore Emulator tests cover ordered pages, server-side group filtering and the exact active phone check without expanding Rules.
- This is source-only work: no Committee roster edits, production Firebase writes, Rules/Index deployment, or Android physical-device acceptance have been performed. Check the final Batch 5 CI before marking automated verification successful.

## Stage 9 Batch 6 — indexed lookup and donor identity release safeguards

- Batch 5 GitHub Actions CI passed for `aeffc06e` (run `38114550592`), including Flutter/backend/Rules checks and Android debug APK build.
- Donor Directory now offers an explicit **server-side indexed lookup**: exact normalized `01XXXXXXXXX` phone (`+880` / `880` accepted) OR a **case-sensitive stored-name prefix**, both with active-only status, optional blood-group filter, 30-record pages and cursor retry. Editing the text without submitting still previews loaded-page substrings; arbitrary middle-name substrings are **not** globally indexed. Readable UI hints distinguish these scopes.
- Source composite indexes were added for active phone+name lookups, with and without blood-group filter; these indexes are **not yet deployed to production**. Failed-precondition/index errors are not silently swallowed.
- Emulator rules regressions check indexed query scopes against inactive donors. Dart regression tests validate normalization of complete phones and reject numeric partials. Bangla/English texts were added.
- The trusted `deactivate-donor` CLI now requires `--confirm-donor-id` matching `--donor-id` and a trimmed reason of at least ten characters. It still uses the existing audited transaction; no direct client delete or phone-key release is permitted. It remains emulator-only.
- Added a read-only `audit-donor-phones` operator command and `donor_phone_plan.js` for reviewing **all historical active and inactive** donor phones in bounded pages, including Bangladesh/Bangla digit normalization, malformed numbers and cross-format collisions. Unit tests reject a truncated audit as complete. This command only runs against the local Firebase emulator and **does not migrate or reserve identities**.
- **Unresolved critical release gate:** the Flutter approval transaction is still allowed without a canonical `donor_phone_keys` reservation. Concurrent approvals of different submissions can therefore duplicate a phone, and the legacy database has not been backfilled. Do not enable a production uniqueness guarantee or switch approvals to the new locking model until an owner-reviewed migration, updated Firestore transaction + Rules, concurrency tests, and production deployment are expressly authorized.
- No production Firebase data, official committee roster, roles, indexes or Rules were deployed or mutated. Physical Android-device end-to-end acceptance is still required. Verify Batch 6 final CI before marking automated verification complete.

## Stage 9 Batch 7 — atomic donor phone reservation (source, emulator)

- GitHub Actions Batch 6 CI for commit `7455fa8f` fully passed, including Flutter/backend/Rules tests and debug APK.
- Donor approvals now require deterministic `donor_phone_keys/{01XXXXXXXXX}` creation **in the same Firestore transaction** as donor creation and submission approval. Two distinct submissions targeting the same canonical phone cannot both reserve the same document.
- New donor submissions normalize +880, local and Bangla-digit numbers to one canonical BD phone. Legacy pending applications with noncanonical phones may still be **rejected** but not automatically approved.
- Firestore Rules constrain the key to the same donor/submission and reviewer, deny modification/deletion, and require `system_config/donor_phone_registry` to be `{ready: true, schema_version: 1}`. When missing/not ready, approval deliberately fails closed, even if a previous client bypasses the new application code.
- Approved donor phone editing is locked. Archive does not delete historical reservations, preserving identity even for inactive profiles. Explicit localized errors explain migration-required, registry-unready and locked identity states.
- Emulator tests cover approval and forged writes, readiness missing/false, legacy rejection, two competing approvals, key immutability and role boundaries. Dart regressions check canonicalization, invalid numbers, and the transaction contract.
- See `docs/DONOR_PHONE_CUTOVER.md` for the necessary owner-controlled full-history audit, cleanup, protected migration/backfill, Rules/index rollout and readiness process. **No production registry activation, historical backfill, Rules deployment, phone-key mutation, Android device E2E or Release acceptance was performed.**
- Batch 7 CI for its final source commit must pass; this remains a **production rollout blocker** until full historical backfill, read-back integrity and owner-approved physical-device verification.

## Stage 9 Batch 8 — production readiness without production mutation

- The final Stage 9 Batch 7 GitHub Actions run `38130603648` completed successfully, including **Flutter analyze/tests, backend/operator tests, Firestore Rules tests, Android debug APK and artifact upload**.
- Added `verifyDonorPhoneRegistry` and the emulator-only `audit-donor-registry` CLI command. It checks **all historical active and archived donor identities** against `donor_phone_keys`, detects missing/orphan/mismatched/noncanonical/duplicate entries and invalid readiness schema, and prints **counts only** (no private phones or donor IDs). A partial page scan is an error, never a green result. The older `audit-donor-phones` CLI output is now similarly redacted.
- Added an explicit, **empty-database-only** `seed-empty-demo-donor-registry` fixture, hard-restricted to `demo-rokter-badhon` with both emulators connected. It allows local physical-phone approval tests but **refuses any existing donor or phone key history** and never migrates/deletes history or touches production. `tools/run_local_phone.ps1` invokes it before installing the locally configured debug APK.
- Unit tests cover donor/key mismatches, archived phone ownership, legacy formats, privacy-safe reports, bounded scan failures, repeatable demo setup, non-demo target denial and unknown existing registry rejection.
- New `docs/STAGE9_ANDROID_ACCEPTANCE_MATRIX.md` captures required Android hardware tests as **UNTESTED** (not silently passed) and maintains a complete NO-GO production blocker list.
- Batch 8 latest GitHub CI is required before marking the source and emulator-side work successful. **No real phone was tested, no live Firebase data read/backfill/write/deployed, no production Rules/indexes/registry activated, no committee import and no signed release created**. Spark Free Plan and 51-person Committee remain unchanged.

## Stage 10 Batch 1 — safe Android release configuration (source-only)

- Stage 9 Batch 8's latest GitHub Actions run `38133879892` completed **successfully**, including Flutter Analyze/Tests, Backend Operator Tests, Firestore Rules Tests, debug Android APK compilation and artifact upload.
- The Android Gradle `release` build previously used the **debug signing key**. This has been removed. Release signing now requires a private `android/key.properties` and a valid local `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Missing configuration is a deliberate failure for release tasks, not a fallback to debug signing. CI's debug build retains its own existing debug signing.
- Android's **main** manifest now requests `android.permission.INTERNET` for Firebase production-network access. `usesCleartextTraffic=true` remains restricted to the debug manifest for local emulator use.
- The signing properties and keystores are ignored by Git. No key material was generated, stored, committed, printed or put into GitHub Actions.
- Added `docs/ANDROID_RELEASE_SIGNING.md` with owner-held key custody, correct package/Firebase registration, signed APK/AAB verification and update-install acceptance guidance.
- New operator regression checks protect against debug signing reintroduction, missing Internet permission and accidental cleartext configuration in the release manifest.
- **Production signing and release are NOT COMPLETE**. The existing `com.example.rokter_badhon` application ID has not been owner-approved; signing key custody, correct Firebase Android identity and SHA/App Check attestation, physical Android acceptance, historical donor key backfill, signed artifacts, privacy and deployed Rules are all external release gates. No production Firebase mutation, official committee change or paid upgrade occurred.

## Stage 10 Batch 2 — release candidate identity and debug artifact verification

- The prior Stage 10 Batch 1 final GitHub Actions run `38286155450` succeeded, including Flutter, Firestore Security Rules, backend operator tests, Android debug APK and artifact upload.
- Added `tools/release/verify_candidate.mjs`: a fail-closed source consistency audit of the Android package ID, namespace/MainActivity, `google-services.json`, Flutter Android Firebase ID/project number, version/build number, production Internet permission, debug-only cleartext setting and owner-private signing configuration.
- The checker **always reports `releaseApproval: NO_GO`**, because matching source does not prove production owner approval or device acceptance. The current `com.example.rokter_badhon` remains an unapproved development package ID. It is **not changed** by this batch.
- Added binary verification of the **actual built debug APK** via SDK `aapt` and `apksigner` for package identity, Internet permission and APK signature, and a computed SHA-256/size. Failing or missing inspection tools make CI fail rather than silently skip artifact verification.
- GitHub Actions now runs both audits and uploads a privacy-safe `release-preflight.json` beside the short-retention debug APK. The report contains no Firebase API key, private signing password or donor/member data. New backend regression tests cover mismatched Firebase IDs, missing permissions, insecure signing, invalid version and missing APK.
- See `docs/ANDROID_RELEASE_CANDIDATE.md` and the acceptance matrix. This is **not** signed release APK/AAB verification, Play Store acceptance, real Android phone testing, migration/backfill, production Firebase deployment, signing-key creation or owner authorization. All of those gates remain **NO-GO** until independently completed.
- Latest Batch 2 CI must be checked against its **final** commit and its binary preflight before marking automated verification passed.

## Stage 10 Batch 3 — emulator-only Android build provenance and cloud launch smoke

- The Stage 10 Batch 2 GitHub Actions run `38336749225` finished successfully, including the actual built Android debug APK's package/permission/signature/sha256 verification.
- **CI's installable test APK now uses `USE_FIREBASE_EMULATOR=true` and `FIREBASE_EMULATOR_HOST=127.0.0.1`.** This changes the CI artifact from the old production-targeted debug APK to `rokter-badhon-emulator-debug-apk` for safe synthetic local tests, not production login.
- Its `release-preflight.json` report declares the emulator target and includes the exact Git commit, GitHub Actions run ID and APK SHA-256. The target declaration attests to the reviewed CI build flags; signature and checksum inspection alone cannot prove embedded Dart defines.
- A new `android-smoke` GitHub Actions job consumes the verified APK artifact, starts an Android 14 cloud emulator, checks checksum/provenance and installs, launches and restarts the app, failing on an app-specific AndroidRuntime fatal exception. **No Firebase emulators are started during this minimal startup smoke; no credentials, role-protected workflows or real device are tested.**
- Updated `docs/PHONE_TESTING.md`, `docs/ANDROID_RELEASE_CANDIDATE.md` and the physical Android acceptance matrix to distinguish emulator-only CI artifacts from a normal `flutter run`, which still targets real Firebase without special flags.
- Backend regression tests guard the emulator-only build settings and safety labeling. Current app package remains the development ID; no production Firebase Rules/indexes/data/committee imports or private signing materials were touched.
- **Batch 3 automated checks need the latest GitHub run to pass**, including the new cloud Android smoke job. Historical phone-key migration, real hardware End-to-End tests, final application ID and signed APK/AAB remain owner-controlled release blockers. This batch is still NO-GO for distribution.

## Stage 10 Batch 4 — isolated Android cloud Auth/UI acceptance

- Stage 10 Batch 3's final CI run `38338521358` passed all Flutter/backend/Firestore tests, emulator-only debug APK signature/checksum inspection, and the Android 14 install/launch/restart smoke.
- Cloud `android-smoke` now starts **real local Firebase Auth + Firestore emulators**, hard-scoped to `demo-rokter-badhon`, with credential/project guards and synthetic test-admin/empty-donor-registry seeding. No production account or data are accessed.
- New Android Python accessibility acceptance checks the English language switch, phone/password fields, sign-in using the public emulator-only developer-admin, and navigation to the Current committee page. These checks require the local emulators and intentionally emit no screenshots, real phone numbers or credentials.
- The CI APK remains the verified `USE_FIREBASE_EMULATOR=true` build, with Git SHA, CI run, Android APK signature and SHA-256 report; no production-targeted APK is used for synthetic tests.
- Backend regression assertions and release/acceptance guides were updated. These cloud checks are **not** full Registration → Approval E2E acceptance, physical Android device tests, a signed release build, approved Android package ID or historical donor registry production cutover. The production gate stays **NO-GO**.
- The latest Batch 4 GitHub Actions run must pass **including the cloud UI acceptance** before these new tests can be marked successful. No Firebase production writes, Rules/index deployment, signing secrets or official 51-person Committee modifications were performed.

## Next concrete tasks

1. Review the new Stage 9 documentation/test CI result, then perform the listed emulator-configured Android-phone MVP checks and record redacted evidence.
2. Review Batch 6 indexed donor search CI and complete remaining secure operator-only publishing transitions without weakening Rules.
3. Obtain explicit owner review/approval for full historical donor phone migration/backfill, verify every reserved key, then gate production readiness; concurrency protection is now source-implemented but not production-active.
4. Obtain explicit owner review/approval for live Rules, admin identity and any 51-member import; source CI never changes Firebase.
5. Complete Stage 9 physical-device acceptance before treating the signed Stage 10 release as ready.

## Stop conditions

- Do not claim **production ready** from emulator or GitHub Actions alone.
- Do not deploy Firebase Rules, create identities, import committee members, or mutate production without explicit owner approval.
- Do not silently grant developer_admin arbitrary full client writes as a shortcut.
- A failed legitimate flow is a blocker, not a reason to re-run unrelated infrastructure audits.

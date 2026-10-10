# Rokter Badhon Ghatail — Free V1 execution tracker

Updated: 2026-10-10. Target: Android APK on Firebase Spark (no Blaze upgrade, Cloud Functions, paid SMS OTP, Firebase Storage, or paid server).

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
| 8. Remaining modules | Requests, donations, notices, events, ranklist, protected admin actions | **Code review and live tests pending** | each supported create/read/transition tested |
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

## Next concrete tasks

1. Verify Stage 7 CI success (Node operator/Firestore Rules tests, Flutter analysis/tests, APK build) on the final code commit.
2. Stage 8: inspect Blood Requests, Donations, Notices, Events and Ranklist for complete read/write and permission/error-state behavior; fix and regress issues without production writes.
3. Return to Stage 6's remaining accurate paginated donor search, duplicate detection and trusted archive; do not silently truncate emergency search results.
4. Review the live Firebase project, deployed Rules and trusted identity **before requesting specific owner approval** for Account/Rules/Committee production mutations. Do not import the 51-person roster or create accounts in CI.
5. After approval, perform real-device Registration → Review → Login → Dashboard → Donor Submit → Approve/Reject → Search and Committee roster acceptance tests.

## Stop conditions

- Do not claim **production ready** from emulator or GitHub Actions alone.
- Do not deploy Firebase Rules, create identities, import committee members, or mutate production without explicit owner approval.
- Do not silently grant developer_admin arbitrary full client writes as a shortcut.
- A failed legitimate flow is a blocker, not a reason to re-run unrelated infrastructure audits.

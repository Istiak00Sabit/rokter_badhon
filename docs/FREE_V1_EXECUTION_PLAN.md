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
| 6. Donors | Search, submission, leader approval, edits, archive with durable history | **Code and emulator tests exist; live tests pending** | real controlled submit→approve→search; rejected submission not listed |
| 7. Committee | Authorized import of fixed official roster, account provisioning and history; safely managed future member adds | **Roster source ready; production import not done** | 51 unique profiles, 2/31/18 roles, zero unintended login grants |
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

## Next concrete tasks

1. Confirm final Stage 5 CI status including the Android debug APK.
2. Stage 6: test Donor Submission → Leader Review → Atomic Approve/Reject → Active Search, covering all permission/duplicate/error states without any production writes.
3. Securely verify the selected production admin identity and deployed Firebase Rules before requesting **specific owner approval** for real bootstrap/registration decisions.
4. Run controlled real-device registration→review→login→dashboard→donor MVP testing after production approval.
5. Advance to official committee import and remaining organization features only when the relevant acceptance gates are met.

## Stop conditions

- Do not claim **production ready** from emulator or GitHub Actions alone.
- Do not deploy Firebase Rules, create identities, import committee members, or mutate production without explicit owner approval.
- Do not silently grant developer_admin arbitrary full client writes as a shortcut.
- A failed legitimate flow is a blocker, not a reason to re-run unrelated infrastructure audits.

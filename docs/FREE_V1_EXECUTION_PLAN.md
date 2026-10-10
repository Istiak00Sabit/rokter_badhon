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
| 4. Registration | Form, phone, Ghatail Union/Village, exact pending request; **protected approval/rejection** and successful login | **Review UI is read-only** | one actual pending→approved→admitted flow and denied unauthenticated access |
| 5. Dashboard | Donor/member/request counters, notices, month boundaries, error states | **Code exists; live tests pending** | matched Firestore data and resilient error/empty/offline states |
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

## Next concrete tasks

1. Confirm final CI status after localization/UI patch.
2. Verify client screen/service operations agree with the scoped Rules, prioritizing registration, dashboard and donor submission/approval.
3. Design and test the **authorized Spark-safe production operator workflow** for registration approval/linked user and developer_admin bootstrap; current CLI intentionally rejects normal production approval. Do not weaken Rules to make approval buttons work.
4. Before any production action, identify exactly what will be changed and obtain explicit owner permission.
5. After approval, run controlled real-device end-to-end MVP acceptance testing, then advance to committee data and remaining modules.

## Stop conditions

- Do not claim **production ready** from emulator or GitHub Actions alone.
- Do not deploy Firebase Rules, create identities, import committee members, or mutate production without explicit owner approval.
- Do not silently grant developer_admin arbitrary full client writes as a shortcut.
- A failed legitimate flow is a blocker, not a reason to re-run unrelated infrastructure audits.

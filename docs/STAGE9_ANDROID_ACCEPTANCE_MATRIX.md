# Rokter Badhon — Stage 9 Android & Firebase acceptance matrix

**Status: NOT RELEASE READY.** This is a checklist, **not evidence that physical device tests occurred**. Only mark a row passed after personally verifying the stated source/device and recording a redacted result. Never publish member names, phone numbers, login credentials, applicant IDs, blood requests or patient details.

## Evidence metadata

| Field | Recorded evidence |
| --- | --- |
| Tested Git commit | NOT TESTED |
| GitHub CI run and APK artifact | See latest successful `Flutter checks` run; copy URL before device test |
| APK source | `tools/run_local_phone.ps1` emulator build (not the normal production-targeted CI APK) |
| Device model / Android version | NOT TESTED |
| Emulator project | `demo-rokter-badhon` only |
| Date, tester, redacted failure log | NOT TESTED |
| Production database / indexes / Rules | NOT DEPLOYED BY THIS STAGE |

## Automated acceptance evidence

| Check | Result policy |
| --- | --- |
| Operator unit/security tests | PASS only on latest GitHub CI green run |
| Firestore Rules Emulator including concurrent donor approvals | PASS only on latest GitHub CI green run |
| Flutter analyze and tests | PASS only on latest GitHub CI green run |
| Android debug APK build + artifact | PASS only on latest GitHub CI green run |
| Android release candidate source alignment (package / Firebase / permissions / private signing) | PASS only after latest source preflight CI step succeeds; **production approval still NO-GO** |
| Built debug APK package, Internet permission, signature and SHA-256 | PASS only after latest binary-preflight CI step succeeds and report is archived |
| Donor migration integrity checker / demo fixture | PASS only on latest GitHub CI green run |
| Signed release APK/AAB | NOT DONE; this debug APK is not a release |

CI release-candidate verification: `tools/release/verify_candidate.mjs` generates the
privacy-safe `release-preflight.json` artifact. It must be evaluated against the **same**
Git commit as the APK. A passing check verifies a **debug** APK only; it never
approves the placeholder package ID, private release signing or production
distribution. See `docs/ANDROID_RELEASE_CANDIDATE.md`.

## Physical Android acceptance — all initially UNTESTED

| ID | Scenario | Expected result | Status |
| --- | --- | --- | --- |
| A01 | First launch, Bangla/English switch, app restart | Language persists correctly; no exception | UNTESTED |
| A02 | Ghatail Union/Municipality → Village/Mahalla dropdown | Values match source; no invalid combinations | UNTESTED |
| A03 | New synthetic registration | Exactly one pending application, no protected access | UNTESTED |
| A04 | Rejected synthetic applicant | No dashboard or protected information | UNTESTED |
| A05 | Approved synthetic registration, valid AuthLink | Phone+password login and logout work | UNTESTED |
| A06 | Approved user with missing or disabled AuthLink/User | Access denied with meaningful error | UNTESTED |
| A07 | Role access, disabled-user logout/reentry | No unauthorized read/write | UNTESTED |
| A08 | Pending synthetic donor | Not present in active directory | UNTESTED |
| A09 | Leader approves donor with ready demo phone registry | Donor+approval+one immutable phone key committed | UNTESTED |
| A10 | Concurrent duplicate phone submissions | Exactly one approval; loser remains pending | UNTESTED |
| A11 | Leader rejects donor | Rejected and absent from active list | UNTESTED |
| A12 | Active donor list, blood group, exact phone and prefix search | Correct results, Load More, Retry | UNTESTED |
| A13 | Donor edits, immutable phone field | Changes except phone persist; phone change blocked | UNTESTED |
| A14 | Current Committee roster & archived term | Read-only 51-person roster; 2 leaders/31 executives/18 committee | UNTESTED |
| A15 | Dashboard count, donation history and ranking | Correct role-scoped results, loading/error states | UNTESTED |
| A16 | Blood Request, Notice, Event gallery | Controlled writes, pagination, visibility and no double submit | UNTESTED |
| A17 | Airplane mode / disconnected emulator / retry | No false zero totals or silent data loss; recovery works | UNTESTED |
| A18 | Repeat app restart and Android permission handling | No stuck splash/login; state remains valid | UNTESTED |

## Production release blockers

- Owner-reviewed **full historical donor phone inventory**, reconciliation of duplicate/legacy and archived records, complete privileged key backfill, and read-back proof. No automatic production mutation.
- Explicit owner authorization for production Firebase Rules/index deployment, registry activation, real approved accounts, committee import and any required credentials.
- Real hardware evidence for the scenarios above; a test APK build alone is not device acceptance.
- Reviewed signing key custody and signed release APK/AAB, update/reinstall tests, backup/recovery plan and privacy review.
- Verification against the actual deployed Firebase project rather than relying on source-only schema/Rules.
- Production Spark plan remains mandatory; no Cloud Functions, SMS OTP, Blaze-only automation, managed paid backups or Firebase Storage added.

**Go / no-go:** If ANY blocker remains unresolved or any device row remains untested, release is **NO-GO**. Marking an automated CI result as passed is never approval to mutate production.

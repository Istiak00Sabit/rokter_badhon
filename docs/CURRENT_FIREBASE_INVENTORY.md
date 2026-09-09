# Rokter Badhon Ghatail — Current Firebase Inventory

Reference: **Production Architecture v1.2 — FROZEN FOR IMPLEMENTATION**  
Inventory date: **2026-09-07** (Asia/Dhaka). This is an observed-state report, not a change to the frozen architecture.

Only this report was created. No application files, dependencies, Firebase data/accounts/configuration, deployed rules, Storage objects, or architecture contracts were changed. No backup, migration, registration, deployment, or application login was performed.

Evidence labels:

- **VERIFIED FROM DEPLOYED FIREBASE**: authenticated management/API reads, raw Firestore REST values, or retrieved deployed rule source. Rules behavior below is static analysis of the deployed source, not a client permission test.
- **VERIFIED FROM SOURCE CODE**: active repository source and local configuration. This never establishes what data is deployed.
- **NOT VERIFIED**: inaccessible or untested state; no default values or assumptions fill these gaps.

The then-active frozen architecture documents were reviewed; the authoritative set is now ARCHITECTURE, DATA_MODEL, AUTH_AND_SECURITY, CAPABILITY_MATRIX, MIGRATION_PLAN, PRODUCTION_CHECKLIST, and LOCALIZATION. Active source searches excluded ZIPs, build output, `.dart_tool`, and generated backups. API reads were live and sequential, not a transactionally consistent backup. Personal values were processed only in memory and excluded from this report; identifiers specifically needed for the requested identity inventory are retained.

## 1. Project identity

**VERIFIED FROM DEPLOYED FIREBASE**

| Property | Observed value |
| --- | --- |
| Project ID | `rokterbadhon-b247b` |
| Project number | `941165503580` |
| Project state | `ACTIVE` |
| Firestore database | `(default)`; only database returned |
| Database type / edition | `FIRESTORE_NATIVE` / `STANDARD` |
| Location | `asia-south1` |
| Database created | `2026-03-28T03:57:59.828973Z` |
| Point-in-time recovery | `POINT_IN_TIME_RECOVERY_DISABLED` |
| Delete protection | `DELETE_PROTECTION_DISABLED` |
| Version retention | `3600s` |

The authenticated Firebase project response agrees with all local project references. The expected project is verified, not merely assumed. The database's `freeTier: true` metadata is not proof of project billing-plan status; billing was not inspected.

## 2. Local Firebase configuration

**VERIFIED FROM SOURCE CODE**

| File / configuration | Finding |
| --- | --- |
| `firebase.json` | FlutterFire platform metadata only. Android and Dart entries both use `rokterbadhon-b247b`. No Firestore/Storage rules or index deployment entries. |
| `.firebaserc` | Not present. No repository alias declared. |
| `android/app/google-services.json` | Project ID `rokterbadhon-b247b`; project number `941165503580`; bucket `rokterbadhon-b247b.firebasestorage.app`. |
| `lib/firebase_options.dart` | Same project, sender/project number and bucket; Android Firebase app ID matches Google Services configuration. |
| Android Firebase app ID | `1:941165503580:android:836f342d5b03c84cba7299`. |
| Android application ID / namespace | `com.example.rokter_badhon`; matches the Google Services Android client. |
| `android/settings.gradle.kts` | Declares Google Services Gradle plugin `4.3.15`. |
| `android/app/build.gradle.kts` | Applies Google Services plugin; release currently uses debug signing. |
| Local Firestore rules / indexes | No active local rules or indexes file found. |
| Local Storage rules | No active local Storage rules file found. |

**VERIFIED FROM LOCAL TOOLING** (environment evidence, not deployed configuration): Firebase CLI package `15.11.0` is installed. Its existing account/refresh-token cache is present; no secret values were printed. No active-project entry for this workspace was found in that cache. No `gcloud` executable was found on PATH, no standard ADC file was found, and no configured credential/token environment variables were present. No Firestore/Auth emulator environment overrides were present.

The initial cached-access-token project request returned HTTP 401. Refreshing the existing CLI OAuth session **in memory only** succeeded, followed by successful explicitly project-scoped read requests. Credentials were not saved or replaced. Sandbox networking required approved network access. No CLI `use`, login, deployment, or export command was run.

## 3. Active source collection inventory

**VERIFIED FROM SOURCE CODE**

Exactly five collection names are referenced by active Dart Firestore calls. All are declared in `lib/constants/app_constants.dart:74–78`.

| Collection | Files with Firestore operations | Read/query | Create | Update/delete | Query and order fields |
| --- | --- | --- | --- | --- | --- |
| `users` | `lib/services/auth_services.dart`, `lib/services/user_services.dart`, `lib/services/dashboard_service.dart` | Document get by ID; Auth-UID lookup; active users; dashboard count from fetched docs | `UserService.addUser`: generated document ID, `set(toMap())` | No active update/delete call found | `auth_uid == uid`, limit 2; `active == true`. Name sorting, admin exclusion, committee-year filtering are local Dart operations, not Firestore predicates. |
| `donors` | `lib/services/donor_service.dart`, `lib/services/dashboard_service.dart`, `lib/views/ranklist_screen.dart` | Active donor list/count, blood-group filter, ranking | `DonorService.addDonor`: `add(toMap())` | No active update/delete call found | `active == true`; optional `blood_group == string`; list orders `name ASC`; ranking orders `total_donations DESC`, limit 50. |
| `donations` | `lib/services/dashboard_service.dart` | Monthly query/count from fetched docs | None found; model serialization alone is not a writer | None found | `date >= firstDay.toIso8601String()`; no explicit order or next-month upper bound. |
| `notices` | `lib/services/dashboard_service.dart` | Latest notices | None found; model serialization alone is not a writer | None found | `date DESC`, limit 3; no publication-status predicate. |
| `requests` | `lib/services/dashboard_service.dart` | Active-request query/count | None found | None found | `status == 'active'`; no explicit ordering. |

`members` is **not** an active Firestore collection reference. Member-named controllers/screens use User records. No active references implement `auth_links`, `user_directory`, `committee_terms`, `committee_assignments`, `registration_requests`, `audit_logs`, or proposed `blood_requests`. The active request name remains `requests`.

### Source schema expectations, not deployed evidence

| Model / collection | Serialized fields and expected types |
| --- | --- |
| `UserModel` / `users` | Strings: `name`, `email`, `role`, `phone`, `photo`, `blood_group`, `address`; `auth_uid`: string/null; `login_enabled`, `active`: bool; `committee_year`: integer; `joined_date`: Timestamp. ID comes from document path. No serialized legacy `uid`. New organization-user creation forces `auth_uid: null`, `login_enabled: false`. |
| `DonorModel` / `donors` | Strings: `name`, `blood_group`, `gender`, `phone`, `photo`, `village`, `union`, `upazilla`, `district`; `total_donations`: integer; `last_donated`: Timestamp/null; `active`: bool. |
| `DonationModel` / `donations` | Strings: `donor_id`, `donor_name`, `blood_group`, `location`, `hospital`, `recipient_name`, `recorded_by`; `date`: Timestamp. |
| `NoticeModel` / `notices` | Strings: `title`, `body`, `posted_by`; `date`: Timestamp; `important`: bool. No status field in this model. |
| No request model found / `requests` | Only queried `status: string` is established. Other fields/types are unknown. |

Evidence: `lib/models/user_model.dart`, `donor_model.dart`, `donation_model.dart`, `notice_model.dart`; services and ranking view listed above.

Current User, Donation and Notice deserializers accept strings/Timestamps and silently replace missing/malformed required dates with `DateTime.now()`. User parsing defaults missing/null `active` to true, missing role to `member`, and missing committee year to the current year. Donor parsing defaults missing/null `active` to true and malformed donation dates to null. **None of these parsers was used for this inventory.**

## 4. Deployed Firestore inventory

**VERIFIED FROM DEPLOYED FIREBASE**

Root `listCollectionIds` returned **`users` only**, without a continuation token. All two User documents were read as raw Firestore values. Explicit reads of the four other legacy collections returned no documents and no continuation tokens. Subcollection-ID reads under each of the two User documents also returned empty successful responses.

| Root collection | Documents observed | Schema status |
| --- | ---: | --- |
| `users` | 2 | Complete top-level document scan; field table below. |
| `donors` | 0 | No deployed document schema to inspect. |
| `donations` | 0 | No deployed document schema to inspect. |
| `notices` | 0 | No deployed document schema to inspect. |
| `requests` | 0 | No deployed document schema to inspect. |
| `members` | Not returned | No root collection discovered. |
| Other root collections, including v1.2 additions | None returned | No unexpected root collection discovered. |

Zero records is not proof that a source model matches the proposed schema. Collection names in code or rules do not create a populated Firestore collection. Historical/deleted data is outside this live inventory.

### Raw User fields

Counts below are across both documents; Timestamp means Firestore `timestampValue`, not a parsed string.

| Field | Observed types / states | Missing count |
| --- | --- | ---: |
| `name` | string × 2; values withheld | 0 |
| `phone` | string × 2; values withheld | 0 |
| `email` | string × 2; one empty string; other value withheld | 0 |
| `address` | string × 2; values withheld | 0 |
| `blood_group` | string × 2; values withheld | 0 |
| `photo` | string × 2; both empty | 0 |
| `role` | string: `admin` × 1, `president` × 1 | 0 |
| `active` | boolean true × 2 | 0 |
| `auth_uid` | null × 1 | 1 |
| `login_enabled` | boolean false × 1 | 1 |
| `committee_year` | integer 2026 × 1 | 1 |
| `joined_date` | Timestamp × 2; valid raw timestamps | 0 |
| legacy `uid` | string × 1 | 1 |
| `access_role` | Absent in both | 2 |

No other User fields were returned. Thus proposed fields such as `profession`, `photo_url`, `preferred_language`, and creation/security metadata are also absent. There is schema heterogeneity through missing/null fields, but **no observed Timestamp/string mixture** in the current populated records.

## 5. User/Auth identity map

**VERIFIED FROM DEPLOYED FIREBASE**

The Auth account listing completed with **1 account**, selecting only UID, email, emailVerified and disabled fields. Password hashes/salts were not requested. Email is redacted because exact spelling is unnecessary for this mapping.

| Firebase Auth UID | Email | emailVerified | disabled |
| --- | --- | --- | --- |
| `nb3LLlkwB9QlF8ePYqRKPtkhct32` | `[REDACTED]` (present) | false | false |

| User document ID | Legacy role | Document ID equals an enumerated Auth UID? | `auth_uid` | legacy `uid` | `login_enabled` | `active` | `committee_year` | `joined_date` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `nb3LLlkwB9QlF8ePYqRKPtkhct32` | `admin` | Yes, exact match | MISSING | Same as document ID/Auth UID | MISSING | true | MISSING | Timestamp `2026-03-31T17:40:41Z` |
| `HEXfP31SPrYrDXayKcW2` | `president` | No | null | MISSING | false | true | integer 2026 | Timestamp `2026-08-31T18:00:00Z` |

Classification:

- **A — Auth account + matching User: 1.** The legacy developer-admin record is `nb3LLlkwB9QlF8ePYqRKPtkhct32`, supported by its deployed `role: admin`, exact Auth-UID document path, and legacy UID. This is a legacy identity match, not a compliant v1.2 admission state.
- **B — User but no Auth account: 1.** `HEXfP31SPrYrDXayKcW2` is the sole President-role document, with explicit login denial and no linked Auth UID. Its role matches the President record described by the user; who created it and whether it is the intended real-world person were not independently verified. `joined_date` is not a document-creation audit timestamp.
- **C — Auth account but no User: 0 observed.**
- **D — Multiple/ambiguous technical mappings: 0 observed** among enumerated UID/path/auth_uid/legacy-uid matches. Verified human ownership and any future approved link decision remain separate gates.

No duplicate nonempty normalized email, phone, auth_uid, or legacy UID values were found across the two Users. This does not prove absence of real-world duplicate people with different contact details. No links were created.

**VERIFIED FROM SOURCE CODE:** `AuthService._findProfile` reads `users/{authUid}` first, then queries `auth_uid` (limit 2). For a same-ID legacy admin with both `auth_uid` and `login_enabled` absent, it synthesizes an in-memory linked/login-enabled profile. The current deployed admin meets that exception. The login flow does not check `emailVerified`; its sole Auth account currently has false. Actual password login was not tested. Under v1.2, absent `access_role`, `auth_links`, and security fields must not be repaired by inference; the admin needs a protected, explicitly verified bootstrap/recovery plan before strict admission is enabled.

## 6. Firestore rules status

**VERIFIED FROM DEPLOYED FIREBASE**

Release: `projects/rokterbadhon-b247b/releases/cloud.firestore`  
Ruleset: `projects/rokterbadhon-b247b/rulesets/fbb416ea-c159-4515-b43f-a18c009fe7ce`  
Release updated: `2026-09-05T06:23:02.712470Z`. Retrieved source file name: `firestore.rules`, rules version 2.

| Resource | Deployed read condition | Deployed create/update/delete condition |
| --- | --- | --- |
| `users`, `donors`, `donations`, `notices`, `requests` | `request.auth != null` | Caller is signed in, `users/{request.auth.uid}` exists, its `role == 'admin'` and `active == true` |
| Everything else | Denied | Denied |

The five named collection matches apply to their immediate documents. The recursive catch-all denies unspecified paths. No expired test-mode date condition is present in the deployed source. There is no local rules file to compare, so local/deployed parity cannot be established; this is an absent local artifact, not evidence of equal rules.

Security gaps against v1.2:

- Any Firebase-authenticated identity can read full private User documents and all five collections, even without an admitted organization User/auth link. Active/login-disabled state and email verification do not gate reads.
- Donation-history audience, unpublished-notice protection, and active/terminal request audience separation are not enforced.
- Authorization still depends on `users/{request.auth.uid}.role == 'admin'`, rather than authoritative `auth_links` plus `users.access_role` and fail-closed state checks.
- The legacy admin may write arbitrary fields, change identities/roles/security state, and hard-delete documents. Field allowlists, immutable actors/timestamps, valid transitions, referential integrity and protected-admin procedures are absent.
- No trusted-backend-only boundary or mandatory audit recording exists in these rules. Catch-all denial currently protects unimplemented v1.2 paths but also means new v1.2 flows cannot work unchanged.
- An organization User marked inactive would still satisfy the broad read rule if they retain a valid Firebase token. Login/UI checks cannot substitute for server authorization.

These are verified deployed-policy gaps, not claims that exploitation occurred. Management OAuth reads use administrative/IAM access and do **not** prove a Flutter client is authorized. No rule tests or write probes were executed against production.

## 7. Index status

**VERIFIED FROM DEPLOYED FIREBASE:** the project-wide composite-index list returned an empty successful response with no continuation token: **zero composite indexes observed**. Initial requests with pagination options returned HTTP 400; the successful retry without those options is the basis of this finding. After an invalid unfiltered request and a transient timeout, the successful filtered field listing returned only `collectionGroups/__default__/fields/*`: collection-scope ascending, descending and array-contains indexes, all `READY`. No custom field exemption was returned and there was no continuation token.

Read-only donor queries selecting document IDs only confirmed both ordered queries below fail with HTTP 400 and **“The query requires an index.”** The API supplied the corresponding composite definitions. No creation link was followed and no index was created.

**VERIFIED FROM SOURCE CODE:** no local index manifest exists.

| Current query | Index requirement / concern |
| --- | --- |
| Users `active == true`; Users `auth_uid == uid` | Normal single-field index candidates. No name/year composite is required by the current locally sorted/filtered User service. |
| Donors `active == true`, `name ASC` | **Confirmed missing** composite `(active ASC, name ASC, __name__ ASC)` from deployed query error. |
| Donors `active == true`, `total_donations DESC` | **Confirmed missing** composite `(active ASC, total_donations DESC, __name__ DESC)` from deployed query error. |
| Donors `active == true`, `blood_group == value` | Equality-index merging may suffice. Do not invent a mandatory composite without planner evidence. |
| Donations `date >= string` | Indexing cannot fix the Timestamp/string query-contract mismatch. |
| Notices `date DESC`; requests `status == 'active'` | Normal single-field index candidates. Publication/audience changes will require future query review. |

No deployed composite index is available to classify as obsolete. The two donor failures are established by actual read-only query responses, even though there are currently no donor records. Other query variants were not executed. Firestore creates automatic single-field indexes and supports some equality-index merging; source query shape alone does not prove every compound query is missing an index. See [Firestore index overview](https://firebase.google.com/docs/firestore/query-data/index-overview).

**Monthly donation defect:** `lib/services/dashboard_service.dart:98` compares `date` with an ISO string, while `DonationModel.toMap` writes a Timestamp. A successfully executed query is not proof of correct month filtering across incompatible types. The query also has no next-month upper bound. There are currently zero deployed donations, so there is no observed mixed-date data and no populated result to reconcile. This is a confirmed source defect with future data risk, not a discovered corrupted donation record.

## 8. Storage status

**VERIFIED FROM DEPLOYED FIREBASE / CLOUD STORAGE METADATA:** project bucket enumeration returned no buckets and no continuation token. The locally configured `rokterbadhon-b247b.firebasestorage.app` bucket and its object-list request returned HTTP 404. Therefore no current project Storage bucket or object path was discovered. The configured name alone does not mean Storage has been provisioned. No photos were downloaded.

The Firebase Rules release listing returned only `cloud.firestore`; no Storage rules release was returned. No local Storage rules file exists. There is no retrieved deployed Storage policy to analyze or compare. No Storage rule changes were made.

**VERIFIED FROM SOURCE CODE:** `firebase_storage`, `image_picker`, and `cached_network_image` dependencies are declared, but no active Firebase Storage upload/download calls or network-photo rendering calls were found. User/Donor models carry `photo` string fields. Both deployed Users have empty `photo` strings.

V1.2 future paths `profile_photos/{userId}/...` and `donor_photos/{donorId}/...` remain a design contract, not observed objects or granted permissions. Unspecified Storage operations remain denied pending approved readers/writers, size/type checks, ownership, replacement/removal and disable behavior, Rules tests, and App Check.

## 9. Data-integrity findings

| Check | Evidence and result | Risk |
| --- | --- | --- |
| Duplicate Users / Auth mappings | No duplicate populated email/phone/auth_uid/uid values in 2 Users; one Auth account has one exact legacy User match. Real-world identity verification is still outstanding. | MEDIUM |
| Missing `active` | None observed: both raw Users contain true. Source parsers nevertheless default missing/null active to true. | HIGH for future migration defaulting |
| Missing `login_enabled` | Legacy admin lacks it; President explicitly false. No stored true value exists. | HIGH |
| Missing `access_role` / auth links | Both Users lack access_role; auth_links root absent. Strict v1.2 admission would reject both until controlled preparation. | HIGH |
| Legacy role/position mixing | `admin` and `president` are known legacy keys, but neither is a valid v1.2 access role. No unknown legacy role was observed. President office must not automatically grant leader authority. | HIGH |
| Mixed dates / malformed required dates | Both joined_date values are real Timestamps; no malformed/null/string joined_date observed. Other date-bearing collections have no records. Source fallback behavior and monthly query remain unsafe. | HIGH source risk; no current mixed-date finding |
| Legacy metadata | Admin has legacy uid and lacks committee_year; President has committee_year 2026. Proposed creation/security actor metadata is absent. Do not invent historical dates, actors or terms. | MEDIUM |
| Empty string vs null | One User email is empty; both photo fields are empty. Other returned User string fields were not empty. Null auth_uid is explicit only on President. | MEDIUM |
| Donor totals vs donation events | No donors or donations to compare; zero observed discrepancies, not a validation of the algorithm. Source donor creation accepts last_donated without recording an event and defaults total_donations to zero. | MEDIUM latent risk |
| last_donated without event | No current donor records. Source can produce this state; future imports require provenance review. | MEDIUM |
| Orphan donation donor_id / actor IDs | No donation/notice records, hence no observed orphan references. User records contain no proposed created_by actor metadata. | MEDIUM latent risk |
| Requests schema | No deployed requests and no active request model. Only active-status query is known. | MEDIUM |
| Notices without clear status | No deployed notices; source model lacks status and dashboard reads latest without publication filter. | HIGH before notices are populated |
| Account verification | Sole Auth account is enabled but emailVerified false. Human ownership, recovery and v1.2 admission must be resolved through protected procedure. | HIGH |

No names, phone numbers, addresses, patient/contact details, or unnecessary email copies are included. Technical UID matching is not approval to link a person, assign a role, or enable login.

## 10. Migration-risk table

| Priority | Risk | Required gate before any mutation |
| --- | --- | --- |
| HIGH | Existing deployed reads expose private Users/business collections to all authenticated identities | Prepare tested v1.2 admission/audience rules and coordinated cutover; do not deploy during inventory. |
| HIGH | Sole admin relies on legacy implicit login and UID-path authorization | Verify owner and prepare protected admin bootstrap/recovery with explicit states and a rollback route before tightening rules. |
| HIGH | Missing access_role/auth_links and office-based legacy roles | Approve per-User role/identity mapping; never infer privileges from title or absent fields. |
| HIGH | Arbitrary admin writes/deletes and no enforced audit/backend boundary | Design narrow atomic/idempotent operations and tamper-resistant audit enforcement per capability matrix. |
| HIGH | No observed backups; PITR/delete protection disabled | Approve backup destination/access, create recoverable backups in a later authorized phase, validate isolated restore before migration. |
| HIGH | Source date defaults, monthly type mismatch, missing notice publication boundary | Preserve raw types in preparation and test future implementation against fixtures; no data rewrite now. |
| HIGH | Android release uses debug signing | Establish production signing and recovery before release; unrelated to changing inventory data. |
| MEDIUM | Two confirmed missing donor indexes and User metadata gaps | Prepare explicit index and field-mapping proposals; do not create indexes during inventory. |
| MEDIUM | President has no Auth identity | Preserve organization-only state; any eventual admission needs verified identity matching and explicit approval. |
| LOW | Local Firebase identifiers | All inspected IDs match deployed project; continue using explicit project/database selection. |

## 11. Backup readiness

**VERIFIED FROM DEPLOYED FIREBASE:** backup-schedule listing for `(default)` and backup listing in `asia-south1` returned empty successful responses. No managed backups/schedules were observed there. PITR and delete protection are disabled. Project bucket enumeration returned none. This does not exclude external/offline backups in another project or location.

**Available access:** the existing CLI Google-account session can refresh in memory and read project/database metadata, raw documents, Firebase Auth account summaries, deployed rules, composite-index metadata, bucket metadata and backup metadata. Successful reads do not establish export/import, billing, destination-write or restore permissions. No service-account private key was requested or printed. Standard ADC and `gcloud` were not available as described in section 2.

Recommended methods for a **separately authorized** backup phase:

1. **Firestore:** prefer managed export to a new, restricted, explicitly selected backup destination/prefix. Confirm billing, export/service-agent permissions, destination permissions and retention first. Preserve the ruleset, index definitions and a manifest alongside the data, then validate restore in an isolated environment. Managed exports require billing and incur reads/storage charges; see [Firebase export/import](https://firebase.google.com/docs/firestore/manage-data/export-import). For this small database, a deliberately designed type-preserving raw export is a fallback only with completeness, subcollection coverage and isolated restore validation; this redacted inventory is not a backup.
2. **Firebase Auth:** use the supported `firebase auth:export` workflow with explicit project and a new restricted output path, only after authorization. Preserve UID/provider/disabled/verification state and required restore configuration. Export artifacts may include password hashes/salts: these are sensitive restore material, not plaintext passwords, and must never enter this report or repository. No such material was retrieved here. See [Firebase Auth import/export](https://firebase.google.com/docs/cli/auth).
3. **Storage:** no project buckets currently need an object backup based on this scan. If objects appear before migration, enumerate them again and copy objects plus relevant metadata/generations to a protected destination without deleting or overwriting source data; verify the copy. See [Cloud Storage object copying](https://docs.cloud.google.com/storage/docs/copying-renaming-moving-objects).

**Not currently established:** authorized backup destination, billing/export permissions, full Auth restore-material permissions, encrypted artifact handling, backup completeness and successful restore. Additional operator/IAM access may be required. No export, bucket creation, billing change or restore was attempted. Existing external backups and administrative recovery ownership remain unverified.

## 12. Unknown/unverified items

**NOT VERIFIED:**

- Execution of query variants other than the two donor index probes; section 7 records verified index metadata and the two confirmed failures. Use read-only representative queries as needed; do not create indexes during verification.
- Any data below missing parent documents. Both existing User documents have no listed subcollections, but root enumeration and existing-parent checks are not a recursive export. Complete recursive, raw, privacy-preserving enumeration before a future export is declared complete.
- Historical/deleted documents, external backups, previously deleted buckets, other-project resources, or Auth tenant accounts outside the default project account listing. No tenant configuration was inspected.
- Current email/password ownership, MFA/recovery configuration, Auth-provider/sign-up settings, and whether the operator is the intended protected developer administrator. UID matching alone cannot verify these.
- App Check enforcement, cloud IAM role breadth, billing status, Cloud Functions inventory, crash-monitoring setup, retention/privacy implementation and release certificate identity. No absence is inferred from uninspected console settings. App Check/Crashlytics dependencies were not found in the inspected pubspec, but that does not establish project enforcement state.
- Actual Flutter runtime/login behavior and end-user allow/deny tests. No production write probes, rules deployment, emulator setup or app execution was performed.
- Real-world approval/provenance for President identity and future access_role. An authorized administrator must verify it without copying personal evidence into this report.

Minimum manual continuation for unknowns: select **`rokterbadhon-b247b` / `(default)`** explicitly in Firebase/Google Cloud consoles; view index configuration and subcollections, Auth provider/recovery settings, App Check, IAM/billing and backup metadata. Record only schema/state/redacted results. Grant only necessary read permissions if an endpoint is inaccessible; do not supply private keys in chat. None of these checks authorizes mutation.

## 13. Recommended NEXT SAFE STEP

**Safe to proceed to backup and migration preparation as planning/read-only verification; not safe to run migration or deploy v1.2 yet.**

Prepare a concrete backup/restore and protected-admin recovery proposal using this observed two-User/one-Auth baseline. Resolve remaining inventory-coverage questions, include the two confirmed missing donor indexes in the future implementation plan, designate a secure destination and verify required permissions. Before any future migration, create separately authorized backups, validate an isolated restore, approve explicit identity/role mappings, and coordinate the admission/rules/client cutover so the sole administrator is not locked out.

Preserve President login denial. Do not create auth_links, infer leader permissions, normalize dates or populate missing security fields during preparation. The next mutation phase requires its own explicit scope. Inventory stops here.

# Rokter Badhon Ghatail — Free V1 Implementation Feasibility

Date: 2026-09-08  
Baseline: **Production Architecture v1.2 — FROZEN FOR IMPLEMENTATION**  
Disposition: **Reduced Free V1 is feasible; full v1.2 hosted automation is not.**

This is a feasibility/design proposal, not implementation or an amendment to the frozen contracts. The owner's Spark-only constraint supersedes the earlier operational cloud-first provisioning direction. Security/data invariants remain binding. Proposed new entities, permissions and narrower direct-write exceptions need the small v1.2.x amendments identified in section 20 before their implementation. Unamended/unlisted operations remain denied.

All requested architecture, capability, migration, checklist, inventory, recovery and cloud-preflight documents were reviewed. Only this document is created. No Firebase reads or changes, exports, billing, deployment, dependency changes or Flutter/Dart changes were performed. Previous inventory is historical evidence, not a refreshed snapshot.

## 1. Free-V1 constraints

- Firebase Authentication and Cloud Firestore on **Spark only**, with no billing account linkage, Blaze upgrade, paid Cloud Functions/Cloud Run, paid cloud project or Firebase Storage bucket.
- No promise of unlimited availability: quota exhaustion causes reduced service/denial, never an automatic billing upgrade or authorization bypass.
- External image provider remains unselected. It must offer an acceptable no-cost plan without required paid infrastructure or embedded reusable secrets. No provider is hardcoded as final.
- No bytes/base64 images in Firestore. Store approved HTTPS URLs and only necessary non-secret metadata.
- Only `users.access_role` authorizes application roles: developer_admin, leader, executive, committee, member. Positions, history, directory records and provider identifiers never grant authority.
- Preserve verified-email admission, explicit active User/link/login states, auth_links-only identity mapping, target restrictions, actor provenance, Timestamp validation and historical references.
- Paid managed backups are not Free-V1 gates. Reliable protected manual capture and restore validation remain gates.

The known two-User/one-Auth baseline needs reviewed migration, not automatic conversion. The legacy admin still needs independent identity verification and explicit protected bootstrap. The President remains organization-only with `login_enabled = false`; no role or link is inferred from president officeholding.

## 2. Spark capabilities used and operating limits

Use email/password Auth, verification/reset emails, Firestore reads/queries, Security Rules, atomic batches/transactions, indexes and local emulator tests within current free quotas. No SMS/phone authentication or paid attestation/provider feature is assumed. Google documents that paid Google Cloud products such as Cloud Run are unavailable on Spark; hosted Functions deployment is not selected for Free V1. See [Firebase pricing plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).

Use paginated bounded queries, unsubscribe unused listeners, cache only permitted data, avoid full-collection dashboard downloads and budget extra Rules reads plus operational capture traffic. Check Firestore free storage/read/write/network quotas before release and monitor usage manually. Firestore PITR, managed backup/restore and managed exports are outside the selected free workflow. See [Firestore quota requirements](https://firebase.google.com/docs/firestore/quotas).

Auth email/account limits and abuse controls still apply. Do not confuse basic Auth limits with Identity Platform-specific limits or assume no-cost email delivery is unlimited. Handle exhausted quotas with localized retry/support messages. See [Auth limits](https://firebase.google.com/docs/auth/limits).

App Check is usable subject to its attestation provider's quotas and supported distribution settings; it supplements authentication/Rules, not authorization or guaranteed bot prevention. Validate controlled APK and Play signing before enforcement; no production debug bypass. External image requests are not automatically protected by Firebase App Check. See [App Check](https://firebase.google.com/docs/app-check).

## 3. Capability feasibility matrix

Classification:

- **A — SAFE ON SPARK:** supported identity/read/UI feature, always with applicable admission/audience constraints.
- **B — SAFE WITH AUTH + RULES / TRANSACTIONS:** bounded client operation whose complete invariants can be checked server-side. Proposed exceptions are explicitly marked; tests are mandatory.
- **C — REQUIRES TRUSTED EXECUTION:** v1.2 requires backend control or evidence unavailable to Rules. Hosted Firebase execution needs Blaze; a reviewed operator-run trusted program can execute limited actions against Spark without a hosted paid service. C does **not** mean every trusted computation inherently requires billing.
- **D — DEFER / REDUCE:** no Free-V1 application workflow or no current grant. C operations have D self-service automation, even when a controlled operational version is included.

Role abbreviations: DA = developer_admin, L = leader, E = executive, Cmt = committee, M = member. Every existing target/scope/field restriction remains as specified in CAPABILITY_MATRIX; eligibility is not a new grant. The following groups cover the existing capability keys, including denied rows, plus the requested new features.

| Capability / feature | Class | Free-V1 disposition and enforcement |
| --- | --- | --- |
| Email/password self-registration | A | Creates Firebase identity only; no organization privileges. Include only after request-only Rules boundary and operator review process pass. |
| Email verification, password reset | A | Firebase owner-controlled messages; no leader password handling; verification required before protected admission. |
| Auth/session restoration and protected reads | B | Resolve exact own auth link and own User; Rules enforce all explicit gate states. Self-link lookup needs an explicit narrowly scoped read contract in the amendment, not broad auth_links listing. |
| `registration.create_own` | B, proposed amendment | Exact own UID create with rule-fixed pending state, identity and server time; no update/list/delete or selected target. See section 8. Existing backend-only creation is not silently reinterpreted. |
| `registration.read_own_status` | A | Existing E exception, own document only while no link exists; all other protected collections denied. |
| `registration.review` | A | DA/L may read only the currently granted pending review audience. |
| `registration.approve`, `registration.reject` | C / D automation | Identity review plus operator-run validated transaction/audit; no leader-client approval write. |
| `user.create` | C | Organization-only creation by controlled operator workflow for eligible DA/L initiation, Q and exact schema; login false, no Auth/link implicitly. |
| `user.own_read`, `directory.view`, `user.directory_read` | A | Exact own private User; active directory only. No broad private User reads to render names. Alias retains identical scope. |
| `user.own_profile_edit`, `user.profile_edit` | B, proposed amendment | Atomic Rules-constrained own profile/projection update; no security/identity edits. Profile image URL direct writes additionally gated by provider validation; see sections 9/12. |
| `directory.sync` | B/C, proposed narrow Q amendment | Not independent permission: B only as constrained own-profile effect; all privileged changes/backfill remain C. |
| `role.assign_member`, `role.assign_committee`, `role.assign_executive` | C | Operator validates initiating DA/L and ordinary-target restrictions; no direct Flutter role writes. |
| `role.assign_leader` | C | DA initiation only, not leader promotion; protected operator execution. |
| `admin.provision`, `admin.recover` | C | Protected operational P, not application-role authority; independent custody and atomic audited repair. |
| `user.disable`, `user.reactivate`, `login.enable`, `login.disable` | C | Ordinary targets only; trusted transaction preserves independent active/login/link semantics and Q. |
| `user.disable_leader`, `user.reactivate_leader`, `login.enable_leader`, `login.disable_leader` | C | Only DA initiation for leader targets; no leader self/peer/admin management. |
| `auth_link.create`, `auth_link.replace` | C | Verified ordinary target and Firebase identity; serialized one-active-link enforcement; old link retained inactive. |
| `auth_link.create_leader`, `auth_link.replace_leader` | C | Explicit DA-only leader target workflows; protected-admin links require P instead. |
| Firebase Auth account disable / session revocation | C | Privileged Auth administrative API/console action with explicit incident scope; not a Flutter grant. Cross-service failure handling required. |
| `password.organizational_management` | D | Always denied; no password disclosure, storage or organization-managed assignment. |
| `committee.view` | A | Current/past terms and assignments per baseline; resolve active directory only. |
| `committee.assign` | C | Trusted audited assignment for eligible DA/L; at most one active User/term slot; shared position keys allowed. |
| `committee.term_create`, `committee.term_end` | D until amendment | Existing all-DENY; proposed rare owner editorial/import workflow only after explicit lifecycle capability approval. Photos do not grant term-creation authority. |
| `committee.assignment_end`, `committee.assignment_correct` | D | Retain denial. Historical import is separately reviewed; no implicit lifecycle grant from assign. |
| `donor.view_search` | A | All admitted roles, active donor audience only. |
| `donor.create` | B | DA/L/E/Cmt; exact initial count/date/link fields; no caller historical aggregates or linked User. |
| `donor.edit` | B | DA/L/E; allowed profile fields only, protected actors/times; no count/state/link edits. External photo fields remain provider-gated. |
| `donor.deactivate_archive` | C | DA/L via trusted audited retained deactivation. |
| `donor.hard_delete`, `donor.reactivate`, `donor.link_user` | D | Existing denials retained; no implied retention/privacy exception. |
| `donation.record` and donor aggregate update | C / D in-app recording | Trusted consistent event/aggregate transaction for eligible DA/L/E/Cmt. Committee receives only minimal acknowledgement, never history. |
| `donation.history_view` | A | DA/L/E only; Cmt/M denied even on self-recorded events. |
| `donation.correct_history` | C | DA/L, controlled correction/reconciliation/audit; no arbitrary counter fixes. |
| `donation.delete_history`, `donation.archive_history` | D | No deletion or invented archive field/collection. |
| `notice.view_published`, `notice.view_unpublished` | A | Published: admitted roles. Draft/archived: DA/L only. |
| `notice.create`, `notice.edit`, `notice.publish`, `notice.archive` | C / D automation | Existing AP audit requirement retained; owner-operated editorial transaction with valid eligible initiator and states. |
| `notice.restore`, `notice.delete` | D | Remain denied. |
| `blood_request.view_active`, `blood_request.view_terminal` | A | Active: admitted roles; terminal: DA/L/E only. No terminal edit/reopen grant. |
| `blood_request.create` | B | All admitted roles; exact schema, creator and active initial state; no member edit privilege inferred. |
| `blood_request.edit`, `blood_request.fulfill`, `blood_request.cancel` | C / D automation | Existing DA/L/E/Cmt scope and AP evidence retained; operator-run transaction. If timely operator coverage is unavailable, do not release an emergency workflow that implies immediate fulfilment. |
| `blood_request.delete` | D | Denied. |
| `audit.read` | A | DA only; whole minimal event audience. |
| `audit.write` | C | Operational trusted writer only; no direct client privileged-log creation. |
| `audit.modify_delete`, `capability.unlisted` | D | Deny; no role wildcard. |
| `storage.unspecified` and Firebase Storage images | D | No Firebase Storage use, bucket or app credentials. |
| Profile external image display | A, after provider approval | HTTPS approved-host URL plus local fallback; ordinary image URLs are not private authorization tokens. |
| Committee group/gallery display | A, proposed audience amendment | Current/past organization history; no public read inferred. |
| Events/event-gallery display | A, proposed audience amendment | Admitted active content; hidden history only proposed DA/L audience. |
| Events/media/cover/URL editorial writes | C, proposed capability amendment | Owner-operated upload/publication with provenance/audit and referential validation; in-app upload/editor mutation deferred initially. |
| Arbitrary external upload / reusable provider secret in APK | D | Reject. Conditional restricted provider-native direct flow needs separate security approval. |
| Free raw Firestore/Auth/config capture | C | Protected manual operational backup, no app bulk-export capability. |
| Managed exports/imports, PITR, managed backups | D / future Blaze | Not Free-V1 requirements. |
| App Check | A/B | Supported no-cost attestation/enforcement within quotas; validate legitimate clients and operational access separately. |
| Scheduled/background jobs | D | No paid scheduler/backend; manual reminders/checklists, on-read UI calculations only. No guaranteed device background job for security/sync. |
| Localization, normal UI, local avatar, bounded dashboards | A | bn default/en optional; stable keys; authorized queries; no local filtering as access control. |

## 4. Included V1 features

Proposed included product: verified-email login/session lifecycle; request-only onboarding with manual decisions; own profile and safe directory; current/past committee display; external profile/group/gallery images; events/history/gallery browsing; donor creation/edit/search within existing role grants; donation history and operator-recorded donations; published notices; scoped blood requests; bn/en UI and basic settings.

Included does not mean every management action gets a Flutter button. Administrative/editorial actions use the reviewed operational workflow below. Expose their actual service limitations, such as awaiting operator review; do not report a mutation as completed before it is committed. New event/media audiences are proposed policy, not effective until approved. Core donor/profile/read modules may ship before provider/media readiness; required photo/event modules cannot be declared complete until their gates pass.

## 5. Deferred features

Defer hosted approval/link/role/account endpoints; instant leader administrative mutation; fully automated auditable business writes; arbitrary direct gallery uploads; provider-mediated signed uploads requiring an unavailable signer; automated asset deletion/cleanup; scheduled reports/reminders/backups; managed cloud exports, paid recovery and Firebase Storage.

All previously unlisted capabilities remain denied, including committee lifecycle/correction, donor reactivation/linking, archived-notice restoration and destructive history operations, except narrowly proposed new editorial grants after amendment. No face recognition, biometric identification or photo-person tagging is included. No speculative multisite or multi-organization layer.

## 6. Trusted-backend conflicts and resolution

Spark removes hosted execution, not the need for trusted validation. Rules cannot call Firebase Admin Auth to verify another identity's current disabled/email state, inspect provider bytes, perform private image deletion, or securely obtain a client-supplied approval's real-world identity evidence. Rules cannot run arbitrary collection-wide reconciliation or external side effects. Transactions alone do not authorize their contents.

Select a **reviewed, operator-invoked local trusted tool** for rare C actions, running on a secured operator machine with existing approved Google operational credentials, not credentials embedded in Flutter. No hosted cloud service, paid infrastructure or new service-account key is assumed. Admin SDK/administrative REST accesses bypass client Rules; the tool must enforce capabilities, target scopes, invariant checks and reliable logs itself. Its reads/writes still consume Spark quotas. This tool is future implementation, not present or executed now.

If secure custody/tooling or operator availability cannot be provided, keep those writes disabled. The reduced app can be read-only for affected modules; it is not acceptable to remove audit requirements or allow generic Console writes to preserve convenience. Hosted automation is not the only technical solution, but frequent manual transactions can make the full product operationally impractical.

## 7. Safe reduced/manual workflows

For ordinary C actions: identify and verify the eligible initiating User, re-read their current Auth/admission state and capability/target at commit, record a minimal authenticated instruction/reason, and execute a fixed operation with a reviewed field diff and operation ID. The operational executor is attributable independently; never label a different person as the authenticated actor. Non-null actor fields reference real User/Auth IDs. Use documented system/recovery null actors only where DATA_MODEL permits, not to fabricate ordinary administrative provenance.

Commit business/security state, exact directory effect and required audit event in one Firestore transaction where applicable. Compare preconditions, reject stale/conflicting input, retry without duplicate effects and keep external Auth/provider operations outside that atomic boundary with explicit recovery states/checkpoints. Preserve later revocations on retry and rollback.

Use a common serialization boundary for all link writers: every operation reads/writes the target User as the shared concurrency anchor (existing update metadata can carry the serialization write), queries for conflicting active links within the transaction, and rejects conflicts. Review and test the exact server transaction implementation. Assignment writers similarly serialize on their term/User slot or an approved shared term transaction write; no unchecked query-then-write. Do not add an unreviewed lock collection or replace all history with a single deterministic assignment document. All writers must follow the same protocol; direct client writes remain denied.

Manual Firebase Console is suitable for inspected identity metadata and separately authorized one-account incident actions. Sequential Console edits of User, directory, link, approval and log **do not meet atomicity**. Do not call them a substitute for the transaction tool. Emergency Auth disablement may be performed operationally with attributable incident evidence, followed by controlled Firestore denial/Q and revocation handling; no claim of cross-service atomicity.

## 8. Registration and auth-link decision

**Select:** Firebase self-sign-up plus a Rules-constrained own pending request; manual/trusted operational approval and linking. **Do not allow direct leader-client approval/link writes.**

Proposed create-own Rules contract (requires amendment to the backend-construction wording): authenticated caller, no auth-link document of any state, document path exactly request.auth.uid, create only, complete exact field allowlist and types. App input remains name/phone/email only. The client service supplies the structural fields required for storage, but Rules accept only `auth_uid == request.auth.uid`, `email == token email`, `status == pending`, `requested_at == request.time` through serverTimestamp, and all decision/linked fields explicitly null. No position, access_role, login flags, target User, extra fields or supplied alternate time can pass. The attacker can send bytes; they cannot choose alternative accepted security values. Rules enforce facts; UI constants do not.

An existing request cannot be overwritten; a retry reads the existing own status rather than updating it. E does not require verified email, grants no collection listing and no business/directory/private User reads. A present broken/inactive link excludes E. After a link is created, use the admitted gate; link existence must never imply admission by itself. Exact own-link lookup is the minimal additional Rules read needed to resolve sessions; other links/listing denied.

Approval validates the applicant's current verified Firebase identity via trusted operational access and verified organizational identity evidence, not submitted matching strings alone. It must not activate President login or create their link without an independent explicit approved action. Link creation/replacement uniqueness and protected-admin exclusions remain enforced by the transaction tool. Rejection also remains audited operational work despite being technically simpler to constrain with Rules.

Rules can enforce a pending record but cannot ensure delivery quotas, global sign-up abuse resistance or real-world identity matching. Include Firebase anti-abuse limits, App Check where supported and a staffed review process. If E's exact field/audience Rules are not proven, defer self-registration and retain operator-assisted account admission rather than granting wider access.

## 9. User-directory synchronization decision

**Choose a narrow Rules-enforced atomic own-profile exception; retain trusted Q for every privileged User change.** This changes enforcement placement, not the invariant or directory audience, and needs an explicit v1.2.x Q amendment. Until then all direct directory writes remain denied under frozen v1.2.

Required proof obligations for the two-document own-profile batch/transaction:

1. Resolve caller through existing active auth link and valid pre-state User. Only update that existing own User; no client User creation/deletion or account repair.
2. Validate exact schema and changed-field allowlist. Only own permitted profile fields plus Rules-bound `updated_at == request.time` and `updated_by == ownUserId` may change. Email, role, active, login, created metadata and links are immutable in this path. Photo URL changes require the additional provider gate below.
3. User write requires `getAfter(user_directory/ownUserId)` to equal the exact projection of the post-write User. Directory write requires `getAfter(users/ownUserId)` to equal its six-field projection: name, phone, blood_group, profession, photo_url, active, with no extra fields.
4. Directory writes require the same own-profile actor/state, a real permitted User profile change and the bound updated metadata in the atomic post-state. The User pre-state must have a validated existing projection; clients may not create/repair a missing directory record. Provisioning/backfill repairs are operational. For address/language-only changes where projection is unchanged, allow no directory write; post-state equality still holds.
5. Standalone forged/stale directory writes, cross-user writes, partial User changes that would desynchronize it, missing fields and creation/deletion must fail. Client-supplied projection is verified against authoritative post-state, never trusted as authority.
6. All privileged operator writes apply Q atomically too, including active false propagation. Concurrent own edits must serialize/retry against current security state; no offline stale update may reactivate anything.

Firestore `getAfter` can enforce post-transaction document relationships; batch limits are 20 document-access calls overall and 10 per operation. Count gate/pre/post lookups explicitly and test worst cases rather than assume caching saves the request. See [atomic operations and Rules](https://firebase.google.com/docs/firestore/manage-data/transactions) and [field restrictions](https://firebase.google.com/docs/firestore/security/rules-fields).

**Conclusion:** secure atomic projection is technically achievable for this bounded own-update case, but has not been implemented/proven here. If bidirectional validation, schema/provenance or call limits fail testing, reduce to operator-only profile editing with read-only directory. Never choose asynchronous client repair or independently writable projection as fallback.

## 10. Audit integrity decision

Keep `audit_logs` creation trusted-only, updates/deletes denied to all application clients and reads DA-only. Operational tool writes are bound to reviewed actions, server time and actor evidence, and committed atomically with their Firestore mutations. Append-only against application clients does not mean immutable against privileged Google administrators; secure tool/credential custody and protected external operational evidence are required.

For B operations such as donor create/edit, own profile and request creation, validated actor/time/immutable creation fields are acceptable **write metadata**, not proof that all historical actions were captured. A Rules-constrained actor/time prevents impersonation within the client boundary; it does not prove truthful clinical/event content or satisfy every AP/AS requirement.

Rules could constrain a paired append-only client event, but this plan does not reinterpret it as v1.2 backend-owned privileged audit. Notice publishing, request status transitions, donor deactivation and donation correction therefore remain C. Operational failed attempts receive external attributed evidence and must not appear as committed application events. No passwords, tokens, private identity proofs or full sensitive documents in logs.

## 11. External image architecture and security

Introduce a provider-neutral image boundary in future services: validate approved asset reference, display safely, request replacement, and submit controlled removal work. The provider is **not selected**. Evaluate free storage/bandwidth/transformation quotas, no required billing, HTTPS stability, signed/private versus public delivery, upload restrictions, credential custody, MIME/content sniffing, maximum bytes/dimensions, orientation/EXIF removal, ownership, replacement/deletion API, moderation and account recovery. No provider shortlist is treated as approval.

**Recommended initial upload path:** designated operator uploads through the provider's authenticated dashboard, validates content/privacy and pastes the approved HTTPS asset URL into the trusted editorial tool. Firebase receives only validated URLs/metadata. This is practical without an always-on signer. Never send provider admin credentials to leaders' Flutter clients.

Provider-native scoped user authentication or short-lived restricted upload capabilities may later work without our paid backend if the provider securely verifies identity, constrains owner/path/type/size/rate and offers acceptable no-cost service. A reusable unsigned preset inside an APK is extractable; client validation and obscurity do not secure it. A signed upload needs a trusted signer somewhere, not a signing secret in Flutter. Defer direct uploads unless the selected provider's complete abuse/ownership/security model passes review.

Firestore Rules can check URL form/approved host and actor permission, not download bytes or verify MIME, availability or ownership. Use HTTPS only, bounded URL length, approved hostname/path rules, no userinfo/private-network host, no embedded long-lived access credentials and no arbitrary redirects accepted by the publishing workflow. Server-side/image-provider validation must examine actual content; extension or declared Content-Type alone is insufficient. Recommend non-animated JPEG/PNG/WebP initially, with byte/dimension limits finalized against the provider; reject active SVG/HTML content. No image binary goes into Firestore.

Public long-lived image URLs are shareable outside Firestore audiences. A hidden/deactivated record cannot retract a copied URL or cached image. Obtain appropriate consent and exclude sensitive patient/contact/identity material. If private delivery is required, require secure provider-controlled expiring delivery; do not pretend a secret-looking URL provides v1.2 privacy. If that cannot be supplied free, omit the sensitive image rather than weaken privacy. No biometric analysis.

## 12. User profile image design

User has one current `photo_url: string | null`; directory carries the same value via Q. Null/missing, malformed, blocked, loading/error or deleted remote images show a bundled local avatar. A URL failure never prevents login or profile/committee navigation. Target writes require explicit null/valid URL; display fallback is not a silent schema migration.

Replacement: upload/validate a new immutable asset first; atomically switch User/directory URL; only then attempt old-asset cleanup after confirming no retained references. Failure to delete the old asset is recorded for manual retry and must not undo the working new URL. Do not reuse mutable provider URLs that overwrite historical content. Revoked users cannot submit URL changes.

Initial Free V1 keeps photo_url mutation operational while the provider/ownership policy is unresolved. The proposed direct own-profile path can initially support the other six permitted inputs (name, phone, blood_group, profession, address, preferred_language). Enabling direct URL selection later needs an approved host/ownership/content workflow, not just HTTPS validation. Users may request a photo change operationally; no new request collection is introduced by this plan. Provider asset IDs for single-profile/cover assets can remain in the restricted operator inventory; no additional User/security/directory fields are needed.

## 13. Committee image design

Each term owns its nullable `group_photo_url`; term rollover never copies over or overwrites the prior term's asset. Read past inactive terms under the existing committee-history audience. A term's active=false means historical, not automatically hidden: gallery read eligibility is based on permitted committee history and media.active, not a requirement that the term remain current.

Additional photos use committee_media with an immutable term_id and asset URL after publication. One image record can depict many people without individual tags. Correction of caption/order/hide is operational and audited. To replace image bytes, publish a new media record and hide/retain the old one; no destructive historical rewrite. Archived images cannot be deleted externally while retained references still require them. A missing cover shows a local placeholder; gallery loading errors do not hide the committee record itself.

Proposed new reads: all admitted roles may read active committee media tied to a readable existing term; hidden media DA/L only. Proposed term photo/gallery writes: operational owner editorial path with verified DA/L initiation, not position-based authority. These new grants and term lifecycle setup must be explicitly entered in the matrix before release; current term-create/end denials do not disappear implicitly.

## 14. Events and galleries

Events represent meetings, donation campaigns, awareness programs, social activities, celebrations, emergency activities and other programs. `event_date` is the known scheduled/actual instant, distinct from creation time; an event with unknown required date stays out of publication rather than using now. Display calendar boundaries in Asia/Dhaka. Past dates remain visible history while active=true.

Proposed reads: all admitted roles can read active events and active event_media whose existing parent event is active; DA/L may review hidden events/media. No anonymous audience. active=false is hidden retained history, not deletion or a role change. A gallery query must constrain event_id/active and satisfy parent authorization; no broad download followed by local filtering.

Proposed operational DA/L editorial actions: create event, edit content/date/location, set/replace cover, hide event, add photo, caption/reorder/hide photo; valid types/references/actors and trusted AP audit required. Reopening hidden content and permanent deletion remain denied until expressly approved. Past event editing needs a correction reason. Child parent IDs and published image URLs remain immutable; replacement creates a new media record. One event has many photos, paginated and bounded; parent hide immediately denies ordinary child reads without rewriting all children.

These are proposed new capability rows, not an implementation grant from a generic manage permission. Retention/content consent must cover people in photos. No payment, ticketing, location tracking or biometric fields are introduced.

## 15. Exact proposed schema additions

All listed keys are the complete proposed creation schema for new entities; nullable keys are explicitly null when absent. IDs come from document paths. Non-null *_by values reference existing application User IDs. All machine dates are Firestore Timestamp, not ISO strings. Unknown required values block publication/import; no DateTime.now fallback. Text is user content, never executable markup. Proposed validation bounds: title/caption up to 200 characters, description up to 5,000, location up to 300, URL up to 2,048, provider_public_id up to 512; finalize against provider constraints before coding.

### Existing CommitteeTerm: one additional field only

```text
committee_terms/{termId}
  group_photo_url: string | null  # approved HTTPS asset URL
```

All existing term fields/invariants remain. Photo edits need trusted audit because the existing term schema has no updated metadata. No photo or title confers authorization.

### CommitteeMedia

```text
committee_media/{mediaId}
  term_id: string
  image_url: string
  caption: string | null
  sort_order: integer             # >= 0; ties resolved by document ID
  active: boolean
  uploaded_at: Timestamp
  uploaded_by: string
  provider: string | null
  provider_public_id: string | null
```

### Event

```text
events/{eventId}
  title: string
  description: string | null
  event_type: string
  event_date: Timestamp
  location: string | null
  cover_image_url: string | null
  active: boolean
  created_at: Timestamp
  created_by: string
  updated_at: Timestamp | null
  updated_by: string | null
```

event_type keys: `meeting`, `blood_donation_campaign`, `awareness_program`, `social_activity`, `celebration`, `emergency_activity`, `other`. New record: active=true, created time/actor trusted, updated pair null; later edits set both updated fields. The boolean is not a draft workflow: unfinished records stay outside published Firestore until complete or enter only an explicitly approved hidden editorial workflow.

### EventMedia

```text
event_media/{mediaId}
  event_id: string
  image_url: string
  caption: string | null
  sort_order: integer
  active: boolean
  uploaded_at: Timestamp
  uploaded_by: string
  provider: string | null
  provider_public_id: string | null
```

Both media types: required existing parent, nonempty approved HTTPS image URL, active=true on publication, trusted server upload/publication-record time and accountable uploader. `uploaded_at` means when this asset record was registered by the controlled upload workflow, not the photograph's historical capture date; document this for imported old photographs. Creation actor/time and parent/asset fields are immutable. Caption/order/hide corrections produce operational audit rather than adding redundant update fields.

**Metadata decision:** include nullable provider/provider_public_id on gallery records because multiple assets need stable removal/replacement handles. provider is a stable language-neutral key selected later; non-null public ID requires a non-null approved provider. Unknowns remain null. Provider IDs are not credentials and grant no delete permission; deletion authority stays outside Firestore/client. Do not include API secrets, signatures, access tokens or face IDs. Public readers can see these fields because Firestore reads whole documents; a provider that treats its asset identifier as secret cannot use this schema without a deliberate sensitive-data split. Profile/term/event cover tracking remains in the protected operational asset inventory to avoid unnecessary entity fields.

No image bytes, arrays of all photos on the parent, counters, provider credential collection or generic media ACL system is added. Anticipated indexes: committee_media(term_id, active, sort_order), event_media(event_id, active, sort_order), events(active, event_date), with stable pagination tie-breaks. Verify exact planner requirements during emulator/staging implementation; no indexes are created now.

## 16. Free backup strategy

**CURRENT Free V1:** operator-run type-preserving raw Firestore capture; supported Firebase Auth export if credential scope permits; exact deployed Rules/index/config and application/migration manifests; encrypted artifacts; verified cloud/offline copy outside the app project; periodic manual capture and an additional checkpoint before every major migration/release. No app bulk-export grant.

Raw capture must fully paginate roots/subcollections (including missing-parent descendants), retain IDs, Timestamp precision, integer/reference/array/map types, null versus absent versus empty values, counts and capture bounds. No Flutter model deserialization or historical normalization. Quiesce known writers or reconcile changes; no false cross-service snapshot claim. A new restore tool must prove raw format round-trip in an emulator/isolated no-cost test environment. Managed import is not how raw JSON is restored.

Auth export may contain password hashes/salts; protect temporary plaintext, encrypt before copying, verify checksums and credential recovery coverage without printing values, then perform defensible cleanup. Preserve disabled/verification state and separate hash configuration custody. Existing export permissions do not authorize a run. The Windows encryption status remains unresolved; choose verified protection before any plaintext capture.

Select an existing acceptable no-cost cloud file-storage account or encrypted offline medium for protected copies; no paid GCS resource or new billing. Provider and custody are not selected; quotas, sharing, recovery and retention need review. Do not use the image provider for Auth backup. A single laptop copy is not adequate. Manual reminder/backup register replaces paid scheduling; record owner, interval, maximum tolerable loss and restore evidence before release.

## 17. Future Blaze-only references and deferred automation

For Free V1, classify the following unchanged documents as **FUTURE / BLAZE OPERATIONAL REFERENCE** through this superseding strategy decision: CLOUD_BACKUP_DESIGN.md, CLOUD_BACKUP_READINESS.md and CLOUD_PROVISIONING_PREFLIGHT.md. Their billing, project, bucket, IAM and managed-export next steps are not current instructions. The managed-cloud-export portions of BACKUP_AND_RECOVERY_PLAN.md and PRODUCTION_CHECKLIST.md need later small operational amendments; preserve their valid custody, audit, rollback and restore requirements.

Future owner-approved Blaze may support hosted trusted Functions/Cloud Run, managed export/import and scheduled processing. Those are not automatically authorized by free usage allowances on a paid plan. External provider-mediated uploads could also require future hosted signing, but no such infrastructure is selected now. App Storage remains unused even in future unless separately redesigned.

## 18. Exact implementation sequence and exit gates

| Phase | Work / exit gate |
| --- | --- |
| 1. Finalize Free-V1 contract | Approve narrow E/Q exceptions, manual C operating model and new entity audiences/rows; publish reviewed v1.2.x documentation amendment. No source/data change in this task. |
| 2. Local Rules foundation | In a separately authorized task, add source-controlled deny-by-default Rules and emulator-only positive/negative tests. No production deploy. Prove E/G, own link read, private/directory audiences, own-update projection, missing fields and atomic call budgets. |
| 3. Migration/backup preparation | Build raw-preserving capture/restore and validation plans/tooling with synthetic fixtures; perform only separately authorized encrypted backup/rehearsal before any production data mutation. Resolve legacy field/date provenance. |
| 4. Protected admin bootstrap tooling | Fixed-scope operational transaction runner, custody/actor/idempotency/rollback tests; rehearse sole-admin recovery and preserve President denial. No real bootstrap until separate approval. |
| 5. Auth/session architecture | Implement fail-closed models and auth_links-only login/session resolution, verification, cache cleanup and revocation; use fixtures/emulator until coordinated cutover. |
| 6. Registration/onboarding | Exact Rules-constrained create-own/status plus operator decision process; test unlinked/unverified/linked states and partial Auth failures. No direct approval/link writes. |
| 7. User/directory | Implement six-field own-profile subset and atomic projection; privileged User operations through tool; test malformed/missing/stale directory denial. |
| 8. Committee history | Approved term import/lifecycle scope, history reads and trusted assignment tool; test concurrent one-active-User/term invariant, shared positions and no role effects. |
| 9. External image abstraction | Provider evaluation/selection, no-secret upload method, privacy/host/type/size checks, immutable replacement and fallback tests. Provider gate blocks real upload/URL publication. |
| 10. Committee photos | Term-owned cover and paginated gallery readers; operator editorial/audit path; historical preservation and hidden-asset behavior. |
| 11. Events/galleries | Exact new schemas, approved audiences and trusted editorial path; parent-hide child-read enforcement and historical correction tests. |
| 12. Donors | Rules-constrained create/edit/search; no client aggregate/link/state changes; pagination and indexes validated. |
| 13. Donations | Operator event/aggregate transaction and correction tests, baseline reconciliation and Cmt history denial. If operator throughput is insufficient, defer live recording module. |
| 14. Notices | Read audience/status queries plus audited operator publishing/archive; no client audit substitute. |
| 15. Blood requests | Direct safe create, audience queries and operational audited edit/fulfil/cancel; publish realistic response coverage before release. |
| 16. Localization | bn default/en optional across every feature; stable event/provider/position keys. Establish resources from phase 2 onward; this phase completes coverage. |
| 17. UI redesign | Capability-based UX, pending/operational states, image errors/local fallback and accessible history/gallery views; no cosmetic changes to security contracts. |
| 18. Security/testing/release | Rules bypass/concurrency tests, trusted tool review, App Check, signing, redacted monitoring, free quotas, privacy and restore evidence. Then separately approve backup, migration/bootstrap, coordinated Rules/client cutover and legacy retirement. Never deploy strict admission before verified admin recovery is ready. |

Each phase passes tests before its dependent workflow opens. No migration, registration implementation or deployment is authorized by this sequence. A clean data/rules/client checkpoint and restrictive rollback are required for production; never reinstate broad authenticated reads to keep old clients working.

## 19. Security compromises explicitly rejected

Reject Firebase Storage/billing as an implicit prerequisite; APK-embedded admin/provider secrets; arbitrary privileged Flutter writes; position-derived roles; directory as authority; submitted identity strings as proof; app-only field validation; async projection repair; client-generated privileged audit as trusted evidence; unchecked uniqueness queries; sequential Console edits called atomic; guessed historical dates/actors; forged counters/donation events; provider URL secrecy claimed as private access; unsigned unrestricted uploads; photo deletion before replacement; plain Auth artifacts in repository/cloud sharing; quota workarounds that bypass Rules; and public/allow-all rules for compatibility.

A secured operational tool is still trusted code that must be reviewed and maintained. If its custody or evidence is weak, declaring it manual does not make it safe. Availability and management UX may be reduced; authorization must not be.

## 20. Required small v1.2.x amendments and GO / NO-GO

No existing document is modified here. Recommended next documentation revision: a focused Free-V1 implementation profile/amendment retaining the v1.2 security invariants. These are real enforcement/schema changes, not merely renamed Cloud Functions.

| Existing document / sections | Required bounded amendment |
| --- | --- |
| ARCHITECTURE §§2–5, 9–10, 13 | Spark-only stack, no Firebase Storage, provider-neutral HTTPS media, operator-run trusted path, narrowly proven own-profile Q exception; add Events/CommitteeMedia/EventMedia modules/entities. |
| DATA_MODEL §§1–2, 5, 12–14 and new entity sections | Add term group URL and exact media/event schemas; HTTPS/provider metadata rules; pending request fixed-value Rules construction; atomic projection own-update exception and unchanged operational Q for all privileged writes. |
| AUTH_AND_SECURITY §§2, 6–8, 12, 14–16 | E create enforcement change, minimal self-link read, operational trusted execution/custody, audit boundary, Q exception and external-media limits. No relaxed verification or target management. |
| PERMISSIONS §§9–12 | Preserve existing role scopes; document reduced client surface, propose explicit event/media/history/editorial capabilities, and no Firebase Storage usage. |
| CAPABILITY_MATRIX §§2–4, 6, 11–16 | Amend E/Q and enforcement paths, own-profile alias parity, minimal own-link get, six-field direct subset until provider gate, operational C execution; add explicit event/media/term-photo/lifecycle rows with fields/scopes/transitions/audit/tests. Retain all other denials. |
| MIGRATION_PLAN §§3–8, 10–14 | Free capture/restore, operational bootstrap and revised staging sequence, media migration provenance and provider abstraction; no managed export prerequisite. |
| PRODUCTION_CHECKLIST §§2–7, 9–13 | Spark/no-paid-resource gate, own-projection and operational-tool tests, external image provider/privacy gates, free backup/restore and realistic operator response coverage. Remove cloud-first provisioning as current release requirement. |
| BACKUP_AND_RECOVERY_PLAN §§1–6, 10–12 | Replace current cloud-first capture with protected raw/Auth/config manual procedure; keep protected admin and rollback controls. |
| CLOUD_BACKUP_DESIGN / CLOUD_BACKUP_READINESS / CLOUD_PROVISIONING_PREFLIGHT | Add FUTURE / BLAZE OPERATIONAL REFERENCE banner in a later authorized documentation task; preserve dated verification evidence and candidate names as history, not current provisioning instructions. |
| LOCAL_BACKUP_READINESS | Later clarify temporary encrypted capture role for raw Firestore/Auth and independent copy, without claiming disk protection was newly verified. |
| LOCALIZATION, if needed | Add event_type/media labels to stable-key examples; no change to bn/en policy. |
| CURRENT_FIREBASE_INVENTORY | Preserve as dated evidence; no rewrite of observed state required. |

**GO:** Free-V1 documentation amendment and, after approval, a separately scoped local Rules/emulator test foundation. **NO-GO:** full self-service v1.2 implementation, production migration/deployment, unreviewed direct E/Q writes or real external uploads under unchanged frozen contracts.

Free V1 is **partially feasible** with the included reads/normal writes and controlled operational administration. A provider-independent UI/schema design can begin after its contract amendment; production image workflows remain blocked on provider validation. Operational availability, protected backup custody and required legacy provenance must be resolved before production release.

**Exact next task:** approve and apply the focused v1.2.x Free-V1 documentation amendment, especially E/Q and the new event/media capability rows. The first subsequent implementation task is a local/source-controlled Firestore Rules foundation with emulator tests for fail-closed admission, own pending requests and atomic own-User/directory updates; explicitly no deployment, migration or registration UI in that task. Stop after this feasibility document.

# Donor phone reservation — gated cutover

**State:** Source-code and emulator acceptance only. Do not run this document as a live migration. Do not set a production registry to `ready: true` from a normal mobile session.

## Why this gate exists

Earlier donor approvals queried active donors by exact stored phone before
writing a new donor. Two different approvals could observe no collision and
both commit; archived and +880/Bangla-digit variants could also be missed.
New approvals reserve a deterministic `donor_phone_keys/{01XXXXXXXXX}`
document in the same Firestore transaction as the donor creation and
`donor_submissions` approval. Firestore Security Rules require a matching
immutable reservation. A second request for that key must fail.

## Required owner-controlled sequence (NOT performed)

1. Keep `system_config/donor_phone_registry` absent or with
   `ready: false, schema_version: 1`. Approvals are blocked while it is not
   explicitly ready; rejection of existing pending legacy applications remains
   allowed.
2. Perform an owner-authorized, **read-only full-history audit**, including
   active and inactive/archived donors. The repository's
   `audit-donor-phones` command is emulator-only. Do not point it at the live
   Firebase project or export private phones into shared logs.
3. Resolve invalid, duplicate or ambiguous legacy identities manually,
   including alternate +880/Bangla-digit spellings. Select and record the
   authoritative donor ID; do not delete historical donations. Do not silently
   reassign archived numbers.
4. Separately review an authenticated, privileged backfill process that writes
   an immutable `donor_phone_keys` entry for **every historical donor phone**,
   not only active profiles. The current repository intentionally does not
   provide a production write command for this.
5. Verify a full read-back: all historical donor IDs are accounted for,
   reservation documents are unique, their `donor_id` mappings are correct,
   and the count agrees with the approved migration manifest. Audit any
   concurrent admission pause separately.
6. Review and deploy the matching Rules and indexes **only with explicit
   production approval**. Test approval/rejection on the local Firebase
   emulator and physical Android devices. Authorize switching
   `system_config/donor_phone_registry` to exactly
   `{ready: true, schema_version: 1}` only after all earlier gates pass.
7. Monitor first approved operations and audit logs. If anything diverges,
   switch readiness off and stop approval. Never bypass the key requirement
   or delete key documents as a quick fix.

## Invariants and known boundaries

- A phone key is never released when a donor is archived; archived history
  continues to own the identity.
- Mobile donor editing cannot change the phone; a future trusted re-key
  needs its own review, identity proof and transaction.
- New client submissions normalize valid Bangladesh mobile input to
  `01XXXXXXXXX`. Old noncanonical pending requests require operator review
  or rejection/reapplication, never silent approval.
- Only developer_admin and leader may create a phone reservation in the
  same valid approval batch. General members may not read or enumerate keys.
- The current app does **not** prove uniqueness for production history.
  Emulator CI passing is not a production backfill, Rules deployment or
  real-device acceptance.
- Real phone numbers and private applicant or donor records must not be put
  in tests, commits, public logs or shared screenshots.

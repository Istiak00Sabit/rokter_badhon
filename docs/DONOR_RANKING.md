# Top 3 donors and lifetime ranking — Firebase Spark

## Source of truth

Only **active** donors in the `donors` collection are ranked.
The current count comes from each `donors/{id}.total_donations` integer.
Ranking is descending by lifetime number of **recorded** donations, not
from donor application counts, phone searches or guessed historical totals.

- The Home Dashboard watches the first three through an indexed Firestore
  snapshot listener, showing their names, blood groups, lifetime count, and
  a link to the full Ranklist.
- The existing Ranklist shows up to 50 top donor profiles with recorded
  donations, sorted by `total_donations`. Zero-count accounts are not
  misleadingly awarded a medal.
- Only admitted and active donors are shown, and the app does not expose
  private donation recipient details in this public ranking.

## Record a real donation

An existing `developer_admin`, `leader` or `executive` may open Donor
List, find the approved donor and tap the Record Donation icon.

The app asks for an actual donation date and optional hospital/location,
then confirms. One Firestore transaction reads the existing donor,
creates `donations/{autoId}` (with actor, time and name/group snapshots),
and updates the donor's `total_donations` by exactly one,
`last_donated_at`, `latest_donation_id`, and audit metadata.

Firestore Security Rules validate **both** sides with `getAfter`. A direct
counter update, unapproved non-editorial record, forged actor, future date,
old/non-monotonic donation date, unrelated donor, or reuse of an existing
donation document ID is denied. There is no Cloud Functions requirement
for this flow; Firebase Spark quotas still apply.

The editor must verify the donation really happened and must not log the
same event twice. Client-side controls and database audit cannot themselves
prove a physical donation took place.

## Historical counts

The current ranking will only reflect numbers **already correctly recorded**
in the donor documents or subsequently recorded through this form. An
existing historical donation in `donations` that was never counted,
or an old donor with missing prior events, must be reconciled with evidence
using the existing trusted operator workflow before publication. Never
automatically invent historical donations or increment counters just because
a donor was registered.

This first editor form records a donation strictly *after* the latest
known `last_donated_at`. It does not provide corrections or deletion of
old donations, because those operations require special audited counter
reconciliation. Old data cannot be silently patched from the UI.

## Deployment and testing

- Pull the PR branch, run `flutter pub get`, then test on a real phone.
- Before changing production permissions, review and publish this branch's
  `firestore.rules` in the correct Firebase project after Emulator CI passes.
- The repository's `firestore.indexes.json` already includes the
  `active` + `total_donations` descending composite index.
  Deploy the index separately if it is missing from the live Firebase project.
- The app itself does not automatically deploy Firestore Rules or Indexes,
  and this change does not mutate real donor data from the GitHub tool.

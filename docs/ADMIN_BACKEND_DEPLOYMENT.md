# Spark-first real application: admin approval and account management

The real Flutter app uses Firebase Authentication + Firestore Security Rules
and **no paid deployed Cloud Functions** for everyday user approval and role
management. Changes were implemented on PR #2 (draft) and require owner
review and Firestore Rules publishing before they work against the existing
Firebase project.

## What works without upgrading billing
- Firebase Auth registers accounts using their private phone-derived
  email/password identity. Applicants can submit their own pending request.
- A pre-existing *properly admitted* `developer_admin` reviews a request
  and atomically creates six related documents: an ordinary Member in
  `users/{authUid}`, `auth_links/{authUid}`, `user_directory/{authUid}`,
  `registration_phone_claims/{phone}`, an immutable
  `registration_review_events/{authUid}`, and approval fields on the request.
  Reject creates only review evidence and changes the request status.
- Existing User roles (member, committee, executive, leader), active flag,
  login flag can be updated by developer admin via a Firestore batch
  containing `admin_actions/{operationId}` audit evidence. Direct user
  mutation without this evidence is denied. Developer admins cannot be
  created, promoted, deactivated or modified from this UI; actors cannot
  change their own privileged account.
- Profile photos may be linked to a publicly reachable HTTPS image URL using
  Firestore's existing User + Directory projection. There is no built-in
  upload/Storage hosting on Spark.
- Official committee roster names/positions/order always come from bundled
  JSON; a verified matching active User Directory may supply a profile photo.
- Donor submission and donor approval continue to use the separate
  phone-registry transactional uniqueness workflow, not the registration
  phone claims.

## Owner steps
1. **Backup your live Firestore Rules** before any changes.
2. Review `firestore.rules` on the PR branch, and test it against the
   **demo emulator only**. The GitHub Actions backend job runs those tests.
3. After approving the results, publish `firestore.rules` in Firebase
   Console for **rokterbadhon-b247b**. Publishing is a live permission change.
   Git commits and `flutter run` do NOT publish Rules.
4. Ensure existing developer admin's authenticated Firebase UID is mapped by
   `auth_links/{authUid}` to an active `users/{id}` with
   `access_role: developer_admin` and `login_enabled: true`.
   Do not create an admin using client-supplied roles.
5. Pull the PR branch and run `flutter pub get` / `flutter run` on a real
   device, or install the locally built APK. No Blaze deployment is necessary.
6. Before testing approval of a **real identity**, manually verify applicant
   identity and phone ownership. Never approve synthetic/fake accounts in
   production.

## Legacy accounts and duplicate phone safety
The newly admitted User ID equals the applicant Auth UID. A reviewed
registration whose phone already appears in `users`, or a claimed phone,
is rejected by the client preflight. The deterministic
`registration_phone_claims/{phone}` write prevents two concurrent
new approvals of the same phone. Historical/legacy profiles might lack
claims: review/reconcile old users before onboarding, and never treat client
preflight as an authorization proof. Linking an applicant to an existing
User (committee import, historical users) is a separate audited, trusted
operator workflow, intentionally not auto-done here.

## Donor registry safety
Donor approval requires an independently audited migration and
`system_config/donor_phone_registry` set ready. **Do not set it to true
without reviewing all existing donor records, including inactive records.**
The emulator demo seed is strictly local and must never be run against
production. Existing donor approval also requires published latest Rules.

## What is deliberately not promised
- Firestore Rules cannot invoke Firebase Admin SDK to delete/disable
  authentication identities, reset another user's password, or force-verify
  phone ownership. Deactivation/login controls act as app-level admission
  gates, not Firebase Auth account disablement.
- Committee membership JSON cannot be remotely edited on one device and
  instantly distributed to other installs; changing roles in User records
  does not edit the official JSON roster.
- Firestore Spark free usage quotas apply. There is no unlimited free usage,
  and no hosting of profile images included.
- Untrusted clients cannot provision developer_admin.
- The dormant `functions/` source is preserved for a possible future
  opted-in Blaze migration, but `firebase.json` contains **no functions
  deploy target**. Do not deploy Functions for Spark testing.
- User list currently pages only first 80 profiles; improved pagination
  and live device acceptance remain necessary before release.

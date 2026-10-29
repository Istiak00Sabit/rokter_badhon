# Registration and donor approval outcomes (Spark Firebase)

## Important: reject is not delete

For a **member registration request**:
- Pending: `registration_requests/{authUid}.status = 'pending'`; the applicant has already created their own Firebase Authentication identity, but no admitted User/AuthLink is created yet.
- Approved: the admin's verified atomic batch changes the request to `approved`, creates `users/{authUid}`, `auth_links/{authUid}`, `user_directory/{authUid}`, a phone claim, and immutable review evidence. The applicant may now log in as `member`.
- Rejected: the batch changes the request to `rejected`, stores reviewer and time, and creates immutable `registration_review_events/{authUid}` including reason. It does **not** create an admitted User or AuthLink. The Firebase Authentication applicant identity and rejected request remain, for identity resolution and audit.

For a **donor submission**:
- Pending: `donor_submissions/{id}` contains submitted donor payload and `status = pending`; the donor is **not** yet in the active `donors` collection.
- Approved: a guarded Firestore transaction creates `donors/{id}`, reserves `donor_phone_keys/{phone}`, and changes submission status to `approved` with reviewer/date/donor ID. Requires the independently reviewed phone registry ready state.
- Rejected: submission is updated to `status = rejected`, reviewer/time/reason saved, and **no active donor is created**.

Rejected/approved requests are excluded from Pending screens by the `where('status', isEqualTo: 'pending')` query. The new **Review History** page shows up to 50 approved/rejected items. They stay in Firestore intentionally. No automatic Firebase deletes or irreversible account removal occur on approval/rejection.

Do **not** delete a request to hide it from the Pending list, or delete Firebase Auth identities to free up a phone without verifying who owns that identity. In the current app, a previously rejected applicant cannot simply sign up again with the same Firebase Auth login; a separately designed reapplication/identity-recovery workflow or owner-authorized remediation is required. Such recovery must prevent impersonation, duplicate accounts and unaudited role changes.

## UI crash and photo handling

Dialog callbacks now unfocus text fields before route pop, and no longer dispose a `TextEditingController` from the parent immediately after `showDialog` returns. This targets the user-reported Flutter red-screen inherited widget assertion on dialog close. It needs final physical device regression testing.

The profile photo dialog is currently a **URL linking** flow, not a photo upload picker. A user can provide an existing HTTPS image address, or clear it. Spark does not include an image hosting provider by default; live access depends on Firestore security rules and valid remote URLs.

## Deployment/verification

- Pull the development branch and run `flutter pub get`, then the app.
- Owner must separately review and publish the updated **Firestore Rules** for the correct Firebase project. GitHub commits alone do not publish live Rules.
- Do not publish Rules without passing the Firebase Emulator rules tests and comparing the deployed baseline. Do not mark donor registry ready merely to make approvals pass.
- Real-device test: cancel a dialog with keyboard open; approve/reject a disposable test request; verify Pending disappears, History shows the decision, Firebase document retains status; test browser/system back and empty queues.

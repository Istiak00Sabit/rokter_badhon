# Developer Admin backend — owner deployment checklist

The Flutter screens and callable server sources live in PR #2. They cannot activate on production through `git pull` alone.

## Prerequisites
- Firebase project: `rokterbadhon-b247b`
- Authorized owner reviews the target, deployed rules, real developer-admin `auth_links` and `users` state and Firebase Auth identity first.
- Firebase **Blaze** billing must be explicitly enabled for Cloud Functions. Spark does not deploy Cloud Functions. Billing may incur charges; configure limits/alerts as appropriate.
- Cloud Functions region: `asia-south1`. New admin code is in `functions/`.
- For optional photos, provide an approved image hosting service, and configure `PROFILE_PHOTO_ALLOWED_HOSTS` as an exact comma-separated list of hostnames (without schemes). An empty setting intentionally rejects photo changes.
- The code does not include an upload service. It only saves a vetted HTTPS URL to existing `users.photo_url` and `user_directory.photo_url`.

## Deployment after owner review

From the **PR branch**, with Firebase CLI access, run:

```bash
git switch fix/admin-registration-village-language-20261026
git pull origin fix/admin-registration-village-language-20261026
npm install --prefix functions
firebase login
firebase use rokterbadhon-b247b
firebase deploy --only functions:admin --project rokterbadhon-b247b
flutter pub get
flutter run
```

Do not deploy the functions if the Firebase project is still Spark, the protected operator identity is not verified, or owner consent for billing/deployment is missing. Running `firebase deploy` affects production.

## What the callable API does
- `adminReviewRegistration`: only an admitted, active **developer_admin** may approve or reject pending registration after a reason. An approval creates Member User, directory, AuthLink, decision and audit in the existing trusted transaction.
- `adminListUsers`: developer admin can read the first 80 User summaries (not full data); pagination is a known follow-up.
- `adminManageUser`: role member/committee/executive/leader, active state or login state through audited authorization; never changes a developer admin or self.
- `updateMyProfilePhoto`: any admitted account can save or clear its own approved HTTPS photo URL with an audit record.

App Check enforcement needs approved real-device provider configuration and testing before production rollout. Firebase Auth, active AuthLink and current User role are checked server-side even before that deployment gate.

## Limits
- Committee **membership, position and ordering remain in bundled JSON**, with no Firestore committee roster writes. Any roster changes require an app release updating JSON. Member/Committee application roles are distinct from the JSON list.
- The donor phone registry must be reconciled/marked ready through the separate reviewed trusted operator workflow. Do not set `system_config/donor_phone_registry.ready` manually.
- The callables do **not** create new developer admins.
- Live production end-to-end approval, mobile App Check, image upload, donor phone migration, and release signing are not claimed done.

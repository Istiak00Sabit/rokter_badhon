# Rokter Badhon Ghatail — Local Backup Readiness

Reference: Production Architecture v1.2 — FROZEN FOR IMPLEMENTATION  
Check date: 2026-09-07  
Current operational interpretation: **CLOUD-FIRST**. Local readiness governs temporary Auth plaintext handling only; it does not gate direct Firestore managed export.

This report supplements [CURRENT_FIREBASE_INVENTORY.md](CURRENT_FIREBASE_INVENTORY.md) and [BACKUP_AND_RECOVERY_PLAN.md](BACKUP_AND_RECOVERY_PLAN.md). The original check was read-only apart from this report. This operational revision preserves its observed machine results and changes only their backup-strategy interpretation; see [CLOUD_BACKUP_DESIGN.md](CLOUD_BACKUP_DESIGN.md). No fresh machine/Firebase checks were performed for the revision.

Checks used read-only Windows metadata, installed CLI source/package metadata, Git discovery and a Firebase project IAM permission-test RPC. No Firestore/Auth exports, document reads, password-hash retrieval, bucket creation, Firebase mutations, rule/index changes, software installation, archives or password handling occurred. No personal files were enumerated. Workspace link metadata was inspected only for repository-boundary assessment.

## 1. Available local storage

**VERIFIED FROM WINDOWS METADATA:** `Win32_LogicalDisk` returned these mounted filesystem volumes. Values are point-in-time readings; GiB is bytes divided by 1,073,741,824.

| Drive | Windows type | Filesystem | Free bytes | Free space, approximately |
| --- | --- | --- | ---: | ---: |
| C: — system drive | Fixed (3) | NTFS | 16,993,628,160 | 15.83 GiB |
| D: | Fixed (3) | NTFS | 36,922,507,264 | 34.39 GiB |
| E: | Fixed (3) | NTFS | 70,976,802,816 | 66.10 GiB |
| F: | Fixed (3) | NTFS | 71,342,145,536 | 66.44 GiB |

The observed two-User/one-Auth baseline is small, so capacity does not appear to be the immediate obstacle. Actual export size, working-copy needs, retention growth and a safe system-drive reserve have not been measured. No test file was written to verify capacity or write access.

## 2. Disk encryption status

**NOT VERIFIED.** `manage-bde -status C:` was attempted read-only after sandbox access restrictions were removed. Windows returned an access-denied error and requested administrative rights. Approval to leave the execution sandbox did not supply Windows administrative elevation.

Neither enabled nor disabled BitLocker/Device Encryption protection can be inferred from that error. No recovery keys, protector secrets or encryption settings were requested. D:, E: and F: encryption status is also unverified; they are not validated encrypted alternatives.

Before selecting this laptop for temporary plaintext Auth artifacts, an authorized Windows administrator should view Device Encryption/BitLocker status or run `manage-bde -status C:` in an elevated terminal. If an alternative volume is selected, check that volume as well. Record encryption/conversion status and whether protection is on or suspended; do not print recovery keys. A fully encrypted volume with suspended protection must not be accepted without review.

Direct managed Firestore export does not write local plaintext and is not gated by this disk check. Protection of any temporary Auth plaintext remains required. Enabling encryption, resuming protection or changing recovery-key custody would be a separate action, not authorized by this check. 7-Zip installation alone does not establish that raw export files would be encrypted when first written.

## 3. Candidate temporary working directories

**VERIFIED FROM LOCAL PATH METADATA:** none of the following proposed directories currently exists. No directory was created. These are now temporary working-area candidates only, not primary backup destinations. Primary custody is the separate-project cloud bucket; no long-term production backup may rely only on this laptop.

| Candidate | Suitability |
| --- | --- |
| `C:\RokterBadhon_Backups\` | Simple temporary-workspace candidate only; outside the repository. Conditional only: verify C: encryption, restricted ACLs, ownership, available reserve and retention before creation or use. |
| `D:\RokterBadhon_Backups\` | Outside the repository and more free space; encryption and future directory ACLs/write access are unverified. |
| `E:\RokterBadhon_Backups\` | Outside the repository and more free space; encryption and future directory ACLs/write access are unverified. |
| `F:\RokterBadhon_Backups\` | Not preferred: root metadata includes ReadOnly in addition to Hidden/System/Directory. This does not by itself prove the whole volume is unwritable, but its suitability requires clarification. Encryption/access also unverified. |

Drive-root metadata showed no root link target. A nonexistent destination has no established ACLs and cannot yet be declared safe. For the selected path, later setup must explicitly establish restricted access and encryption before export, and recheck that it is not a junction/symlink or inside a synchronized/shared folder. Do not rely on default inherited permissions. No write test was performed.

## 4. External-copy availability

**VERIFIED FROM WINDOWS METADATA:** all four listed volumes report fixed drives. `Get-Disk` returned one physical disk: disk 0, NVMe, boot/system, size 512,110,190,592 bytes. No USB/removable/external disk or removable filesystem volume was returned.

**External drive letter / filesystem / free space: none detected.** D:, E: and F: must not be treated as an independent external backup merely because their letters differ from C:. The visible local storage does not supply a second physical recovery copy.

No personal files were listed. Disconnected, unmounted or Windows-unrecognized devices are outside this result. An approved external/off-machine copy destination remains unresolved and must be inspected when available.

## 5. Firebase tooling readiness

**VERIFIED FROM INSTALLED FILES:** Firebase CLI package version **15.11.0** is installed under the current user's npm packages. `firebase.ps1` resolves to `C:\Users\HP\AppData\Roaming\npm\firebase.ps1`.

The installed `lib/commands/auth-export.js` explicitly registers `auth:export [dataFile]` and checks `firebaseauth.users.get`. Thus the installed CLI supports Auth export. The command was **not executed**, including for a test export. CLI version/support were established by file reads to avoid unintended output/cache artifacts.

An existing Firebase CLI identity and refresh credential are present. No credential values were printed. Previous inventory found no gcloud on PATH or standard ADC; their absence was not independently rechecked here. Neither gcloud nor new software is needed merely to establish that the installed Firebase CLI has its Auth export command.

## 6. Read-only Firebase capability check

**VERIFIED FROM LIVE PROJECT IAM METADATA:** the existing CLI session was refreshed only in memory and used to call `projects/rokterbadhon-b247b:testIamPermissions`. This read-only capability RPC returned all six requested permissions:

| Permission returned | Evidence it provides |
| --- | --- |
| `firebaseauth.users.get` | Current principal passes the permission checked by the installed Auth export command. |
| `firebaseauth.configs.getHashConfig` | Principal has permission to access Auth hash configuration; the configuration itself was not retrieved. |
| `datastore.entities.get` | Principal has Firestore document-get permission. |
| `datastore.entities.list` | Principal has Firestore enumeration/query permission. |
| `datastore.databases.get` | Principal has database metadata-read permission. |
| `datastore.databases.export` | Principal has the source-project permission to initiate a managed export. |

**Assessment:** this identity appears capable of initiating Auth export and performing raw Firestore reads. It also holds the listed managed-export permission. No password hashes, Auth records or Firestore documents were requested in this task; no tokens were saved or printed.

**Limits:** permission presence is not an end-to-end export test. Destination ACLs, complete credential-export coverage, Auth/provider/tenant scope, billing, service-agent permissions, service availability and restore capability remain unverified. The metadata check does not grant permission to use the credentials for mutations. Managed export remains blocked by the unresolved destination and operational prerequisites described in the recovery plan.

## 7. Archive/encryption tooling already available

**VERIFIED FROM FILE METADATA:** `C:\Program Files\7-Zip\7z.exe` exists, product version **22.01**. It was not found through `Get-Command 7z/7zz`, so its executable is not currently resolved by those command names on PATH. The explicit installation path is available for a later reviewed workflow.

`manage-bde.exe` and the `Get-BitLockerVolume` command are present; presence does not establish enabled protection. No archive was created, encryption operation tested, software updated or password requested/handled. The installed 7-Zip version's current security suitability was not assessed.

A later encrypted archive cannot retroactively protect a raw export initially written to an unverified unencrypted location. Select a workflow that protects initial files, temporary files and final artifacts. Archive passwords/key recovery and retention remain custodian decisions; no values belong in repository documentation or terminal history.

## 8. Git and repository exclusion

**VERIFIED FROM LOCAL CHECKS:** `git rev-parse --show-toplevel` and `git status --short` in `C:\rokter_badhon` both reported that the directory is not a Git repository. Neither `C:\rokter_badhon\.git` nor `C:\.git` exists. There is therefore no current standard worktree index here that tracks a proposed backup path.

`C:\RokterBadhon_Backups\` is a sibling of `C:\rokter_badhon`, not a child. The D:/E:/F: candidates are also outside the application directory. A normal Git repository initialized in `C:\rokter_badhon` cannot include files from these separate destinations merely through a normal `git add .` in that worktree. No existing proposed backup directory is itself available to inspect for Git metadata because it does not exist.

Generated plugin symlinks were found under the workspace's Flutter ephemeral directories; no proposed backup directory exists to be their current content. Do not later link, copy or stage backups into the workspace. Recheck the final resolved destination and repository root before capture. Initializing a broader worktree, copying artifacts into source, or using unrelated backup/sync tooling can invalidate the present boundary. A repository ignore entry is not a substitute for keeping the destination outside the repository. No Git configuration or ignore file was changed.

## 9. Risks and remaining verification

| Finding | Risk / next prerequisite |
| --- | --- |
| Disk encryption unverified | Auth temporary-plaintext gate: establish protection before local use. Not a blocker for direct Firestore-to-Cloud-Storage export. |
| Destination absent, ACLs unestablished | Blocking: approve path/custodians and separately authorize secure setup; do not infer privacy from being outside Git. |
| No external/off-machine copy destination | Not a first-cloud-export blocker. After primary verification, choose an eventual independent second cloud/offline copy; same-disk partitions do not cover disk loss. |
| Auth export and sensitive permissions available | Tooling is capable, but credential-bearing output needs strict artifact handling; never use a test export as a capability probe. |
| 7-Zip present but workflow untested | Establish a reviewed initial-file/temporary-file/final-archive encryption process before relying on it. No password handling here. |
| Capture/restore not exercised | Permissions and installed software do not establish complete, restorable backups. Follow the separate recovery plan. |
| Free space is a live reading | Recheck immediately before a later capture; maintain system reserve and account for working/second copies. |

The first sandboxed CIM disk queries were denied; approved execution outside the sandbox returned disk metadata. BitLocker still failed on Windows administrative access. An overall command nonzero result caused by the absent candidate paths or failed BitLocker/Git query was not treated as invalidating the separately successful metadata results.

## 10. READY / NOT READY decision

**Local temporary Auth workspace: NOT READY until plaintext protection, restrictive access, artifact encryption/key recovery and secure cleanup are validated.** BitLocker verification remains desirable before storing plaintext credentials; another approved protected workspace may be selected instead. No local long-term backup is proposed.

**Direct Firestore managed export: not blocked by laptop BitLocker or absent external drives.** It writes directly to the separate backup-project bucket. Cloud execution is nevertheless NOT READY until the project/bucket identities, source billing/Blaze, least-privilege cross-project access, custody and capture authorization are resolved in CLOUD_BACKUP_DESIGN. Prior source IAM checks alone do not satisfy those gates.

**Safe next step:** complete the cloud design decision record for custodians, proposed project/bucket identities, billing/budget, retention and Auth protected temporary-workspace method, then perform permitted read-only validation. Do not create directories/projects/buckets, change billing/IAM, export/upload, archive or alter Firebase during documentation work.

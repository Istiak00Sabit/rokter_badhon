import { AdmissionError, parseUser, parseDirectory, projectDirectory } from './policy.js';
import { internalAuthEmailForPhone, normalizePhone } from './auth_identity.js';
import {
  OFFICIAL_COMMITTEE_TERM_ID,
  loadOfficialCommitteeSource,
  validateOfficialCommitteeSource,
} from './official_committee.js';

const PROJECT_ID = 'rokterbadhon-b247b';
const PRODUCTION_ACTOR = 'trusted-operator-official-committee-import';
const SOURCE_USER_FIELDS = [
  'name', 'phone', 'email', 'blood_group', 'profession', 'address',
  'photo_url', 'access_role', 'active', 'login_enabled', 'preferred_language',
  'created_by', 'updated_by',
];

function expectedUser(row) {
  return {
    name: row.name,
    phone: row.phone,
    email: null,
    blood_group: row.blood_group,
    profession: row.profession,
    address: null,
    photo_url: null,
    access_role: row.access_role,
    active: true,
    login_enabled: false,
    preferred_language: null,
    created_by: null,
    updated_by: null,
  };
}

function sameFields(left, right, keys = Object.keys(right)) {
  return keys.every((key) => left?.[key] === right[key]);
}

function blockingItem(serial, code) {
  // Never log personal names, phone numbers, Auth UIDs, or emails.
  return { serial, code };
}

/**
 * Read-only eligibility check. It performs no writes and never logs PII.
 *
 * This is an advisory preflight, NOT a concurrency lock. The actual import
 * repeats its own checks transactionally. Operator must inspect the result
 * and obtain a backup before approving any production mutation.
 */
export async function inspectCommitteeImport({
  projectId, db, auth, rows = loadOfficialCommitteeSource(),
  skipAuth = false,
  onStage = () => {},
}) {
  if (projectId !== PROJECT_ID && !projectId?.startsWith('demo-')) {
    throw new AdmissionError('unsafe_target', 'Unknown target Firebase project.');
  }
  const source = validateOfficialCommitteeSource(rows);
  const actor = projectId === PROJECT_ID
    ? PRODUCTION_ACTOR
    : 'local-emulator-committee-seed';
  const blockers = [];
  const counts = {
    source: source.length,
    existingUsers: 0,
    existingDirectories: 0,
    existingAssignments: 0,
    existingImportAudits: 0,
    existingPhoneAuthIdentities: 0,
  };

  onStage('committee.firestore');
  await db.runTransaction(async (transaction) => {
    const termRef = db.collection('committee_terms').doc(OFFICIAL_COMMITTEE_TERM_ID);
    const [term, activeTerms] = await Promise.all([
      transaction.get(termRef),
      transaction.get(db.collection('committee_terms').where('active', '==', true)),
    ]);
    if (activeTerms.docs.some((doc) => doc.id !== OFFICIAL_COMMITTEE_TERM_ID)) {
      blockers.push(blockingItem(null, 'another_active_term'));
    }
    if (term.exists) {
      if (!sameFields(term.data(), {
        name: '2025-2027',
        start_year: 2025,
        end_year: 2027,
        start_date: null,
        end_date: null,
        active: true,
        group_photo_url: null,
        created_by: actor,
      })) {
        blockers.push(blockingItem(null, 'existing_term_mismatch'));
      }
    }
    for (const row of source) {
      const suffix = String(row.serial).padStart(3, '0');
      const userId = 'committee-2025-2027-' + suffix;
      const assignmentId = '2025-2027-' + suffix;
      const auditId = 'official-committee-2025-2027-' + suffix;
      const [u, d, a, audit, phoneUsers, phoneDirectories, assignments] = await Promise.all([
        transaction.get(db.collection('users').doc(userId)),
        transaction.get(db.collection('user_directory').doc(userId)),
        transaction.get(db.collection('committee_assignments').doc(assignmentId)),
        transaction.get(db.collection('audit_logs').doc(auditId)),
        transaction.get(db.collection('users').where('phone', '==', row.phone)),
        transaction.get(db.collection('user_directory').where('phone', '==', row.phone)),
        transaction.get(db.collection('committee_assignments')
          .where('user_id', '==', userId).where('term_id', '==', OFFICIAL_COMMITTEE_TERM_ID)),
      ]);
      if (u.exists) counts.existingUsers++;
      if (d.exists) counts.existingDirectories++;
      if (a.exists) counts.existingAssignments++;
      if (audit.exists) counts.existingImportAudits++;
      if (phoneUsers.docs.some((doc) => doc.id !== userId) ||
          phoneDirectories.docs.some((doc) => doc.id !== userId)) {
        blockers.push(blockingItem(row.serial, 'phone_already_in_use'));
      }
      if (assignments.docs.some((doc) => doc.id !== assignmentId)) {
        blockers.push(blockingItem(row.serial, 'duplicate_assignment'));
      }
      if (!u.exists && (d.exists || a.exists)) {
        blockers.push(blockingItem(row.serial, 'orphan_records'));
      }
      if (u.exists) {
        try {
          const parsed = parseUser(u.data(), userId);
          if (!sameFields(parsed, expectedUser(row), SOURCE_USER_FIELDS) ||
              !d.exists || !sameFields(parseDirectory(d.data(), userId), projectDirectory(parsed))) {
            blockers.push(blockingItem(row.serial, 'existing_user_mismatch'));
          }
        } catch (_) {
          blockers.push(blockingItem(row.serial, 'malformed_existing_user'));
        }
        if (projectId === PROJECT_ID && !audit.exists) {
          blockers.push(blockingItem(row.serial, 'existing_user_missing_import_audit'));
        }
      }
      if (a.exists && !sameFields(a.data(), {
        user_id: userId, term_id: OFFICIAL_COMMITTEE_TERM_ID,
        position: row.position, active: true, ended_at: null, assigned_by: actor,
      })) {
        blockers.push(blockingItem(row.serial, 'existing_assignment_mismatch'));
      }
      if (audit.exists && (audit.data()?.action !== 'committee.member_seed' ||
          audit.data()?.changes?.user_id?.after !== userId)) {
        blockers.push(blockingItem(row.serial, 'import_audit_mismatch'));
      }
    }
  });

  if (!skipAuth) {
    onStage('committee.firebase_auth');
    for (const row of source) {
      const internalEmail = internalAuthEmailForPhone(normalizePhone(row.phone));
      try {
        const record = await auth.getUserByEmail(internalEmail);
        if (record) counts.existingPhoneAuthIdentities++;
      } catch (error) {
        if (error?.code !== 'auth/user-not-found') throw error;
      }
    }
  } else {
    // Never imply that import is safe when Auth ownership is unverified.
    counts.existingPhoneAuthIdentities = null;
  }

  return {
    mode: 'READ_ONLY',
    projectId,
    committeeTerm: OFFICIAL_COMMITTEE_TERM_ID,
    counts,
    blockers,
    firestoreRecordsCompatible: blockers.length === 0,
    authLookupsComplete: !skipAuth,
    safeToConsiderImport: blockers.length === 0 && !skipAuth,
    // This remains a dry-run recommendation. Never infer a write approval.
    wouldCreateUsers: source.length - counts.existingUsers,
    wouldCreateAssignments: source.length - counts.existingAssignments,
  };
}

/** Classifies a historical registration without changing the Auth account. */
export function classifyRegistrationIdentity({ phone, authEmail, authDisabled = false }) {
  if (authDisabled) return 'disabled_auth';
  if (typeof authEmail !== 'string' || authEmail.trim().length === 0) {
    return 'missing_auth_email';
  }
  try {
    const internalEmail = internalAuthEmailForPhone(normalizePhone(phone));
    return authEmail.trim().toLowerCase() === internalEmail
      ? 'phone_identity'
      : 'legacy_email_identity';
  } catch (_) {
    return 'invalid_registration_phone';
  }
}

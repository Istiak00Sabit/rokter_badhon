import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

import {
  AdmissionError,
  parseAuthLink,
  parseDirectory,
  parseUser,
  projectDirectory,
  validateId,
} from './policy.js';
import {
  OFFICIAL_COMMITTEE_TERM_ID,
  loadOfficialCommitteeSource,
  validateOfficialCommitteeSource,
} from './official_committee.js';
import { internalAuthEmailForPhone, normalizePhone } from './auth_identity.js';

const ALLOWED_ROLES = new Set(['developer_admin', 'leader', 'executive', 'committee', 'member']);
const ACTOR = 'trusted-operator';

function fail(code, message) {
  throw new AdmissionError(code, message);
}

function requiredText(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0) fail('invalid_argument', `${label} is required.`);
  return value.trim();
}

function same(left, right, keys = Object.keys(right)) {
  return keys.every((key) => left[key] === right[key]);
}

function userIdFor(serial) {
  return `committee-2025-2027-${String(serial).padStart(3, '0')}`;
}

function assignmentIdFor(serial) {
  return `2025-2027-${String(serial).padStart(3, '0')}`;
}

function auditIdFor(operationId, serial) {
  return `${operationId}-${String(serial).padStart(3, '0')}`;
}

function password() {
  return crypto.randomBytes(18).toString('base64url');
}

function expectedUser(row, phone, now) {
  return {
    name: row.name,
    phone,
    email: null,
    blood_group: row.blood_group,
    profession: row.profession,
    address: null,
    photo_url: null,
    access_role: row.access_role,
    active: true,
    login_enabled: true,
    preferred_language: null,
    created_at: now,
    created_by: null,
    updated_at: now,
    updated_by: null,
  };
}

function expectedAssignment(userId, row, now) {
  return {
    user_id: userId,
    term_id: OFFICIAL_COMMITTEE_TERM_ID,
    position: row.position,
    active: true,
    assigned_at: now,
    assigned_by: ACTOR,
    ended_at: null,
  };
}

function sourceRows(file) {
  if (file) {
    let decoded;
    try {
      decoded = JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (error) {
      fail('invalid_source', `Cannot read committee source: ${error.message}`);
    }
    return validateOfficialCommitteeSource(decoded);
  }
  return loadOfficialCommitteeSource();
}

async function getAuthByEmail(auth, email) {
  try {
    return { record: await auth.getUserByEmail(email), created: false, generatedPassword: null };
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
    return { record: null, created: false, generatedPassword: null };
  }
}

function authErrorCode(error) {
  return error?.code ?? 'auth_error';
}

async function createAuth(auth, { email, name }) {
  const generatedPassword = password();
  try {
    const record = await auth.createUser({
      email,
      password: generatedPassword,
      emailVerified: false,
      disabled: false,
      displayName: name,
    });
    return { record, created: true, generatedPassword };
  } catch (error) {
    throw new AdmissionError(authErrorCode(error), `Firebase Auth account could not be created: ${error.message}`);
  }
}

async function ensureTerm({ db, serverTimestamp }) {
  const term = db.collection('committee_terms').doc(OFFICIAL_COMMITTEE_TERM_ID);
  return db.runTransaction(async (transaction) => {
    const termSnapshot = await transaction.get(term);
    const activeTerms = await transaction.get(db.collection('committee_terms').where('active', '==', true));
    if (activeTerms.docs.some((doc) => doc.id !== OFFICIAL_COMMITTEE_TERM_ID)) {
      fail('ambiguous_current_term', 'A different active committee term exists; reviewed rollover is required.');
    }
    if (termSnapshot.exists) {
      const actual = termSnapshot.data();
      const expected = {
        name: '2025-2027', start_year: 2025, end_year: 2027,
        start_date: null, end_date: null, active: true, group_photo_url: null,
      };
      if (!same(actual, expected)) fail('existing_conflict', 'Existing 2025-2027 term conflicts with the reviewed source.');
      return { created: false };
    }
    transaction.create(term, {
      name: '2025-2027', start_year: 2025, end_year: 2027,
      start_date: null, end_date: null, active: true, group_photo_url: null,
      created_at: serverTimestamp(), created_by: ACTOR,
    });
    return { created: true };
  });
}

async function provisionOne({ db, auth, serverTimestamp, row, operationId, resetExistingPassword }) {
  let phone;
  let internalEmail;
  try {
    phone = normalizePhone(row.phone);
    internalEmail = internalAuthEmailForPhone(phone);
  } catch (_) {
    fail('invalid_source', `Committee row ${row.serial} has an invalid phone number.`);
  }

  let authState = await getAuthByEmail(auth, internalEmail);
  let createdAuth = false;
  let generatedPassword = null;
  const userId = userIdFor(row.serial);
  const assignmentId = assignmentIdFor(row.serial);
  const auditId = auditIdFor(operationId, row.serial);
  const userReference = db.collection('users').doc(userId);
  const directoryReference = db.collection('user_directory').doc(userId);
  const assignmentReference = db.collection('committee_assignments').doc(assignmentId);
  const auditReference = db.collection('audit_logs').doc(auditId);

  // Preflight the deterministic Firestore identity before creating an Auth
  // account. The transaction repeats these checks after Auth creation.
  await db.runTransaction(async (transaction) => {
    const [userSnapshot, directorySnapshot, assignmentSnapshot, phoneUsers, phoneDirectory] = await Promise.all([
      transaction.get(userReference),
      transaction.get(directoryReference),
      transaction.get(assignmentReference),
      transaction.get(db.collection('users').where('phone', '==', phone)),
      transaction.get(db.collection('user_directory').where('phone', '==', phone)),
    ]);
    if (phoneUsers.docs.some((doc) => doc.id !== userId) || phoneDirectory.docs.some((doc) => doc.id !== userId)) {
      fail('conflict', `Phone ${phone} already belongs to another User or directory entry.`);
    }
    if (!userSnapshot.exists && (directorySnapshot.exists || assignmentSnapshot.exists)) {
      fail('conflict', `Deterministic committee identity ${userId} has orphaned records.`);
    }
    return { userExists: userSnapshot.exists };
  });

  if (!authState.record) {
    authState = await createAuth(auth, { email: internalEmail, name: row.name });
    createdAuth = true;
    generatedPassword = authState.generatedPassword;
  } else if (authState.record.email !== internalEmail) {
    fail('conflict', `Internal Auth identity for ${phone} resolves to a different email.`);
  }
  const enableExistingAuth = !createdAuth && authState.record.disabled === true;
  const resetExistingAuthPassword = resetExistingPassword && !createdAuth;

  const authUid = authState.record.uid;
  const actualLinkReference = db.collection('auth_links').doc(authUid);
  try {
    const result = await db.runTransaction(async (transaction) => {
      const [userSnapshot, directorySnapshot, linkSnapshot, assignmentSnapshot, auditSnapshot,
        phoneUsers, phoneDirectory, userLinks] = await Promise.all([
        transaction.get(userReference),
        transaction.get(directoryReference),
        transaction.get(actualLinkReference),
        transaction.get(assignmentReference),
        transaction.get(auditReference),
        transaction.get(db.collection('users').where('phone', '==', phone)),
        transaction.get(db.collection('user_directory').where('phone', '==', phone)),
        transaction.get(db.collection('auth_links').where('user_id', '==', userId)),
      ]);
      const now = serverTimestamp();
      const canonicalUser = expectedUser(row, phone, now);
      const canonicalDirectory = projectDirectory(canonicalUser);

      if (phoneUsers.docs.some((doc) => doc.id !== userId) || phoneDirectory.docs.some((doc) => doc.id !== userId)) {
        fail('conflict', `Phone ${phone} already belongs to another User or directory entry.`);
      }
      if (userLinks.docs.some((doc) => doc.id !== authUid && doc.data().active === true)) {
        fail('conflict', `User ${userId} already has a different active Auth link.`);
      }
      if (linkSnapshot.exists) {
        const link = parseAuthLink(linkSnapshot.data(), authUid);
        if (link.user_id !== userId) fail('conflict', `Auth UID ${authUid} is linked to a different User.`);
      }
      if (auditSnapshot.exists) {
        const audit = auditSnapshot.data();
        if (audit.action !== 'committee.account_provision' || audit.changes?.user_id?.after !== userId) {
          fail('operation_reused', `Audit operation ${auditId} already belongs to another operation.`);
        }
      }
      if (userSnapshot.exists) {
        const existing = parseUser(userSnapshot.data(), userId);
        if (!same(existing, { name: row.name, phone, email: null, blood_group: row.blood_group,
          profession: row.profession, address: null, photo_url: null, access_role: row.access_role,
          preferred_language: null })) {
          fail('conflict', `Existing User ${userId} does not match the committee source.`);
        }
        if (existing.access_role !== row.access_role) {
          fail('conflict', `Existing User ${userId} has a different access_role.`);
        }
        if (!directorySnapshot.exists) fail('conflict', `User ${userId} is missing user_directory.`);
        const existingDirectory = parseDirectory(directorySnapshot.data(), userId);
        if (!same(existingDirectory, { ...canonicalDirectory, active: existingDirectory.active })) {
          fail('conflict', `Directory ${userId} conflicts with the User.`);
        }
        if (existing.active !== true || existing.login_enabled !== true) {
          transaction.update(userReference, {
            active: true, login_enabled: true, updated_at: now, updated_by: null,
          });
        }
        if (existingDirectory.active !== true) transaction.update(directoryReference, { active: true });
      } else {
        if (directorySnapshot.exists) fail('conflict', `Directory ${userId} exists without its User.`);
        transaction.create(userReference, canonicalUser);
        transaction.create(directoryReference, canonicalDirectory);
      }

      if (!linkSnapshot.exists) {
        transaction.create(actualLinkReference, {
          user_id: userId, active: true, created_at: now, created_by: ACTOR,
        });
      } else {
        const link = parseAuthLink(linkSnapshot.data(), authUid);
        if (!link.active) transaction.update(actualLinkReference, { active: true });
      }

      if (!assignmentSnapshot.exists) {
        transaction.create(assignmentReference, expectedAssignment(userId, row, now));
      } else {
        const existingAssignment = assignmentSnapshot.data();
        if (!same(existingAssignment, { user_id: userId, term_id: OFFICIAL_COMMITTEE_TERM_ID, position: row.position })) {
          fail('conflict', `Assignment ${assignmentId} conflicts with the committee source.`);
        }
        if (existingAssignment.active !== true || existingAssignment.ended_at !== null) {
          transaction.update(assignmentReference, { active: true, ended_at: null });
        }
      }

      if (!userSnapshot.exists || !auditSnapshot.exists || !linkSnapshot.exists || !assignmentSnapshot.exists) {
        if (!auditSnapshot.exists) {
          transaction.create(auditReference, {
            action: 'committee.account_provision', actor_user_id: null, actor_auth_uid: null,
            target_path: userReference.path, occurred_at: now, operation_id: auditId,
            outcome: 'committed',
            changes: { user_id: { after: userId }, auth_uid: { after: authUid },
              access_role: { after: row.access_role }, active: { after: true }, login_enabled: { after: true },
              committee_assignment_id: { after: assignmentId } },
            reason: 'Trusted pre-provisioning from data/committee_2025_2027.json.',
          });
        }
        return { status: 'created' };
      }
      return { status: 'already-existing/reused' };
    });
    if (enableExistingAuth) {
      if (typeof auth.updateUser !== 'function') {
        fail('auth_update_unsupported', 'Firebase Auth account cannot be enabled by this operator client.');
      }
      await auth.updateUser(authUid, { disabled: false });
    }
    if (resetExistingAuthPassword) {
      if (typeof auth.updateUser !== 'function') {
        fail('auth_update_unsupported', 'Firebase Auth password reset is unavailable to this operator client.');
      }
      generatedPassword = password();
      await auth.updateUser(authUid, { password: generatedPassword });
    }
    return { ...result, serial: row.serial, userId, authUid, phone, generatedPassword, createdAuth };
  } catch (error) {
    if (createdAuth && typeof auth.deleteUser === 'function') {
      try { await auth.deleteUser(authUid); } catch (_) { /* report the original failure */ }
    }
    if (error instanceof AdmissionError) throw error;
    throw new AdmissionError('failed', `Committee row ${row.serial} failed: ${error.message}`);
  }
}

function writeCredentials(file, projectId, entries) {
  if (entries.length === 0) return null;
  const target = path.resolve(file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const body = {
    warning: 'Local one-time provisioning credentials. Delete after secure distribution. Never commit or upload this file.',
    project_id: projectId,
    generated_at: new Date().toISOString(),
    entries,
  };
  fs.writeFileSync(target, `${JSON.stringify(body, null, 2)}\n`, { encoding: 'utf8', mode: 0o600, flag: 'wx' });
  return target;
}

export async function provisionCommitteeAccounts({
  projectId,
  file,
  credentialsFile,
  db,
  auth,
  serverTimestamp,
  operationId,
  resetExistingPasswords = false,
}) {
  if (!['demo-rokter-badhon', 'rokterbadhon-b247b'].includes(projectId)) {
    fail('unsafe_target', 'Committee provisioning refuses an unknown Firebase project.');
  }
  validateId(operationId, 'operation ID');
  const rows = sourceRows(file);
  if (rows.some((row) => !ALLOWED_ROLES.has(row.access_role))) fail('invalid_role_mapping', 'Committee source contains an unknown access_role.');
  await ensureTerm({ db, serverTimestamp });

  const report = { detected: rows.length, created: [], alreadyExistingReused: [], skipped: [], conflict: [], failed: [], credentialsFile: null };
  const credentials = [];
  for (const row of rows) {
    try {
      const result = await provisionOne({
        db, auth, serverTimestamp, row, operationId,
        resetExistingPassword: resetExistingPasswords,
      });
      if (result.status === 'created') report.created.push({ serial: row.serial, userId: result.userId, phone: result.phone });
      else report.alreadyExistingReused.push({ serial: row.serial, userId: result.userId, phone: result.phone });
      if (result.generatedPassword) credentials.push({
        serial: row.serial, name: row.name, phone: result.phone,
        access_role: row.access_role, temporary_password: result.generatedPassword,
      });
    } catch (error) {
      const item = { serial: row.serial, phone: row.phone, code: error.code ?? 'failed', message: error.message };
      if (error.code === 'conflict' || error.code === 'operation_reused') report.conflict.push(item);
      else report.failed.push(item);
    }
  }
  if (credentials.length > 0) {
    const target = credentialsFile ?? path.resolve(process.cwd(), '.local', `committee-credentials-2025-2027-${operationId}.json`);
    try {
      report.credentialsFile = writeCredentials(target, projectId, credentials);
    } catch (error) {
      report.failed.push({ code: 'credentials_file_failed', message: error.message });
    }
  }
  return report;
}

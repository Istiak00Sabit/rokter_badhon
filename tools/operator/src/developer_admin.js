import {
  AdmissionError,
  parseAuthLink,
  parseDirectory,
  parseUser,
  projectDirectory,
  validateId,
} from './policy.js';
import { internalAuthEmailForPhone } from './auth_identity.js';

// This is deliberately the only legacy identity accepted by the repair path.
// It is the exact pre-v1.2.1 Auth/User pair documented in the repository
// inventory; this is not a general legacy-role migration command.
export const DOCUMENTED_LEGACY_DEVELOPER_ADMIN = Object.freeze({
  authUid: 'nb3LLlkwB9QlF8ePYqRKPtkhct32',
  userId: 'nb3LLlkwB9QlF8ePYqRKPtkhct32',
  legacyRole: 'admin',
});

function text(value, label, { nullable = false } = {}) {
  if (nullable && (value === undefined || value === null || value === '')) return null;
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new AdmissionError('invalid_argument', `${label} is required.`);
  }
  return value.trim();
}

function requireDocument(snapshot, label) {
  if (!snapshot?.exists) throw new AdmissionError('missing', `${label} does not exist.`);
  return snapshot.data();
}

async function requiredAuth(auth, uid) {
  try {
    const record = await auth.getUser(uid);
    if (record.disabled === true) {
      throw new AdmissionError('auth_disabled', 'Target Firebase Auth account is disabled.');
    }
    if (typeof record.email !== 'string' || record.email.length === 0) {
      throw new AdmissionError('auth_email_missing', 'Target Firebase Auth account has no email.');
    }
    return record;
  } catch (error) {
    if (error instanceof AdmissionError) throw error;
    if (error?.code === 'auth/user-not-found') {
      throw new AdmissionError('auth_identity_missing', 'Target Firebase Auth account does not exist.');
    }
    throw new AdmissionError('auth_lookup_failed', 'Target Firebase Auth account could not be verified.');
  }
}

async function migrateAuthIdentity(auth, record, identity) {
  let internalEmail;
  try {
    internalEmail = internalAuthEmailForPhone(identity.phone);
  } catch (_) {
    throw new AdmissionError('invalid_argument', 'Administrator phone is not a valid organization phone number.');
  }
  if (record.email === internalEmail) return { record, changed: false, previousEmail: record.email };
  if (record.email !== identity.email) {
    throw new AdmissionError('email_mismatch', 'Firebase Auth identity does not match the documented administrator.');
  }
  if (typeof auth.updateUser !== 'function') {
    throw new AdmissionError('auth_update_unsupported', 'Firebase Auth identity migration is unavailable.');
  }
  const updated = await auth.updateUser(record.uid, {
    email: internalEmail,
    emailVerified: false,
  });
  return { record: updated, changed: true, previousEmail: record.email };
}

async function rollbackAuthIdentity(auth, uid, previousEmail, previousVerified) {
  if (previousEmail && typeof auth.updateUser === 'function') {
    try {
      await auth.updateUser(uid, {
        email: previousEmail,
        emailVerified: previousVerified === true,
      });
    } catch (_) {
      // The original operation remains failed closed; an operator must repair
      // the Auth identity if the provider rollback itself fails.
    }
  }
}

async function optionalAuth(auth, uid) {
  try {
    return await auth.getUser(uid);
  } catch (error) {
    if (error?.code === 'auth/user-not-found') return null;
    throw new AdmissionError('auth_lookup_failed', 'Existing administrator Auth state could not be verified.');
  }
}

function validateInput({ authUid, operationId, reason, identity }) {
  validateId(authUid, 'Firebase Auth UID');
  validateId(operationId, 'operation ID');
  const normalized = {
    name: text(identity?.name, 'name'),
    phone: text(identity?.phone, 'phone'),
    email: text(identity?.email, 'email'),
    blood_group: text(identity?.blood_group, 'blood group', { nullable: true }),
    profession: text(identity?.profession, 'profession', { nullable: true }),
    address: text(identity?.address, 'address', { nullable: true }),
    preferred_language: text(identity?.preferred_language, 'preferred language', { nullable: true }),
  };
  return { identity: normalized, reason: text(reason, 'reason') };
}

function buildAdminUser(identity, serverTimestamp) {
  return {
    name: identity.name,
    phone: identity.phone,
    email: identity.email,
    blood_group: identity.blood_group,
    profession: identity.profession,
    address: identity.address,
    photo_url: null,
    access_role: 'developer_admin',
    active: true,
    login_enabled: true,
    preferred_language: identity.preferred_language,
    created_at: serverTimestamp(),
    created_by: null,
    updated_at: serverTimestamp(),
    updated_by: null,
  };
}

function exactProjection(user, directory) {
  const expected = projectDirectory(user);
  const actual = {
    name: directory.name,
    phone: directory.phone,
    blood_group: directory.blood_group,
    profession: directory.profession,
    photo_url: directory.photo_url,
    active: directory.active,
  };
  if (Object.keys(expected).some((key) => expected[key] !== actual[key])) {
    throw new AdmissionError('ambiguous_state', 'Existing developer_admin directory projection is not exact.');
  }
}

function documents(snapshot) {
  return snapshot.docs.map((document) => ({ id: document.id, data: document.data() }));
}

function hasUnexpectedIdentity(snapshot, allowedIds = new Set()) {
  return snapshot.docs.some((document) => !allowedIds.has(document.id));
}

function requiredTimestamp(value, label) {
  if (!value || typeof value.toMillis !== 'function') {
    throw new AdmissionError('invalid_argument', `${label} must be a Firestore Timestamp.`);
  }
  return value;
}

function legacyNullableText(value, field) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new AdmissionError('malformed', `Legacy ${field} is invalid.`);
  }
  return value.trim();
}

function legacyHttpsPhoto(value) {
  const photo = legacyNullableText(value, 'photo');
  if (photo === null) return null;
  if (!/^https:\/\/[^/]+.*$/.test(photo) || photo.length > 2048) {
    throw new AdmissionError('malformed', 'Legacy photo is not an approved HTTPS URL.');
  }
  return photo;
}

function sameProjection(left, right) {
  return ['name', 'phone', 'blood_group', 'profession', 'photo_url', 'active']
    .every((field) => left[field] === right[field]);
}

function parseLegacyCandidate(data, identity, authUid) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    throw new AdmissionError('malformed', 'Legacy developer-admin User is malformed.');
  }
  if (data.role !== DOCUMENTED_LEGACY_DEVELOPER_ADMIN.legacyRole) {
    throw new AdmissionError('legacy_identity_mismatch', 'Target is not the documented legacy admin record.');
  }
  if (data.active !== true) {
    throw new AdmissionError('legacy_inactive', 'Documented legacy admin must still be active before repair.');
  }
  if (!data.joined_date || typeof data.joined_date.toMillis !== 'function') {
    throw new AdmissionError('legacy_provenance_missing', 'Legacy admin joined_date provenance is missing or malformed.');
  }
  if (Object.prototype.hasOwnProperty.call(data, 'access_role') ||
      Object.prototype.hasOwnProperty.call(data, 'login_enabled') ||
      Object.prototype.hasOwnProperty.call(data, 'auth_uid') ||
      Object.prototype.hasOwnProperty.call(data, 'photo_url')) {
    throw new AdmissionError('legacy_shape_invalid', 'Target is not the documented pre-v1.2.1 User shape.');
  }
  if (data.uid !== authUid) {
    throw new AdmissionError('identity_mismatch', 'Legacy User UID does not exactly match Firebase Auth UID.');
  }

  const name = text(data.name, 'legacy name');
  const phone = text(data.phone, 'legacy phone');
  const email = text(data.email, 'legacy email');
  if (name !== identity.name || phone !== identity.phone || email !== identity.email) {
    throw new AdmissionError('identity_mismatch', 'Repair identity does not exactly match the legacy User.');
  }
  const bloodGroup = legacyNullableText(data.blood_group, 'blood_group');
  const profession = legacyNullableText(data.profession, 'profession');
  const address = legacyNullableText(data.address, 'address');
  if (bloodGroup !== identity.blood_group || profession !== identity.profession || address !== identity.address) {
    throw new AdmissionError('identity_mismatch', 'Repair profile fields do not exactly match the legacy User.');
  }
  return {
    name,
    phone,
    email,
    blood_group: bloodGroup,
    profession,
    address,
    photo_url: legacyHttpsPhoto(data.photo),
  };
}

function buildLegacyAdminUser(profile, createdAt, serverTimestamp) {
  return {
    ...profile,
    access_role: 'developer_admin',
    active: true,
    login_enabled: true,
    preferred_language: null,
    created_at: createdAt,
    created_by: null,
    updated_at: serverTimestamp(),
    updated_by: null,
  };
}

function auditMatches(audit, operationId, userId, authUid) {
  return audit?.action === 'admin.repair_legacy' &&
    audit.operation_id === operationId &&
    audit.outcome === 'committed' &&
    audit.target_path === `users/${userId}` &&
    audit.changes?.auth_uid?.after === authUid &&
    audit.changes?.access_role?.after === 'developer_admin';
}

function parseExistingDirectory(snapshot, expected, userId) {
  if (!snapshot.exists) return false;
  try {
    const actual = parseDirectory(snapshot.data(), userId);
    if (!sameProjection(actual, expected)) {
      throw new AdmissionError('identity_conflict', 'Existing directory does not match the legacy User.');
    }
  } catch (error) {
    if (error instanceof AdmissionError) throw error;
    throw new AdmissionError('identity_conflict', 'Existing directory is not a valid exact projection.');
  }
  return true;
}

export async function repairDocumentedLegacyDeveloperAdmin({
  db,
  auth,
  serverTimestamp,
  authUid,
  legacyUserId,
  identity,
  createdAt,
  operationId,
  reason,
}) {
  const validated = validateInput({ authUid, operationId, reason, identity });
  requiredTimestamp(createdAt, 'created-at');
  if (authUid !== DOCUMENTED_LEGACY_DEVELOPER_ADMIN.authUid ||
      legacyUserId !== DOCUMENTED_LEGACY_DEVELOPER_ADMIN.userId) {
    throw new AdmissionError('identity_conflict', 'Legacy repair only accepts the documented administrator identity.');
  }
  if (validated.identity.preferred_language !== null) {
    throw new AdmissionError('identity_mismatch', 'Legacy repair cannot invent a preferred language.');
  }

  const originalAuth = await requiredAuth(auth, authUid);
  const migratedAuth = await migrateAuthIdentity(auth, originalAuth, validated.identity);

  const user = db.collection('users').doc(legacyUserId);
  const directory = db.collection('user_directory').doc(legacyUserId);
  const link = db.collection('auth_links').doc(authUid);
  const audit = db.collection('audit_logs').doc(operationId);
  const adminUsers = db.collection('users').where('access_role', '==', 'developer_admin');
  const userLinks = db.collection('auth_links').where('user_id', '==', legacyUserId);
  const emailUsers = db.collection('users').where('email', '==', validated.identity.email);
  const phoneUsers = db.collection('users').where('phone', '==', validated.identity.phone);
  const phoneDirectory = db.collection('user_directory').where('phone', '==', validated.identity.phone);

  try {
    return await db.runTransaction(async (transaction) => {
    const [userSnapshot, directorySnapshot, linkSnapshot, auditSnapshot, adminSnapshot,
      userLinksSnapshot, emailUsersSnapshot, phoneUsersSnapshot, phoneDirectorySnapshot] = await Promise.all([
      transaction.get(user),
      transaction.get(directory),
      transaction.get(link),
      transaction.get(audit),
      transaction.get(adminUsers),
      transaction.get(userLinks),
      transaction.get(emailUsers),
      transaction.get(phoneUsers),
      transaction.get(phoneDirectory),
    ]);

    const existingAudit = auditSnapshot.exists ? auditSnapshot.data() : null;
    const existingUser = userSnapshot.exists ? userSnapshot.data() : null;
    const existingDirectory = directorySnapshot.exists ? directorySnapshot.data() : null;
    const existingLink = linkSnapshot.exists ? linkSnapshot.data() : null;
    const canonicalState = existingUser && existingDirectory && existingLink;

    if (existingAudit && !auditMatches(existingAudit, operationId, legacyUserId, authUid)) {
      throw new AdmissionError('operation_reused', 'Operation ID has already been used for another operation.');
    }

    if (canonicalState) {
      try {
        const parsedUser = parseUser(existingUser, legacyUserId);
        const parsedLink = parseAuthLink(existingLink, authUid);
        const expectedDirectory = projectDirectory(parsedUser);
        parseExistingDirectory(directorySnapshot, expectedDirectory, legacyUserId);
        const exactRetryIdentity = parsedUser.name === validated.identity.name &&
          parsedUser.phone === validated.identity.phone &&
          parsedUser.email === validated.identity.email &&
          parsedUser.blood_group === validated.identity.blood_group &&
          parsedUser.profession === validated.identity.profession &&
          parsedUser.address === validated.identity.address &&
          parsedUser.preferred_language === null &&
          parsedUser.created_at.toMillis() === createdAt.toMillis();
        if (parsedUser.access_role !== 'developer_admin' || !parsedUser.active ||
            !parsedUser.login_enabled || !parsedLink.active || parsedLink.user_id !== legacyUserId ||
            !exactRetryIdentity ||
            !auditMatches(existingAudit, operationId, legacyUserId, authUid)) {
          throw new AdmissionError('already_healthy_admin', 'A healthy developer_admin state already exists; repair is not allowed.');
        }
        return { action: 'developer_admin_legacy_repaired', userId: legacyUserId, operationId, idempotent: true };
      } catch (error) {
        if (error instanceof AdmissionError && error.code === 'already_healthy_admin') throw error;
        if (existingUser.access_role === 'developer_admin') {
          throw new AdmissionError('ambiguous_state', 'Existing developer_admin state is not an exact completed repair.');
        }
      }
    }
    if (existingAudit) {
      throw new AdmissionError('operation_reused', 'Operation ID has already been used without an exact completed repair.');
    }

    if (userSnapshot.exists === false) {
      throw new AdmissionError('missing', 'Documented legacy developer-admin User does not exist.');
    }
    const profile = parseLegacyCandidate(existingUser, validated.identity, authUid);
    const projectedUser = buildLegacyAdminUser(profile, createdAt, serverTimestamp);
    const projectedDirectory = projectDirectory(projectedUser);
    parseExistingDirectory(directorySnapshot, projectedDirectory, legacyUserId);

    for (const candidate of documents(adminSnapshot)) parseUser(candidate.data, candidate.id);
    if (!adminSnapshot.empty) {
      throw new AdmissionError('already_healthy_admin', 'A developer_admin User already exists; legacy repair is not allowed.');
    }
    if (linkSnapshot.exists || !userLinksSnapshot.empty) {
      throw new AdmissionError('identity_conflict', 'Legacy User already has an auth link of some state.');
    }
    const allowed = new Set([legacyUserId]);
    if (hasUnexpectedIdentity(emailUsersSnapshot, allowed) ||
        hasUnexpectedIdentity(phoneUsersSnapshot, allowed) ||
        hasUnexpectedIdentity(phoneDirectorySnapshot, allowed)) {
      throw new AdmissionError('identity_conflict', 'Legacy administrator identity conflicts with another record.');
    }

    transaction.set(user, projectedUser);
    transaction.set(directory, projectedDirectory);
    transaction.create(link, {
      user_id: legacyUserId,
      active: true,
      created_at: serverTimestamp(),
      created_by: legacyUserId,
    });
    transaction.create(audit, {
      action: 'admin.repair_legacy',
      actor_user_id: null,
      actor_auth_uid: null,
      target_path: user.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: {
        auth_uid: { after: authUid },
        access_role: { before: 'admin', after: 'developer_admin' },
        active: { after: true },
        login_enabled: { after: true },
      },
      reason: validated.reason,
    });
    return { action: 'developer_admin_legacy_repaired', userId: legacyUserId, operationId, idempotent: false };
    });
  } catch (error) {
    if (migratedAuth.changed) {
      await rollbackAuthIdentity(auth, authUid, migratedAuth.previousEmail, originalAuth.emailVerified);
    }
    throw error;
  }
}

export async function bootstrapDeveloperAdmin({
  db,
  auth,
  serverTimestamp,
  authUid,
  identity,
  operationId,
  reason,
}) {
  const validated = validateInput({ authUid, operationId, reason, identity });
  const originalAuth = await requiredAuth(auth, authUid);
  const migratedAuth = await migrateAuthIdentity(auth, originalAuth, validated.identity);

  const targetLink = db.collection('auth_links').doc(authUid);
  const newUser = db.collection('users').doc();
  const newDirectory = db.collection('user_directory').doc(newUser.id);
  const audit = db.collection('audit_logs').doc(operationId);
  const adminUsers = db.collection('users').where('access_role', '==', 'developer_admin');
  const userLinks = db.collection('auth_links').where('user_id', '==', newUser.id);
  const emailUsers = db.collection('users').where('email', '==', validated.identity.email);
  const phoneUsers = db.collection('users').where('phone', '==', validated.identity.phone);
  const phoneDirectory = db.collection('user_directory').where('phone', '==', validated.identity.phone);

  try {
    return await db.runTransaction(async (transaction) => {
    const [adminSnapshot, linkSnapshot, userSnapshot, directorySnapshot, auditSnapshot, userLinksSnapshot,
      emailUsersSnapshot, phoneUsersSnapshot, phoneDirectorySnapshot] =
      await Promise.all([
        transaction.get(adminUsers),
        transaction.get(targetLink),
        transaction.get(newUser),
        transaction.get(newDirectory),
        transaction.get(audit),
        transaction.get(userLinks),
        transaction.get(emailUsers),
        transaction.get(phoneUsers),
        transaction.get(phoneDirectory),
      ]);

    for (const candidate of documents(adminSnapshot)) parseUser(candidate.data, candidate.id);
    if (!adminSnapshot.empty) {
      throw new AdmissionError(
        'existing_admin_state',
        'Bootstrap requires zero existing developer_admin User records; use reviewed recovery instead.',
      );
    }
    if (linkSnapshot.exists) {
      throw new AdmissionError('existing_auth_link', 'Target Auth UID already has an auth link of some state.');
    }
    if (userSnapshot.exists || directorySnapshot.exists || !userLinksSnapshot.empty) {
      throw new AdmissionError('identity_conflict', 'Generated User/directory identity conflicts with existing data.');
    }
    if (!emailUsersSnapshot.empty || !phoneUsersSnapshot.empty || !phoneDirectorySnapshot.empty) {
      throw new AdmissionError('identity_conflict', 'Intended administrator identity conflicts with existing data.');
    }
    if (auditSnapshot.exists) {
      throw new AdmissionError('operation_reused', 'Operation ID has already been used.');
    }

    const user = buildAdminUser(validated.identity, serverTimestamp);
    transaction.create(newUser, user);
    transaction.create(newDirectory, projectDirectory(user));
    transaction.create(targetLink, {
      user_id: newUser.id,
      active: true,
      created_at: serverTimestamp(),
      created_by: newUser.id,
    });
    transaction.create(audit, {
      action: 'admin.provision',
      actor_user_id: null,
      actor_auth_uid: null,
      target_path: newUser.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: {
        user_id: { after: newUser.id },
        auth_uid: { after: authUid },
        access_role: { after: 'developer_admin' },
        active: { after: true },
        login_enabled: { after: true },
      },
      reason: validated.reason,
    });
    return { action: 'developer_admin_bootstrapped', userId: newUser.id, operationId };
    });
  } catch (error) {
    if (migratedAuth.changed) {
      await rollbackAuthIdentity(auth, authUid, migratedAuth.previousEmail, originalAuth.emailVerified);
    }
    throw error;
  }
}

export async function recoverDeveloperAdmin({
  db,
  auth,
  serverTimestamp,
  authUid,
  oldUserId,
  identity,
  operationId,
  reason,
}) {
  const validated = validateInput({ authUid, operationId, reason, identity });
  validateId(oldUserId, 'old developer_admin User ID');
  const originalAuth = await requiredAuth(auth, authUid);
  const migratedAuth = await migrateAuthIdentity(auth, originalAuth, validated.identity);

  const newLink = db.collection('auth_links').doc(authUid);
  const newUser = db.collection('users').doc();
  const newDirectory = db.collection('user_directory').doc(newUser.id);
  const oldUser = db.collection('users').doc(oldUserId);
  const oldDirectory = db.collection('user_directory').doc(oldUserId);
  const audit = db.collection('audit_logs').doc(operationId);
  const adminUsers = db.collection('users').where('access_role', '==', 'developer_admin');
  const oldLinks = db.collection('auth_links').where('user_id', '==', oldUserId);
  const newUserLinks = db.collection('auth_links').where('user_id', '==', newUser.id);
  const emailUsers = db.collection('users').where('email', '==', validated.identity.email);
  const phoneUsers = db.collection('users').where('phone', '==', validated.identity.phone);
  const phoneDirectory = db.collection('user_directory').where('phone', '==', validated.identity.phone);

  try {
    return await db.runTransaction(async (transaction) => {
    const [adminSnapshot, oldUserSnapshot, oldDirectorySnapshot, oldLinksSnapshot, newLinkSnapshot,
      newUserSnapshot, newDirectorySnapshot, auditSnapshot, newUserLinksSnapshot, emailUsersSnapshot,
      phoneUsersSnapshot, phoneDirectorySnapshot] = await Promise.all([
      transaction.get(adminUsers),
      transaction.get(oldUser),
      transaction.get(oldDirectory),
      transaction.get(oldLinks),
      transaction.get(newLink),
      transaction.get(newUser),
      transaction.get(newDirectory),
      transaction.get(audit),
      transaction.get(newUserLinks),
      transaction.get(emailUsers),
      transaction.get(phoneUsers),
      transaction.get(phoneDirectory),
    ]);

    const admins = documents(adminSnapshot).map((candidate) => parseUser(candidate.data, candidate.id));
    const previousUser = parseUser(requireDocument(oldUserSnapshot, 'Old developer_admin User'), oldUserId);
    if (previousUser.access_role !== 'developer_admin') {
      throw new AdmissionError('ordinary_promotion_denied', 'Recovery cannot promote an ordinary User.');
    }
    const currentCandidates = admins.filter((candidate) => candidate.active || candidate.login_enabled);
    if (currentCandidates.length !== 1 || currentCandidates[0].id !== oldUserId) {
      throw new AdmissionError(
        'ambiguous_admin_state',
        'Recovery requires exactly one explicitly identified non-historical developer_admin User.',
      );
    }
    const previousDirectory = parseDirectory(
      requireDocument(oldDirectorySnapshot, 'Old developer_admin directory'),
      oldUserId,
    );
    exactProjection(previousUser, previousDirectory);

    const links = documents(oldLinksSnapshot).map((candidate) => ({
      reference: db.collection('auth_links').doc(candidate.id),
      value: parseAuthLink(candidate.data, candidate.id),
    }));
    const activeLinks = links.filter((candidate) => candidate.value.active);
    if (activeLinks.length > 1) {
      throw new AdmissionError('ambiguous_admin_state', 'Old developer_admin has multiple active auth links.');
    }
    let oldAuth = null;
    if (activeLinks.length === 1) oldAuth = await optionalAuth(auth, activeLinks[0].value.uid);
    const healthy = previousUser.active && previousUser.login_enabled && activeLinks.length === 1 &&
      oldAuth !== null && oldAuth.disabled !== true &&
      typeof oldAuth.email === 'string' &&
      oldAuth.email === internalAuthEmailForPhone(previousUser.phone);
    if (healthy) {
      throw new AdmissionError('healthy_admin_exists', 'Existing developer_admin authority is healthy; recovery is forbidden.');
    }
    if (newLinkSnapshot.exists) {
      throw new AdmissionError('existing_auth_link', 'Replacement Auth UID already has an auth link of some state.');
    }
    if (newUserSnapshot.exists || newDirectorySnapshot.exists || !newUserLinksSnapshot.empty) {
      throw new AdmissionError('identity_conflict', 'Generated replacement identity conflicts with existing data.');
    }
    const oldIdentity = new Set([oldUserId]);
    if (hasUnexpectedIdentity(emailUsersSnapshot, oldIdentity) ||
        hasUnexpectedIdentity(phoneUsersSnapshot, oldIdentity) ||
        hasUnexpectedIdentity(phoneDirectorySnapshot, oldIdentity)) {
      throw new AdmissionError('identity_conflict', 'Replacement administrator identity conflicts with another User.');
    }
    if (auditSnapshot.exists) {
      throw new AdmissionError('operation_reused', 'Operation ID has already been used.');
    }

    const replacement = buildAdminUser(validated.identity, serverTimestamp);
    transaction.create(newUser, replacement);
    transaction.create(newDirectory, projectDirectory(replacement));
    transaction.create(newLink, {
      user_id: newUser.id,
      active: true,
      created_at: serverTimestamp(),
      created_by: newUser.id,
    });
    if (previousUser.active || previousUser.login_enabled) {
      transaction.update(oldUser, {
        active: false,
        login_enabled: false,
        updated_at: serverTimestamp(),
        updated_by: null,
      });
    }
    if (previousDirectory.active) transaction.update(oldDirectory, { active: false });
    if (activeLinks.length === 1) transaction.update(activeLinks[0].reference, { active: false });
    transaction.create(audit, {
      action: 'admin.recover',
      actor_user_id: null,
      actor_auth_uid: null,
      target_path: oldUser.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: {
        previous_user_id: { before: oldUserId, active_after: false, login_enabled_after: false },
        replacement_user_id: { after: newUser.id },
        replacement_auth_uid: { after: authUid },
        previous_active_link_deactivated: activeLinks.length === 1,
      },
      reason: validated.reason,
    });
    return {
      action: 'developer_admin_recovered',
      previousUserId: oldUserId,
      userId: newUser.id,
      operationId,
    };
    });
  } catch (error) {
    if (migratedAuth.changed) {
      await rollbackAuthIdentity(auth, authUid, migratedAuth.previousEmail, originalAuth.emailVerified);
    }
    throw error;
  }
}

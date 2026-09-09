import {
  AdmissionError,
  parseAuthLink,
  parseDirectory,
  parseUser,
  projectDirectory,
  validateId,
} from './policy.js';

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
    if (record.emailVerified !== true) {
      throw new AdmissionError('email_unverified', 'Target Firebase Auth email is not verified.');
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
  const authRecord = await requiredAuth(auth, authUid);
  if (authRecord.email !== validated.identity.email) {
    throw new AdmissionError('email_mismatch', 'Input email does not match Firebase Auth email.');
  }

  const targetLink = db.collection('auth_links').doc(authUid);
  const newUser = db.collection('users').doc();
  const newDirectory = db.collection('user_directory').doc(newUser.id);
  const audit = db.collection('audit_logs').doc(operationId);
  const adminUsers = db.collection('users').where('access_role', '==', 'developer_admin');
  const userLinks = db.collection('auth_links').where('user_id', '==', newUser.id);
  const emailUsers = db.collection('users').where('email', '==', validated.identity.email);
  const phoneUsers = db.collection('users').where('phone', '==', validated.identity.phone);
  const phoneDirectory = db.collection('user_directory').where('phone', '==', validated.identity.phone);

  return db.runTransaction(async (transaction) => {
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
  const newAuth = await requiredAuth(auth, authUid);
  if (newAuth.email !== validated.identity.email) {
    throw new AdmissionError('email_mismatch', 'Input email does not match replacement Firebase Auth email.');
  }

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

  return db.runTransaction(async (transaction) => {
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
      oldAuth !== null && oldAuth.disabled !== true && oldAuth.emailVerified === true &&
      typeof oldAuth.email === 'string' && oldAuth.email === previousUser.email;
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
}

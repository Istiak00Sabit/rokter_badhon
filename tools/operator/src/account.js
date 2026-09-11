import {
  AdmissionError,
  authorizeOperator,
  authorizeOperatorForRoles,
  parseAuthLink,
  parseDirectory,
  parseUser,
  projectDirectory,
  validateId,
} from './policy.js';

const ROLES = new Set(['developer_admin', 'leader', 'executive', 'committee', 'member']);
const ORDINARY_ROLES = new Set(['executive', 'committee', 'member']);

function fail(code, message) { throw new AdmissionError(code, message); }
function document(snapshot, label) { if (!snapshot?.exists) fail('missing', `${label} does not exist.`); return snapshot.data(); }
function text(value, label) { if (typeof value !== 'string' || value.trim().length === 0) fail('invalid_argument', `${label} is required.`); return value.trim(); }
function nullableText(value, label) {
  if (value === null) return null;
  if (typeof value !== 'string' || value.trim().length === 0) fail('invalid_argument', `${label} must be non-empty or null.`);
  return value.trim();
}
function photoUrl(value) {
  if (value === null) return null;
  if (typeof value !== 'string' || value.length > 2048 || !/^https:\/\/[^/]+.*$/.test(value)) fail('invalid_argument', 'photo URL must be HTTPS or null.');
  return value;
}
function same(left, right) { return JSON.stringify(left) === JSON.stringify(right); }
function assertCurrentUser(user) { if (!ROLES.has(user.access_role)) fail('malformed', 'Target User has an unknown role.'); }
function assertDirectory(user, directory) { if (!same(projectDirectory(user), projectDirectory(directory))) fail('projection_mismatch', 'User directory is missing, malformed, or out of sync.'); }
function common({ operatorUid, operationId, reason }) {
  validateId(operatorUid, 'operator UID'); validateId(operationId, 'operation ID');
  return text(reason, 'reason');
}
async function authRecord(auth, uid, label) {
  try { return await auth.getUser(uid); } catch (_) { fail('auth_identity_missing', `${label} Firebase Auth account does not exist.`); }
}
async function resolve(transaction, db, operatorUid, record, allowedRoles) {
  const link = parseAuthLink(document(await transaction.get(db.collection('auth_links').doc(operatorUid)), 'Operator auth link'), operatorUid);
  const user = parseUser(document(await transaction.get(db.collection('users').doc(link.user_id)), 'Operator User'), link.user_id);
  if (allowedRoles) authorizeOperatorForRoles({ authRecord: record, link, user, allowedRoles });
  else authorizeOperator({ authRecord: record, link, user });
  return user;
}
function audit({ action, actor, operatorUid, targetPath, operationId, reason, changes, serverTimestamp }) {
  return { action, actor_user_id: actor.id, actor_auth_uid: operatorUid, target_path: targetPath, occurred_at: serverTimestamp(), operation_id: operationId, outcome: 'committed', changes, reason };
}
function exactRetry(auditValue, { action, actor, targetPath, reason, after }) {
  return auditValue?.action === action && auditValue.actor_user_id === actor.id && auditValue.target_path === targetPath && auditValue.reason === reason && auditValue.changes?.value?.after === after;
}
function targetBoundary(actor, target, { leaderTarget = false } = {}) {
  assertCurrentUser(target);
  if (target.access_role === 'developer_admin') fail('protected_admin', 'Normal account management cannot target developer_admin.');
  if (leaderTarget) {
    if (actor.access_role !== 'developer_admin' || target.access_role !== 'leader' || actor.id === target.id) fail('unauthorized_target', 'Only developer_admin may manage another leader through this operation.');
    return;
  }
  if (!ORDINARY_ROLES.has(target.access_role) || actor.id === target.id) fail('unauthorized_target', 'This operation is limited to another ordinary User.');
}
async function loadTarget(transaction, db, userId) {
  const user = parseUser(document(await transaction.get(db.collection('users').doc(userId)), 'Target User'), userId);
  const directory = parseDirectory(document(await transaction.get(db.collection('user_directory').doc(userId)), 'Target directory'), userId);
  assertCurrentUser(user); assertDirectory(user, directory); return user;
}

export async function createOrganizationUser(dependencies) {
  const { db, auth, serverTimestamp, operatorUid, operationId } = dependencies;
  const reason = common(dependencies); const profile = {
    name: text(dependencies.name, 'name'), phone: text(dependencies.phone, 'phone'),
    email: nullableText(dependencies.email, 'email'), blood_group: nullableText(dependencies.bloodGroup, 'blood group'),
    profession: nullableText(dependencies.profession, 'profession'), address: nullableText(dependencies.address, 'address'),
    photo_url: photoUrl(dependencies.photoUrl), preferred_language: nullableText(dependencies.preferredLanguage, 'preferred language'),
  };
  const record = await authRecord(auth, operatorUid, 'Operator'); const userRef = db.collection('users').doc();
  const directoryRef = db.collection('user_directory').doc(userRef.id); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record); const auditSnapshot = await transaction.get(auditRef);
    if (auditSnapshot.exists) {
      const prior = auditSnapshot.data(); const priorId = prior.target_path?.startsWith('users/') ? prior.target_path.slice(6) : null;
      if (prior.action === 'user.create' && prior.actor_user_id === actor.id && prior.reason === reason && priorId) {
        const priorUser = parseUser(document(await transaction.get(db.collection('users').doc(priorId)), 'Previously created User'), priorId);
        if (same(Object.fromEntries(Object.keys(profile).map((key) => [key, priorUser[key]])), profile) && priorUser.access_role === 'member' && priorUser.active && !priorUser.login_enabled) return { action: 'user-already-created', userId: priorId, operationId };
      }
      fail('operation_reused', 'Operation ID has already been used with different input.');
    }
    if ((await transaction.get(userRef)).exists || (await transaction.get(directoryRef)).exists) fail('id_collision', 'Generated User ID already exists.');
    const user = { ...profile, access_role: 'member', active: true, login_enabled: false, created_at: serverTimestamp(), created_by: actor.id, updated_at: serverTimestamp(), updated_by: actor.id };
    transaction.create(userRef, user); transaction.create(directoryRef, projectDirectory(user));
    transaction.create(auditRef, audit({ action: 'user.create', actor, operatorUid, targetPath: userRef.path, operationId, reason, changes: { access_role: { after: 'member' }, active: { after: true }, login_enabled: { after: false } }, serverTimestamp }));
    return { action: 'user-created', userId: userRef.id, operationId };
  });
}

export async function assignAccessRole(dependencies) {
  const { db, auth, serverTimestamp, operatorUid, userId, targetRole, operationId } = dependencies;
  const reason = common(dependencies); validateId(userId, 'target User ID'); if (!['member', 'committee', 'executive', 'leader'].includes(targetRole)) fail('unauthorized_role', 'Target role is not assignable.');
  const record = await authRecord(auth, operatorUid, 'Operator'); const userRef = db.collection('users').doc(userId); const directoryRef = db.collection('user_directory').doc(userId); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record); const target = await loadTarget(transaction, db, userId);
    if (targetRole === 'leader') { if (actor.access_role !== 'developer_admin') fail('unauthorized', 'Only developer_admin may assign leader.'); targetBoundary(actor, target); }
    else if (actor.access_role === 'developer_admin') {
      if (target.access_role === 'developer_admin' || actor.id === target.id) fail('protected_admin', 'Normal role assignment cannot target developer_admin.');
    } else targetBoundary(actor, target);
    const action = `role.assign_${targetRole}`; const auditSnapshot = await transaction.get(auditRef);
    if (target.access_role === targetRole && auditSnapshot.exists && exactRetry(auditSnapshot.data(), { action, actor, targetPath: userRef.path, reason, after: targetRole })) return { action: 'role-already-assigned', userId, operationId };
    if (target.access_role === targetRole) fail('no_change', 'Target already has that role.');
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(userRef, { access_role: targetRole, updated_at: serverTimestamp(), updated_by: actor.id }); transaction.update(directoryRef, projectDirectory(target));
    transaction.create(auditRef, audit({ action, actor, operatorUid, targetPath: userRef.path, operationId, reason, changes: { value: { before: target.access_role, after: targetRole } }, serverTimestamp }));
    return { action: 'role-assigned', userId, operationId };
  });
}

async function changeUserFlag(dependencies, { field, desired, actionBase, requireActiveLink = false }) {
  const { db, auth, serverTimestamp, operatorUid, userId, operationId, leaderTarget = false } = dependencies;
  const reason = common(dependencies); validateId(userId, 'target User ID'); const record = await authRecord(auth, operatorUid, 'Operator');
  const userRef = db.collection('users').doc(userId); const directoryRef = db.collection('user_directory').doc(userId); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record); const target = await loadTarget(transaction, db, userId); targetBoundary(actor, target, { leaderTarget });
    if (requireActiveLink) {
      if (!target.active) fail('target_inactive', 'Login cannot be enabled for an inactive User.');
      const links = await transaction.get(db.collection('auth_links').where('user_id', '==', userId).where('active', '==', true));
      if (links.docs.length !== 1) fail('link_state_invalid', 'Target must have exactly one active Auth link.');
      const linkedAuth = await authRecord(auth, links.docs[0].id, 'Target');
      if (linkedAuth.disabled || linkedAuth.emailVerified !== true || (target.email !== null && linkedAuth.email !== target.email)) fail('target_identity_invalid', 'Target Auth identity is disabled, unverified, or mismatched.');
    }
    const action = `${actionBase}${leaderTarget ? '_leader' : ''}`; const auditSnapshot = await transaction.get(auditRef);
    if (target[field] === desired && auditSnapshot.exists && exactRetry(auditSnapshot.data(), { action, actor, targetPath: userRef.path, reason, after: desired })) return { action: `${action}-already-applied`, userId, operationId };
    if (target[field] === desired) fail('no_change', `Target ${field} already has the requested state.`);
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    const afterUser = { ...target, [field]: desired }; transaction.update(userRef, { [field]: desired, updated_at: serverTimestamp(), updated_by: actor.id }); transaction.update(directoryRef, projectDirectory(afterUser));
    transaction.create(auditRef, audit({ action, actor, operatorUid, targetPath: userRef.path, operationId, reason, changes: { value: { before: target[field], after: desired } }, serverTimestamp }));
    return { action: `${action}-applied`, userId, operationId };
  });
}
export function setUserActive(dependencies) {
  if (typeof dependencies.active !== 'boolean') fail('invalid_argument', 'active must be boolean.');
  return changeUserFlag(dependencies, { field: 'active', desired: dependencies.active, actionBase: dependencies.active ? 'user.reactivate' : 'user.disable' });
}
export function setLoginEnabled(dependencies) {
  if (typeof dependencies.enabled !== 'boolean') fail('invalid_argument', 'enabled must be boolean.');
  return changeUserFlag(dependencies, { field: 'login_enabled', desired: dependencies.enabled, actionBase: dependencies.enabled ? 'login.enable' : 'login.disable', requireActiveLink: dependencies.enabled });
}

function verifyTargetAuth(record, target) {
  if (record.disabled || record.emailVerified !== true || typeof record.email !== 'string' || target.email === null || record.email !== target.email) fail('target_identity_invalid', 'Target Auth identity must be enabled, verified, and match the User email.');
}
export async function createAuthLink(dependencies) {
  const { db, auth, serverTimestamp, operatorUid, userId, targetAuthUid, operationId, leaderTarget = false } = dependencies;
  const reason = common(dependencies); validateId(userId, 'target User ID'); validateId(targetAuthUid, 'target Auth UID');
  const [operatorRecord, targetRecord] = await Promise.all([authRecord(auth, operatorUid, 'Operator'), authRecord(auth, targetAuthUid, 'Target')]);
  const linkRef = db.collection('auth_links').doc(targetAuthUid); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, operatorRecord); const target = await loadTarget(transaction, db, userId); targetBoundary(actor, target, { leaderTarget }); verifyTargetAuth(targetRecord, target);
    const existingForUser = await transaction.get(db.collection('auth_links').where('user_id', '==', userId).where('active', '==', true)); const linkSnapshot = await transaction.get(linkRef); const action = `auth_link.create${leaderTarget ? '_leader' : ''}`; const auditSnapshot = await transaction.get(auditRef);
    if (linkSnapshot.exists && auditSnapshot.exists) {
      const link = parseAuthLink(linkSnapshot.data(), targetAuthUid);
      if (link.active && link.user_id === userId && exactRetry(auditSnapshot.data(), { action, actor, targetPath: linkRef.path, reason, after: targetAuthUid })) return { action: 'auth-link-already-created', userId, targetAuthUid, operationId };
    }
    if (linkSnapshot.exists || !existingForUser.empty) fail('link_conflict', 'Target Auth UID or User already has an active link.');
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.create(linkRef, { user_id: userId, active: true, created_at: serverTimestamp(), created_by: actor.id });
    transaction.create(auditRef, audit({ action, actor, operatorUid, targetPath: linkRef.path, operationId, reason, changes: { value: { after: targetAuthUid }, user_id: { after: userId } }, serverTimestamp }));
    return { action: 'auth-link-created', userId, targetAuthUid, operationId };
  });
}

export async function replaceAuthLink(dependencies) {
  const { db, auth, serverTimestamp, operatorUid, userId, oldAuthUid, newAuthUid, operationId, leaderTarget = false } = dependencies;
  const reason = common(dependencies); validateId(userId, 'target User ID'); validateId(oldAuthUid, 'old Auth UID'); validateId(newAuthUid, 'new Auth UID'); if (oldAuthUid === newAuthUid) fail('invalid_argument', 'Old and new Auth UIDs must differ.');
  const [operatorRecord, newRecord] = await Promise.all([authRecord(auth, operatorUid, 'Operator'), authRecord(auth, newAuthUid, 'Target')]);
  const oldRef = db.collection('auth_links').doc(oldAuthUid); const newRef = db.collection('auth_links').doc(newAuthUid); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, operatorRecord); const target = await loadTarget(transaction, db, userId); targetBoundary(actor, target, { leaderTarget }); verifyTargetAuth(newRecord, target);
    const oldSnapshot = await transaction.get(oldRef); const newSnapshot = await transaction.get(newRef); const auditSnapshot = await transaction.get(auditRef); const action = `auth_link.replace${leaderTarget ? '_leader' : ''}`;
    if (oldSnapshot.exists && newSnapshot.exists && auditSnapshot.exists) {
      const oldLink = parseAuthLink(oldSnapshot.data(), oldAuthUid); const newLink = parseAuthLink(newSnapshot.data(), newAuthUid);
      if (!oldLink.active && newLink.active && oldLink.user_id === userId && newLink.user_id === userId && exactRetry(auditSnapshot.data(), { action, actor, targetPath: newRef.path, reason, after: newAuthUid })) return { action: 'auth-link-already-replaced', userId, newAuthUid, operationId };
    }
    const oldLink = parseAuthLink(document(oldSnapshot, 'Old Auth link'), oldAuthUid); if (!oldLink.active || oldLink.user_id !== userId) fail('link_state_invalid', 'Old link is not the active link for target User.');
    if (newSnapshot.exists) fail('link_conflict', 'New Auth UID already has a link document.');
    const activeLinks = await transaction.get(db.collection('auth_links').where('user_id', '==', userId).where('active', '==', true)); if (activeLinks.docs.length !== 1 || activeLinks.docs[0].id !== oldAuthUid) fail('link_state_invalid', 'Target must have exactly one active link matching old Auth UID.');
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(oldRef, { active: false }); transaction.create(newRef, { user_id: userId, active: true, created_at: serverTimestamp(), created_by: actor.id });
    transaction.create(auditRef, audit({ action, actor, operatorUid, targetPath: newRef.path, operationId, reason, changes: { value: { before: oldAuthUid, after: newAuthUid }, user_id: { after: userId } }, serverTimestamp }));
    return { action: 'auth-link-replaced', userId, newAuthUid, operationId };
  });
}

export async function updateOwnPhoto(dependencies) {
  const { db, auth, serverTimestamp, operatorUid, operationId } = dependencies; const reason = common(dependencies); const value = photoUrl(dependencies.photoUrl); const record = await authRecord(auth, operatorUid, 'Operator'); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record, ['developer_admin', 'leader', 'executive', 'committee', 'member']); const userRef = db.collection('users').doc(actor.id); const directoryRef = db.collection('user_directory').doc(actor.id); const target = await loadTarget(transaction, db, actor.id); const auditSnapshot = await transaction.get(auditRef);
    if (target.photo_url === value && auditSnapshot.exists && exactRetry(auditSnapshot.data(), { action: 'user.photo_update', actor, targetPath: userRef.path, reason, after: value })) return { action: 'photo-already-updated', userId: actor.id, operationId };
    if (target.photo_url === value) fail('no_change', 'Photo URL is unchanged.'); if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    const afterUser = { ...target, photo_url: value }; transaction.update(userRef, { photo_url: value, updated_at: serverTimestamp(), updated_by: actor.id }); transaction.update(directoryRef, projectDirectory(afterUser));
    transaction.create(auditRef, audit({ action: 'user.photo_update', actor, operatorUid, targetPath: userRef.path, operationId, reason, changes: { value: { before: target.photo_url, after: value } }, serverTimestamp }));
    return { action: 'photo-updated', userId: actor.id, operationId };
  });
}

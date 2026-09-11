import { AdmissionError, authorizeOperator, parseAuthLink, parseUser, validateId } from './policy.js';

const FIELDS = new Set(['title', 'body', 'important', 'status', 'created_by', 'created_at', 'updated_by', 'updated_at']);
function fail(code, message) { throw new AdmissionError(code, message); }
function document(snapshot, label) { if (!snapshot?.exists) fail('missing', `${label} does not exist.`); return snapshot.data(); }
function text(value, label) { if (typeof value !== 'string' || value.trim().length === 0) fail('invalid_argument', `${label} is required.`); return value.trim(); }
function timestamp(value, label, nullable = false) { if (nullable && value === null) return; if (!value || typeof value.toMillis !== 'function') fail('malformed', `${label} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`); }
function parseNotice(data, id) {
  const keys = data && typeof data === 'object' && !Array.isArray(data) ? Object.keys(data) : [];
  if (keys.length !== FIELDS.size || keys.some((key) => !FIELDS.has(key))) fail('malformed', 'Notice has missing or unapproved fields.');
  validateId(id, 'notice ID'); text(data.title, 'title'); text(data.body, 'body');
  if (typeof data.important !== 'boolean') fail('malformed', 'important must be boolean.');
  if (!['draft', 'published', 'archived'].includes(data.status)) fail('malformed', 'Notice status is unknown.');
  validateId(data.created_by, 'created_by'); timestamp(data.created_at, 'created_at');
  if (data.updated_by !== null) validateId(data.updated_by, 'updated_by');
  timestamp(data.updated_at, 'updated_at', true);
  if ((data.updated_by === null) !== (data.updated_at === null)) fail('malformed', 'Notice update metadata is inconsistent.');
  return { id, ...data };
}
async function authRecord(auth, uid) { try { return await auth.getUser(uid); } catch (_) { fail('auth_identity_missing', 'Operator Auth account does not exist.'); } }
async function resolve(transaction, db, uid, record) {
  const link = parseAuthLink(document(await transaction.get(db.collection('auth_links').doc(uid)), 'Operator auth link'), uid);
  const user = parseUser(document(await transaction.get(db.collection('users').doc(link.user_id)), 'Operator User'), link.user_id);
  authorizeOperator({ authRecord: record, link, user }); return user;
}
function common(operatorUid, operationId, reason) { validateId(operatorUid, 'operator UID'); validateId(operationId, 'operation ID'); return text(reason, 'reason'); }
function audit({ action, actor, operatorUid, path, operationId, reason, changes, serverTimestamp }) { return { action, actor_user_id: actor.id, actor_auth_uid: operatorUid, target_path: path, occurred_at: serverTimestamp(), operation_id: operationId, outcome: 'committed', changes, reason }; }

export async function createNotice({ db, auth, serverTimestamp, operatorUid, title, body, important, operationId, reason }) {
  const why = common(operatorUid, operationId, reason); const normalizedTitle = text(title, 'title'); const normalizedBody = text(body, 'body');
  if (typeof important !== 'boolean') fail('invalid_argument', 'important must be boolean.');
  const record = await authRecord(auth, operatorUid); const ref = db.collection('notices').doc(); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record);
    if ((await transaction.get(auditRef)).exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.create(ref, { title: normalizedTitle, body: normalizedBody, important, status: 'draft', created_by: actor.id, created_at: serverTimestamp(), updated_by: null, updated_at: null });
    transaction.create(auditRef, audit({ action: 'notice.create', actor, operatorUid, path: ref.path, operationId, reason: why, changes: { status: { after: 'draft' }, title: { after: normalizedTitle } }, serverTimestamp }));
    return { action: 'notice-created', noticeId: ref.id, operationId };
  });
}

export async function editNotice(dependencies) {
  const { db, auth, serverTimestamp, operatorUid, noticeId, operationId, reason } = dependencies;
  const why = common(operatorUid, operationId, reason); validateId(noticeId, 'notice ID'); const changes = {};
  if (dependencies.title !== undefined) changes.title = text(dependencies.title, 'title');
  if (dependencies.body !== undefined) changes.body = text(dependencies.body, 'body');
  if (dependencies.important !== undefined) { if (typeof dependencies.important !== 'boolean') fail('invalid_argument', 'important must be boolean.'); changes.important = dependencies.important; }
  if (Object.keys(changes).length === 0) fail('invalid_argument', 'At least one editable field is required.');
  const record = await authRecord(auth, operatorUid); const ref = db.collection('notices').doc(noticeId); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record); const current = parseNotice(document(await transaction.get(ref), 'Notice'), noticeId);
    if (current.status === 'archived') fail('notice_archived', 'Archived notices cannot be edited.');
    if ((await transaction.get(auditRef)).exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(ref, { ...changes, updated_by: actor.id, updated_at: serverTimestamp() });
    transaction.create(auditRef, audit({ action: 'notice.edit', actor, operatorUid, path: ref.path, operationId, reason: why, changes: Object.fromEntries(Object.entries(changes).map(([key, value]) => [key, { before: current[key], after: value }])), serverTimestamp }));
    return { action: 'notice-edited', noticeId, operationId };
  });
}

async function transition(dependencies, target) {
  const { db, auth, serverTimestamp, operatorUid, noticeId, operationId, reason } = dependencies;
  const why = common(operatorUid, operationId, reason); validateId(noticeId, 'notice ID');
  const record = await authRecord(auth, operatorUid); const ref = db.collection('notices').doc(noticeId); const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record); const current = parseNotice(document(await transaction.get(ref), 'Notice'), noticeId); const auditSnapshot = await transaction.get(auditRef);
    const action = `notice.${target === 'published' ? 'publish' : 'archive'}`;
    const exactRetry = auditSnapshot.exists && auditSnapshot.data().action === action && auditSnapshot.data().target_path === ref.path && auditSnapshot.data().actor_user_id === actor.id;
    if (current.status === target && exactRetry) return { action: `notice-already-${target}`, noticeId, operationId };
    if ((target === 'published' && current.status !== 'draft') || (target === 'archived' && !['draft', 'published'].includes(current.status))) fail('invalid_transition', `Cannot transition ${current.status} to ${target}.`);
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(ref, { status: target, updated_by: actor.id, updated_at: serverTimestamp() });
    transaction.create(auditRef, audit({ action, actor, operatorUid, path: ref.path, operationId, reason: why, changes: { status: { before: current.status, after: target } }, serverTimestamp }));
    return { action: `notice-${target}`, noticeId, operationId };
  });
}
export function publishNotice(dependencies) { return transition(dependencies, 'published'); }
export function archiveNotice(dependencies) { return transition(dependencies, 'archived'); }
export const noticeSchemaFields = FIELDS;

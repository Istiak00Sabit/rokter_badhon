import {
  AdmissionError,
  authorizeOperatorForRoles,
  parseAuthLink,
  parseUser,
  validateId,
} from './policy.js';

const FIELDS = new Set([
  'blood_group', 'patient_name', 'hospital', 'location', 'contact_name',
  'contact_phone', 'required_at', 'status', 'created_by', 'created_at',
  'fulfilled_by', 'fulfilled_at',
]);
const INPUTS = new Map([
  ['bloodGroup', ['blood_group', 10, false]],
  ['patientName', ['patient_name', 200, true]],
  ['hospital', ['hospital', 300, false]],
  ['location', ['location', 300, false]],
  ['contactName', ['contact_name', 200, false]],
  ['contactPhone', ['contact_phone', 100, false]],
]);
function fail(code, message) { throw new AdmissionError(code, message); }
function document(snapshot, label) {
  if (!snapshot?.exists) fail('missing', `${label} does not exist.`);
  return snapshot.data();
}
function text(value, label, max, nullable = false) {
  if (nullable && value === null) return null;
  if (typeof value !== 'string' || value.trim().length === 0 || value.trim().length > max) fail('invalid_argument', `${label} is invalid.`);
  return value.trim();
}
function timestamp(value, label, nullable = false) {
  if (nullable && value === null) return;
  if (!value || typeof value.toMillis !== 'function') fail('malformed', `${label} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`);
}
function parseRequest(data, id) {
  const keys = data && typeof data === 'object' && !Array.isArray(data) ? Object.keys(data) : [];
  if (keys.length !== FIELDS.size || keys.some((key) => !FIELDS.has(key))) fail('malformed', 'BloodRequest has missing or unapproved fields.');
  validateId(id, 'request ID');
  text(data.blood_group, 'blood_group', 10);
  text(data.patient_name, 'patient_name', 200, true);
  text(data.hospital, 'hospital', 300);
  text(data.location, 'location', 300);
  text(data.contact_name, 'contact_name', 200);
  text(data.contact_phone, 'contact_phone', 100);
  timestamp(data.required_at, 'required_at', true);
  if (!['active', 'fulfilled', 'cancelled'].includes(data.status)) fail('malformed', 'Request status is unknown.');
  validateId(data.created_by, 'created_by');
  timestamp(data.created_at, 'created_at');
  if (data.fulfilled_by !== null) validateId(data.fulfilled_by, 'fulfilled_by');
  timestamp(data.fulfilled_at, 'fulfilled_at', true);
  if (data.status === 'fulfilled' && (data.fulfilled_by === null || data.fulfilled_at === null)) fail('malformed', 'Fulfilled request metadata is incomplete.');
  if (data.status !== 'fulfilled' && (data.fulfilled_by !== null || data.fulfilled_at !== null)) fail('malformed', 'Non-fulfilled request has fulfillment metadata.');
  return { id, ...data };
}
async function authRecord(auth, uid) {
  try { return await auth.getUser(uid); } catch (_) { fail('auth_identity_missing', 'Operator Auth account does not exist.'); }
}
async function resolve(transaction, db, uid, record) {
  const link = parseAuthLink(document(await transaction.get(db.collection('auth_links').doc(uid)), 'Operator auth link'), uid);
  const user = parseUser(document(await transaction.get(db.collection('users').doc(link.user_id)), 'Operator User'), link.user_id);
  authorizeOperatorForRoles({ authRecord: record, link, user, allowedRoles: ['developer_admin', 'leader', 'executive', 'committee'] });
  return user;
}
function common(operatorUid, operationId, reason) {
  validateId(operatorUid, 'operator UID');
  validateId(operationId, 'operation ID');
  return text(reason, 'reason', 2000);
}
function audit({ action, actor, operatorUid, path, operationId, reason, changes, serverTimestamp }) {
  return { action, actor_user_id: actor.id, actor_auth_uid: operatorUid, target_path: path, occurred_at: serverTimestamp(), operation_id: operationId, outcome: 'committed', changes, reason };
}

export async function editBloodRequest(dependencies) {
  const { db, auth, serverTimestamp, operatorUid, requestId, operationId, reason } = dependencies;
  const why = common(operatorUid, operationId, reason);
  validateId(requestId, 'request ID');
  const changes = {};
  for (const [input, [field, max, nullable]] of INPUTS) {
    if (dependencies[input] !== undefined) changes[field] = text(dependencies[input], field, max, nullable);
  }
  if (dependencies.requiredAt !== undefined) { timestamp(dependencies.requiredAt, 'required_at', true); changes.required_at = dependencies.requiredAt; }
  if (Object.keys(changes).length === 0) fail('invalid_argument', 'At least one editable field is required.');
  const record = await authRecord(auth, operatorUid);
  const ref = db.collection('blood_requests').doc(requestId);
  const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record);
    const current = parseRequest(document(await transaction.get(ref), 'Blood request'), requestId);
    if (current.status !== 'active') fail('request_terminal', 'Terminal requests cannot be edited.');
    if ((await transaction.get(auditRef)).exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(ref, changes);
    transaction.create(auditRef, audit({ action: 'blood_request.edit', actor, operatorUid, path: ref.path, operationId, reason: why, changes: Object.fromEntries(Object.entries(changes).map(([key, value]) => [key, { before: current[key], after: value }])), serverTimestamp }));
    return { action: 'blood-request-edited', requestId, operationId };
  });
}

async function transition(dependencies, target) {
  const { db, auth, serverTimestamp, operatorUid, requestId, operationId, reason } = dependencies;
  const why = common(operatorUid, operationId, reason);
  validateId(requestId, 'request ID');
  const record = await authRecord(auth, operatorUid);
  const ref = db.collection('blood_requests').doc(requestId);
  const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record);
    const current = parseRequest(document(await transaction.get(ref), 'Blood request'), requestId);
    const auditSnapshot = await transaction.get(auditRef);
    const expectedAction = `blood_request.${target === 'fulfilled' ? 'fulfill' : 'cancel'}`;
    const exactRetry = auditSnapshot.exists
      && auditSnapshot.data().action === expectedAction
      && auditSnapshot.data().target_path === ref.path
      && auditSnapshot.data().actor_user_id === actor.id;
    if (current.status === target && exactRetry) return { action: `blood-request-already-${target}`, requestId, operationId };
    if (current.status !== 'active') fail('request_terminal', 'Request is already terminal and cannot transition.');
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    const fields = target === 'fulfilled'
      ? { status: target, fulfilled_by: actor.id, fulfilled_at: serverTimestamp() }
      : { status: target };
    transaction.update(ref, fields);
    transaction.create(auditRef, audit({ action: expectedAction, actor, operatorUid, path: ref.path, operationId, reason: why, changes: { status: { before: 'active', after: target } }, serverTimestamp }));
    return { action: `blood-request-${target}`, requestId, operationId };
  });
}
export function fulfillBloodRequest(dependencies) { return transition(dependencies, 'fulfilled'); }
export function cancelBloodRequest(dependencies) { return transition(dependencies, 'cancelled'); }
export const bloodRequestSchemaFields = FIELDS;

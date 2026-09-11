import {
  AdmissionError,
  authorizeOperator,
  parseAuthLink,
  parseUser,
  validateId,
} from './policy.js';

const DONOR_FIELDS = new Set([
  'name', 'phone', 'blood_group', 'gender', 'photo_url', 'village', 'union',
  'upazila', 'district', 'profession', 'linked_user_id', 'active',
  'last_donated_at', 'total_donations', 'created_at', 'created_by',
  'updated_at', 'updated_by',
]);

function fail(code, message) {
  throw new AdmissionError(code, message);
}

function requireDocument(snapshot, label) {
  if (!snapshot?.exists) fail('missing', `${label} does not exist.`);
  return snapshot.data();
}

function timestamp(value, field, nullable = false) {
  if (nullable && value === null) return;
  if (!value || typeof value.toMillis !== 'function') {
    fail('malformed', `${field} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`);
  }
}

function nullableString(value, field) {
  if (value !== null && (typeof value !== 'string' || value.length === 0)) {
    fail('malformed', `${field} must be a non-empty string or null.`);
  }
}

function parseDonor(data, id) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) fail('malformed', 'Donor must be an object.');
  const keys = Object.keys(data);
  if (keys.length !== DONOR_FIELDS.size || keys.some((key) => !DONOR_FIELDS.has(key))) {
    fail('malformed', 'Donor has missing or unapproved fields.');
  }
  for (const field of ['name', 'phone', 'blood_group', 'upazila', 'district']) {
    if (typeof data[field] !== 'string' || data[field].length === 0) fail('malformed', `${field} must be non-empty.`);
  }
  for (const field of ['gender', 'village', 'union', 'profession']) nullableString(data[field], field);
  nullableString(data.linked_user_id, 'linked_user_id');
  if (data.photo_url !== null && (typeof data.photo_url !== 'string' || data.photo_url.length > 2048 || !/^https:\/\/[^/]+.*$/.test(data.photo_url))) {
    fail('malformed', 'photo_url must be HTTPS or null.');
  }
  if (typeof data.active !== 'boolean') fail('malformed', 'active must be boolean.');
  timestamp(data.last_donated_at, 'last_donated_at', true);
  if (!Number.isInteger(data.total_donations) || data.total_donations < 0) fail('malformed', 'total_donations must be a nonnegative integer.');
  timestamp(data.created_at, 'created_at');
  timestamp(data.updated_at, 'updated_at');
  validateId(data.created_by, 'created_by');
  validateId(data.updated_by, 'updated_by');
  return { id, ...data };
}

async function getAuthRecord(auth, uid) {
  try {
    return await auth.getUser(uid);
  } catch (_) {
    fail('auth_identity_missing', 'Operator Firebase Auth account does not exist.');
  }
}

export async function deactivateDonor({
  db, auth, serverTimestamp, operatorUid, donorId, operationId, reason,
}) {
  validateId(operatorUid, 'operator UID');
  validateId(donorId, 'donor ID');
  validateId(operationId, 'operation ID');
  if (typeof reason !== 'string' || reason.trim().length === 0) fail('invalid_argument', 'reason is required.');
  const authRecord = await getAuthRecord(auth, operatorUid);
  const donorReference = db.collection('donors').doc(donorId);
  const auditReference = db.collection('audit_logs').doc(operationId);

  return db.runTransaction(async (transaction) => {
    const link = parseAuthLink(
      requireDocument(await transaction.get(db.collection('auth_links').doc(operatorUid)), 'Operator auth link'),
      operatorUid,
    );
    const operator = parseUser(
      requireDocument(await transaction.get(db.collection('users').doc(link.user_id)), 'Operator User'),
      link.user_id,
    );
    authorizeOperator({ authRecord, link, user: operator });
    const donor = parseDonor(requireDocument(await transaction.get(donorReference), 'Donor'), donorId);
    if (!donor.active) fail('already_inactive', 'Donor is already inactive.');
    if ((await transaction.get(auditReference)).exists) fail('operation_reused', 'Operation ID has already been used.');
    const updatedAt = serverTimestamp();
    transaction.update(donorReference, {
      active: false,
      updated_at: updatedAt,
      updated_by: operator.id,
    });
    transaction.create(auditReference, {
      action: 'donor.deactivate',
      actor_user_id: operator.id,
      actor_auth_uid: operatorUid,
      target_path: donorReference.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: { active: { before: true, after: false } },
      reason: reason.trim(),
    });
    return { action: 'donor-deactivated', donorId, operationId };
  });
}

export const donorSchemaFields = DONOR_FIELDS;

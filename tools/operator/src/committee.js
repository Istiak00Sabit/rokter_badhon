import {
  AdmissionError,
  authorizeOperator,
  parseAuthLink,
  parseDirectory,
  parseUser,
  projectDirectory,
  validateId,
} from './policy.js';

const RECOGNIZED_ROLES = new Set([
  'developer_admin',
  'leader',
  'executive',
  'committee',
  'member',
]);
const TERM_FIELDS = new Set([
  'name', 'start_year', 'end_year', 'start_date', 'end_date', 'active',
  'group_photo_url', 'created_at', 'created_by',
]);
const ASSIGNMENT_FIELDS = new Set([
  'user_id', 'term_id', 'position', 'active', 'assigned_at', 'assigned_by', 'ended_at',
]);
const POSITION_PATTERN = /^[a-z][a-z0-9_]{0,63}$/;

function fail(code, message) {
  throw new AdmissionError(code, message);
}

function requireText(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    fail('invalid_argument', `${label} is required.`);
  }
  return value.trim();
}

function requireDocument(snapshot, label) {
  if (!snapshot?.exists) fail('missing', `${label} does not exist.`);
  return snapshot.data();
}

function exactFields(value, fields, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('malformed', `${label} must be an object.`);
  }
  const keys = Object.keys(value);
  if (keys.length !== fields.size || keys.some((key) => !fields.has(key))) {
    fail('malformed', `${label} has missing or unapproved fields.`);
  }
}

function timestamp(value, field, nullable = false) {
  if (nullable && value === null) return;
  if (!value || typeof value.toMillis !== 'function') {
    fail('malformed', `${field} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`);
  }
}

function parseTerm(data, id) {
  exactFields(data, TERM_FIELDS, 'CommitteeTerm');
  if (typeof data.name !== 'string' || data.name.length === 0) fail('malformed', 'CommitteeTerm name must be non-empty.');
  if (!Number.isInteger(data.start_year) || !Number.isInteger(data.end_year)) fail('malformed', 'CommitteeTerm years must be integers.');
  timestamp(data.start_date, 'start_date', true);
  timestamp(data.end_date, 'end_date', true);
  if (typeof data.active !== 'boolean') fail('malformed', 'CommitteeTerm active must be a boolean.');
  if (data.group_photo_url !== null && (typeof data.group_photo_url !== 'string' || !/^https:\/\/[^/]+.*$/.test(data.group_photo_url))) {
    fail('malformed', 'CommitteeTerm group_photo_url must be HTTPS or null.');
  }
  timestamp(data.created_at, 'created_at');
  if (typeof data.created_by !== 'string' || data.created_by.length === 0) fail('malformed', 'CommitteeTerm created_by must be non-empty.');
  return { id, ...data };
}

function parseAssignment(data, id) {
  exactFields(data, ASSIGNMENT_FIELDS, 'CommitteeAssignment');
  validateId(data.user_id, 'CommitteeAssignment user_id');
  validateId(data.term_id, 'CommitteeAssignment term_id');
  if (typeof data.position !== 'string' || !POSITION_PATTERN.test(data.position)) fail('malformed', 'CommitteeAssignment position is invalid machine text.');
  if (typeof data.active !== 'boolean') fail('malformed', 'CommitteeAssignment active must be a boolean.');
  timestamp(data.assigned_at, 'assigned_at');
  validateId(data.assigned_by, 'CommitteeAssignment assigned_by');
  timestamp(data.ended_at, 'ended_at', true);
  if ((data.active && data.ended_at !== null) || (!data.active && data.ended_at === null)) {
    fail('malformed', 'CommitteeAssignment active/ended_at state is inconsistent.');
  }
  return { id, ...data };
}

async function getAuthRecord(auth, uid) {
  try {
    return await auth.getUser(uid);
  } catch (_) {
    fail('auth_identity_missing', 'Operator Firebase Auth account does not exist.');
  }
}

async function resolveOperator(transaction, db, operatorUid, authRecord) {
  const linkSnapshot = await transaction.get(db.collection('auth_links').doc(operatorUid));
  const link = parseAuthLink(requireDocument(linkSnapshot, 'Operator auth link'), operatorUid);
  const userSnapshot = await transaction.get(db.collection('users').doc(link.user_id));
  const user = parseUser(requireDocument(userSnapshot, 'Operator User'), link.user_id);
  authorizeOperator({ authRecord, link, user });
  return user;
}

function validateCommonInput({ operatorUid, operationId, reason }) {
  validateId(operatorUid, 'operator UID');
  validateId(operationId, 'operation ID');
  return requireText(reason, 'reason');
}

function validateDirectoryIdentity(user, directory) {
  const expected = projectDirectory(user);
  if (directory.active !== true || Object.keys(expected).some((key) => directory[key] !== expected[key])) {
    fail('directory_mismatch', 'Target user_directory is inactive or does not match the authoritative User identity.');
  }
}

export async function assignCommitteePosition({
  db, auth, serverTimestamp, operatorUid, targetUserId, termId, position, operationId, reason,
}) {
  const normalizedReason = validateCommonInput({ operatorUid, operationId, reason });
  validateId(targetUserId, 'target User ID');
  validateId(termId, 'term ID');
  if (typeof position !== 'string' || !POSITION_PATTERN.test(position)) {
    fail('invalid_position', 'position must be lowercase machine text using letters, digits, and underscores.');
  }
  const operatorAuth = await getAuthRecord(auth, operatorUid);
  const assignmentReference = db.collection('committee_assignments').doc();
  const auditReference = db.collection('audit_logs').doc(operationId);

  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    const targetReference = db.collection('users').doc(targetUserId);
    const directoryReference = db.collection('user_directory').doc(targetUserId);
    const termReference = db.collection('committee_terms').doc(termId);
    const duplicateQuery = db.collection('committee_assignments')
      .where('user_id', '==', targetUserId)
      .where('term_id', '==', termId)
      .where('active', '==', true);
    const [targetSnapshot, directorySnapshot, termSnapshot, auditSnapshot, duplicates] = await Promise.all([
      transaction.get(targetReference),
      transaction.get(directoryReference),
      transaction.get(termReference),
      transaction.get(auditReference),
      transaction.get(duplicateQuery),
    ]);
    const target = parseUser(requireDocument(targetSnapshot, 'Target User'), targetUserId);
    if (!target.active) fail('target_inactive', 'Target User is inactive.');
    if (!RECOGNIZED_ROLES.has(target.access_role)) fail('malformed', 'Target User has an unknown access role.');
    if (target.access_role === 'developer_admin') fail('unauthorized_target', 'Committee assignment cannot target developer_admin.');
    const directory = parseDirectory(requireDocument(directorySnapshot, 'Target user_directory'), targetUserId);
    validateDirectoryIdentity(target, directory);
    const term = parseTerm(requireDocument(termSnapshot, 'Committee term'), termId);
    if (!term.active) fail('term_inactive', 'Committee term is inactive.');
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    if (!duplicates.empty) fail('duplicate_assignment', 'Target User already has an active assignment in this term.');

    const assignment = {
      user_id: targetUserId,
      term_id: termId,
      position,
      active: true,
      assigned_at: serverTimestamp(),
      assigned_by: operator.id,
      ended_at: null,
    };
    transaction.create(assignmentReference, assignment);
    transaction.create(auditReference, {
      action: 'committee.assign',
      actor_user_id: operator.id,
      actor_auth_uid: operatorUid,
      target_path: assignmentReference.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: {
        user_id: { after: targetUserId },
        term_id: { after: termId },
        position: { after: position },
        active: { after: true },
      },
      reason: normalizedReason,
    });
    return { action: 'committee-position-assigned', assignmentId: assignmentReference.id, operationId };
  });
}

export async function endCommitteeAssignment({
  db, auth, serverTimestamp, operatorUid, assignmentId, operationId, reason,
}) {
  const normalizedReason = validateCommonInput({ operatorUid, operationId, reason });
  validateId(assignmentId, 'assignment ID');
  const operatorAuth = await getAuthRecord(auth, operatorUid);
  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    const assignmentReference = db.collection('committee_assignments').doc(assignmentId);
    const assignmentSnapshot = await transaction.get(assignmentReference);
    const assignment = parseAssignment(requireDocument(assignmentSnapshot, 'Committee assignment'), assignmentId);
    if (!assignment.active) fail('already_ended', 'Committee assignment is already ended.');
    const termSnapshot = await transaction.get(db.collection('committee_terms').doc(assignment.term_id));
    parseTerm(requireDocument(termSnapshot, 'Parent committee term'), assignment.term_id);
    const auditSnapshot = await transaction.get(db.collection('audit_logs').doc(operationId));
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    const endedAt = serverTimestamp();
    transaction.update(assignmentReference, {
      active: false,
      ended_at: endedAt,
    });
    transaction.create(db.collection('audit_logs').doc(operationId), {
      action: 'committee.assignment_end',
      actor_user_id: operator.id,
      actor_auth_uid: operatorUid,
      target_path: assignmentReference.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: {
        active: { before: true, after: false },
        ended_at: { before: null, after: endedAt },
      },
      reason: normalizedReason,
    });
    return { action: 'committee-assignment-ended', assignmentId, operationId };
  });
}

export const committeeSchemaFields = { assignment: ASSIGNMENT_FIELDS };

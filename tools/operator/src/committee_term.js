import {
  AdmissionError,
  authorizeOperator,
  parseAuthLink,
  parseUser,
  validateId,
} from './policy.js';

const TERM_FIELDS = new Set([
  'name', 'start_year', 'end_year', 'start_date', 'end_date', 'active',
  'group_photo_url', 'created_at', 'created_by',
]);

function fail(code, message) {
  throw new AdmissionError(code, message);
}

function requireText(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0) fail('invalid_argument', `${label} is required.`);
  return value.trim();
}

function requireTimestamp(value, label, nullable = false) {
  if (nullable && value === null) return;
  if (!value || typeof value.toMillis !== 'function') fail('invalid_argument', `${label} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`);
}

function nullableHttps(value, label) {
  if (value === null) return null;
  if (typeof value !== 'string' || value.length === 0 || value.length > 2048 || !/^https:\/\/[^/]+.*$/.test(value)) {
    fail('invalid_argument', `${label} must be a valid HTTPS URL or null.`);
  }
  return value;
}

function requireDocument(snapshot, label) {
  if (!snapshot?.exists) fail('missing', `${label} does not exist.`);
  return snapshot.data();
}

function parseExistingTerm(data, id) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) fail('malformed', 'Current CommitteeTerm must be an object.');
  const keys = Object.keys(data);
  if (keys.length !== TERM_FIELDS.size || keys.some((key) => !TERM_FIELDS.has(key))) {
    fail('malformed', 'Current CommitteeTerm has missing or unapproved fields.');
  }
  requireText(data.name, 'Current CommitteeTerm name');
  if (!Number.isInteger(data.start_year) || !Number.isInteger(data.end_year) || data.start_year > data.end_year) {
    fail('malformed', 'Current CommitteeTerm years are invalid.');
  }
  requireTimestamp(data.start_date, 'Current CommitteeTerm start_date', true);
  requireTimestamp(data.end_date, 'Current CommitteeTerm end_date', true);
  if (data.active !== true) fail('malformed', 'Queried current CommitteeTerm must be active.');
  nullableHttps(data.group_photo_url, 'Current CommitteeTerm group_photo_url');
  requireTimestamp(data.created_at, 'Current CommitteeTerm created_at');
  validateId(data.created_by, 'Current CommitteeTerm created_by');
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

export async function rolloverCommitteeTerm({
  db, auth, serverTimestamp, operatorUid, currentTermId, name, startYear, endYear,
  startDate, endDate, groupPhotoUrl, operationId, reason,
}) {
  validateId(operatorUid, 'operator UID');
  validateId(operationId, 'operation ID');
  const normalizedReason = requireText(reason, 'reason');
  const normalizedName = requireText(name, 'term name');
  if (!Number.isInteger(startYear) || !Number.isInteger(endYear) || startYear > endYear) {
    fail('invalid_argument', 'Term years must be integers in ascending order.');
  }
  requireTimestamp(startDate, 'start date', true);
  requireTimestamp(endDate, 'end date', true);
  if (startDate !== null && endDate !== null && startDate.toMillis() > endDate.toMillis()) {
    fail('invalid_argument', 'Term dates must be in ascending order.');
  }
  const normalizedCover = nullableHttps(groupPhotoUrl, 'group photo URL');
  if (currentTermId !== null) validateId(currentTermId, 'current term ID');
  const operatorAuth = await getAuthRecord(auth, operatorUid);
  const newTermReference = db.collection('committee_terms').doc();
  const auditReference = db.collection('audit_logs').doc(operationId);
  const activeTermsQuery = db.collection('committee_terms').where('active', '==', true);

  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    const [activeTerms, newTermSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(activeTermsQuery),
      transaction.get(newTermReference),
      transaction.get(auditReference),
    ]);
    if (activeTerms.docs.length > 1) fail('ambiguous_current_term', 'Multiple active terms require separate trusted repair.');
    const current = activeTerms.docs[0] ?? null;
    if (current !== null) parseExistingTerm(current.data(), current.id);
    if (current === null && currentTermId !== null) fail('stale_current_term', 'No active current term exists.');
    if (current !== null && (currentTermId === null || current.id !== currentTermId)) {
      fail('stale_current_term', 'Explicit current term does not match the single active term.');
    }
    if (newTermSnapshot.exists) fail('id_collision', 'Generated successor term already exists.');
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');

    const newTerm = {
      name: normalizedName,
      start_year: startYear,
      end_year: endYear,
      start_date: startDate,
      end_date: endDate,
      active: true,
      group_photo_url: normalizedCover,
      created_at: serverTimestamp(),
      created_by: operator.id,
    };
    if (current !== null) transaction.update(db.collection('committee_terms').doc(current.id), { active: false });
    transaction.create(newTermReference, newTerm);
    transaction.create(auditReference, {
      action: 'committee.term_rollover',
      actor_user_id: operator.id,
      actor_auth_uid: operatorUid,
      target_path: newTermReference.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: {
        previous_term_id: { before: current?.id ?? null, active_after: current === null ? null : false },
        new_term_id: { after: newTermReference.id, active: true },
      },
      reason: normalizedReason,
    });
    return { action: 'committee-term-rolled-over', termId: newTermReference.id, operationId };
  });
}

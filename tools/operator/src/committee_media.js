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
const MEDIA_FIELDS = new Set([
  'term_id', 'image_url', 'caption', 'sort_order', 'active', 'uploaded_at',
  'uploaded_by', 'provider', 'provider_public_id',
]);

function fail(code, message) {
  throw new AdmissionError(code, message);
}

function requireText(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    fail('invalid_argument', `${label} is required.`);
  }
  return value.trim();
}

function optionalString(value, label, { nonEmpty = false } = {}) {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string' || (nonEmpty && value.length === 0)) {
    fail('invalid_argument', `${label} must be ${nonEmpty ? 'a non-empty string' : 'a string'} or null.`);
  }
  return value;
}

function httpsUrl(value, label, { nullable = false } = {}) {
  if (nullable && value === null) return null;
  if (typeof value !== 'string' || value.length === 0 || value.length > 2048 || !/^https:\/\/[^/]+.*$/.test(value)) {
    fail('invalid_url', `${label} must be a valid HTTPS URL${nullable ? ' or null' : ''}.`);
  }
  return value;
}

function requireDocument(snapshot, label) {
  if (!snapshot?.exists) fail('missing', `${label} does not exist.`);
  return snapshot.data();
}

function exactFields(value, fields, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail('malformed', `${label} must be an object.`);
  const keys = Object.keys(value);
  if (keys.length !== fields.size || keys.some((key) => !fields.has(key))) {
    fail('malformed', `${label} has missing or unapproved fields.`);
  }
}

function timestamp(value, field, nullable = false) {
  if (nullable && value === null) return;
  if (!value || typeof value.toMillis !== 'function') fail('malformed', `${field} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`);
}

function parseTerm(data, id) {
  exactFields(data, TERM_FIELDS, 'CommitteeTerm');
  requireText(data.name, 'CommitteeTerm name');
  if (!Number.isInteger(data.start_year) || !Number.isInteger(data.end_year)) fail('malformed', 'CommitteeTerm years must be integers.');
  timestamp(data.start_date, 'start_date', true);
  timestamp(data.end_date, 'end_date', true);
  if (typeof data.active !== 'boolean') fail('malformed', 'CommitteeTerm active must be a boolean.');
  httpsUrl(data.group_photo_url, 'group_photo_url', { nullable: true });
  timestamp(data.created_at, 'created_at');
  validateId(data.created_by, 'CommitteeTerm created_by');
  return { id, ...data };
}

function parseMedia(data, id) {
  exactFields(data, MEDIA_FIELDS, 'CommitteeMedia');
  validateId(data.term_id, 'CommitteeMedia term_id');
  httpsUrl(data.image_url, 'CommitteeMedia image_url');
  optionalString(data.caption, 'CommitteeMedia caption');
  if (!Number.isInteger(data.sort_order) || data.sort_order < 0) fail('malformed', 'CommitteeMedia sort_order must be a nonnegative integer.');
  if (typeof data.active !== 'boolean') fail('malformed', 'CommitteeMedia active must be a boolean.');
  timestamp(data.uploaded_at, 'uploaded_at');
  validateId(data.uploaded_by, 'CommitteeMedia uploaded_by');
  const provider = optionalString(data.provider, 'CommitteeMedia provider', { nonEmpty: true });
  const publicId = optionalString(data.provider_public_id, 'CommitteeMedia provider_public_id', { nonEmpty: true });
  if (publicId !== null && provider === null) fail('malformed', 'provider_public_id requires provider.');
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

function commonInput(operatorUid, operationId, reason) {
  validateId(operatorUid, 'operator UID');
  validateId(operationId, 'operation ID');
  return requireText(reason, 'reason');
}

function auditRecord({ action, operator, operatorUid, targetPath, operationId, reason, changes, serverTimestamp }) {
  return {
    action,
    actor_user_id: operator.id,
    actor_auth_uid: operatorUid,
    target_path: targetPath,
    occurred_at: serverTimestamp(),
    operation_id: operationId,
    outcome: 'committed',
    changes,
    reason,
  };
}

export async function addCommitteeMedia({
  db, auth, serverTimestamp, operatorUid, termId, imageUrl, caption,
  sortOrder, provider, providerPublicId, operationId, reason,
}) {
  const normalizedReason = commonInput(operatorUid, operationId, reason);
  validateId(termId, 'term ID');
  const normalizedUrl = httpsUrl(imageUrl, 'image URL');
  const normalizedCaption = optionalString(caption, 'caption');
  const normalizedProvider = optionalString(provider, 'provider', { nonEmpty: true });
  const normalizedPublicId = optionalString(providerPublicId, 'provider_public_id', { nonEmpty: true });
  if (normalizedPublicId !== null && normalizedProvider === null) fail('invalid_argument', 'provider_public_id requires provider.');
  if (!Number.isInteger(sortOrder) || sortOrder < 0) fail('invalid_argument', 'sort order must be a nonnegative integer.');
  const operatorAuth = await getAuthRecord(auth, operatorUid);
  const mediaReference = db.collection('committee_media').doc();
  const auditReference = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    const [termSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(db.collection('committee_terms').doc(termId)),
      transaction.get(auditReference),
    ]);
    parseTerm(requireDocument(termSnapshot, 'Committee term'), termId);
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    const media = {
      term_id: termId,
      image_url: normalizedUrl,
      caption: normalizedCaption,
      sort_order: sortOrder,
      active: true,
      uploaded_at: serverTimestamp(),
      uploaded_by: operator.id,
      provider: normalizedProvider,
      provider_public_id: normalizedPublicId,
    };
    transaction.create(mediaReference, media);
    transaction.create(auditReference, auditRecord({
      action: 'committee_media.add', operator, operatorUid,
      targetPath: mediaReference.path, operationId, reason: normalizedReason,
      changes: { term_id: { after: termId }, image_url: { after: normalizedUrl }, active: { after: true } },
      serverTimestamp,
    }));
    return { action: 'committee-media-added', mediaId: mediaReference.id, operationId };
  });
}

export async function deactivateCommitteeMedia({
  db, auth, serverTimestamp, operatorUid, mediaId, operationId, reason,
}) {
  const normalizedReason = commonInput(operatorUid, operationId, reason);
  validateId(mediaId, 'media ID');
  const operatorAuth = await getAuthRecord(auth, operatorUid);
  const mediaReference = db.collection('committee_media').doc(mediaId);
  const auditReference = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    const mediaSnapshot = await transaction.get(mediaReference);
    const media = parseMedia(requireDocument(mediaSnapshot, 'Committee media'), mediaId);
    if (!media.active) fail('already_inactive', 'Committee media is already inactive.');
    const [termSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(db.collection('committee_terms').doc(media.term_id)),
      transaction.get(auditReference),
    ]);
    parseTerm(requireDocument(termSnapshot, 'Parent committee term'), media.term_id);
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(mediaReference, { active: false });
    transaction.create(auditReference, auditRecord({
      action: 'committee_media.hide', operator, operatorUid,
      targetPath: mediaReference.path, operationId, reason: normalizedReason,
      changes: { active: { before: true, after: false } }, serverTimestamp,
    }));
    return { action: 'committee-media-deactivated', mediaId, operationId };
  });
}

async function editActiveCommitteeMedia({
  db, auth, serverTimestamp, operatorUid, mediaId, operationId, reason,
  action, field, value,
}) {
  const normalizedReason = commonInput(operatorUid, operationId, reason);
  validateId(mediaId, 'media ID');
  const operatorAuth = await getAuthRecord(auth, operatorUid);
  const mediaReference = db.collection('committee_media').doc(mediaId);
  const auditReference = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    const mediaSnapshot = await transaction.get(mediaReference);
    const media = parseMedia(requireDocument(mediaSnapshot, 'Committee media'), mediaId);
    if (!media.active) fail('media_inactive', 'Committee media is inactive.');
    const [termSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(db.collection('committee_terms').doc(media.term_id)),
      transaction.get(auditReference),
    ]);
    parseTerm(requireDocument(termSnapshot, 'Parent committee term'), media.term_id);
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(mediaReference, { [field]: value });
    transaction.create(auditReference, auditRecord({
      action, operator, operatorUid, targetPath: mediaReference.path,
      operationId, reason: normalizedReason,
      changes: { [field]: { before: media[field], after: value } },
      serverTimestamp,
    }));
    return { action, mediaId, operationId };
  });
}

export async function editCommitteeMediaCaption(dependencies) {
  return editActiveCommitteeMedia({
    ...dependencies,
    action: 'committee_media.edit_caption',
    field: 'caption',
    value: optionalString(dependencies.caption, 'caption'),
  });
}

export async function setCommitteeMediaOrder(dependencies) {
  if (!Number.isInteger(dependencies.sortOrder) || dependencies.sortOrder < 0) {
    fail('invalid_argument', 'sort order must be a nonnegative integer.');
  }
  return editActiveCommitteeMedia({
    ...dependencies,
    action: 'committee_media.set_order',
    field: 'sort_order',
    value: dependencies.sortOrder,
  });
}

export async function setCommitteeGroupPhoto({
  db, auth, serverTimestamp, operatorUid, termId, imageUrl, operationId, reason,
}) {
  const normalizedReason = commonInput(operatorUid, operationId, reason);
  validateId(termId, 'term ID');
  const normalizedUrl = httpsUrl(imageUrl, 'group photo URL', { nullable: true });
  const operatorAuth = await getAuthRecord(auth, operatorUid);
  const termReference = db.collection('committee_terms').doc(termId);
  const auditReference = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    const [termSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(termReference), transaction.get(auditReference),
    ]);
    const term = parseTerm(requireDocument(termSnapshot, 'Committee term'), termId);
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(termReference, { group_photo_url: normalizedUrl });
    transaction.create(auditReference, auditRecord({
      action: 'committee.group_photo_update', operator, operatorUid,
      targetPath: termReference.path, operationId, reason: normalizedReason,
      changes: { group_photo_url: { before: term.group_photo_url, after: normalizedUrl } },
      serverTimestamp,
    }));
    return { action: 'committee-group-photo-set', termId, operationId };
  });
}

export const committeeMediaSchemaFields = MEDIA_FIELDS;

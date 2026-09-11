import {
  AdmissionError,
  authorizeOperator,
  parseAuthLink,
  parseUser,
  validateId,
} from './policy.js';

const EVENT_FIELDS = new Set([
  'title', 'description', 'event_type', 'event_date', 'location',
  'cover_image_url', 'active', 'created_at', 'created_by', 'updated_at',
  'updated_by',
]);
const MEDIA_FIELDS = new Set([
  'event_id', 'image_url', 'caption', 'sort_order', 'active', 'uploaded_at',
  'uploaded_by', 'provider', 'provider_public_id',
]);
const EVENT_TYPES = new Set([
  'meeting', 'blood_donation_campaign', 'awareness_program',
  'social_activity', 'celebration', 'emergency_activity', 'other',
]);

function fail(code, message) { throw new AdmissionError(code, message); }
function requiredText(value, label, max) {
  if (typeof value !== 'string' || value.trim().length === 0 || value.trim().length > max) {
    fail('invalid_argument', `${label} must be a non-empty string of at most ${max} characters.`);
  }
  return value.trim();
}
function nullableText(value, label, max) {
  if (value === undefined || value === null) return null;
  return requiredText(value, label, max);
}
function httpsUrl(value, label, nullable = false) {
  if (nullable && (value === undefined || value === null)) return null;
  if (typeof value !== 'string' || value.length === 0 || value.length > 2048 || !/^https:\/\/[^/]+/.test(value)) {
    fail('invalid_url', `${label} must be an HTTPS URL${nullable ? ' or null' : ''}.`);
  }
  return value;
}
function timestamp(value, label, nullable = false) {
  if (nullable && value === null) return;
  if (!value || typeof value.toMillis !== 'function') fail('malformed', `${label} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`);
}
function exact(value, fields, label) {
  const keys = value && typeof value === 'object' && !Array.isArray(value) ? Object.keys(value) : [];
  if (keys.length !== fields.size || keys.some((key) => !fields.has(key))) fail('malformed', `${label} has missing or unapproved fields.`);
}
function document(snapshot, label) {
  if (!snapshot?.exists) fail('missing', `${label} does not exist.`);
  return snapshot.data();
}
function parseEvent(data, id) {
  exact(data, EVENT_FIELDS, 'Event');
  validateId(id, 'event ID');
  requiredText(data.title, 'title', 200);
  nullableText(data.description, 'description', 5000);
  if (!EVENT_TYPES.has(data.event_type)) fail('malformed', 'Event type is unknown.');
  timestamp(data.event_date, 'event_date');
  nullableText(data.location, 'location', 300);
  httpsUrl(data.cover_image_url, 'cover_image_url', true);
  if (typeof data.active !== 'boolean') fail('malformed', 'Event active must be boolean.');
  timestamp(data.created_at, 'created_at');
  validateId(data.created_by, 'created_by');
  timestamp(data.updated_at, 'updated_at', true);
  if (data.updated_by !== null) validateId(data.updated_by, 'updated_by');
  if ((data.updated_at === null) !== (data.updated_by === null)) fail('malformed', 'Event update metadata is inconsistent.');
  return { id, ...data };
}
function parseMedia(data, id) {
  exact(data, MEDIA_FIELDS, 'EventMedia');
  validateId(id, 'media ID');
  validateId(data.event_id, 'event_id');
  httpsUrl(data.image_url, 'image_url');
  nullableText(data.caption, 'caption', 200);
  if (!Number.isInteger(data.sort_order) || data.sort_order < 0) fail('malformed', 'sort_order must be nonnegative.');
  if (typeof data.active !== 'boolean') fail('malformed', 'Media active must be boolean.');
  timestamp(data.uploaded_at, 'uploaded_at');
  validateId(data.uploaded_by, 'uploaded_by');
  const provider = nullableText(data.provider, 'provider', 200);
  const publicId = nullableText(data.provider_public_id, 'provider_public_id', 512);
  if (publicId !== null && provider === null) fail('malformed', 'provider_public_id requires provider.');
  return { id, ...data };
}
async function authRecord(auth, uid) {
  try { return await auth.getUser(uid); } catch (_) { fail('auth_identity_missing', 'Operator Auth account does not exist.'); }
}
async function operator(transaction, db, uid, record) {
  const link = parseAuthLink(document(await transaction.get(db.collection('auth_links').doc(uid)), 'Operator auth link'), uid);
  const user = parseUser(document(await transaction.get(db.collection('users').doc(link.user_id)), 'Operator User'), link.user_id);
  authorizeOperator({ authRecord: record, link, user });
  return user;
}
function common(operatorUid, operationId, reason) {
  validateId(operatorUid, 'operator UID');
  validateId(operationId, 'operation ID');
  return requiredText(reason, 'reason', 2000);
}
function audit({ action, actor, operatorUid, path, operationId, reason, changes, serverTimestamp }) {
  return { action, actor_user_id: actor.id, actor_auth_uid: operatorUid, target_path: path, occurred_at: serverTimestamp(), operation_id: operationId, outcome: 'committed', changes, reason };
}

export async function createEvent({ db, auth, serverTimestamp, operatorUid, title, description, eventType, eventDate, location, coverImageUrl, operationId, reason }) {
  const why = common(operatorUid, operationId, reason);
  const normalized = {
    title: requiredText(title, 'title', 200),
    description: nullableText(description, 'description', 5000),
    event_type: requiredText(eventType, 'event_type', 100),
    event_date: eventDate,
    location: nullableText(location, 'location', 300),
    cover_image_url: httpsUrl(coverImageUrl, 'cover_image_url', true),
  };
  if (!EVENT_TYPES.has(normalized.event_type)) fail('invalid_argument', 'event_type is unknown.');
  timestamp(eventDate, 'event_date');
  const record = await authRecord(auth, operatorUid);
  const ref = db.collection('events').doc();
  const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await operator(transaction, db, operatorUid, record);
    if ((await transaction.get(auditRef)).exists) fail('operation_reused', 'Operation ID has already been used.');
    const value = { ...normalized, active: true, created_at: serverTimestamp(), created_by: actor.id, updated_at: null, updated_by: null };
    transaction.create(ref, value);
    transaction.create(auditRef, audit({ action: 'event.create', actor, operatorUid, path: ref.path, operationId, reason: why, changes: { title: { after: normalized.title }, active: { after: true } }, serverTimestamp }));
    return { action: 'event-created', eventId: ref.id, operationId };
  });
}

async function editEvent({ db, auth, serverTimestamp, operatorUid, eventId, operationId, reason, action, changes }) {
  const why = common(operatorUid, operationId, reason);
  validateId(eventId, 'event ID');
  const record = await authRecord(auth, operatorUid);
  const ref = db.collection('events').doc(eventId);
  const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await operator(transaction, db, operatorUid, record);
    const current = parseEvent(document(await transaction.get(ref), 'Event'), eventId);
    if (!current.active) fail('event_inactive', 'Event is inactive.');
    if ((await transaction.get(auditRef)).exists) fail('operation_reused', 'Operation ID has already been used.');
    const beforeAfter = Object.fromEntries(Object.entries(changes).map(([key, value]) => [key, { before: current[key], after: value }]));
    transaction.update(ref, { ...changes, updated_at: serverTimestamp(), updated_by: actor.id });
    transaction.create(auditRef, audit({ action, actor, operatorUid, path: ref.path, operationId, reason: why, changes: beforeAfter, serverTimestamp }));
    return { action, eventId, operationId };
  });
}

export function updateEvent(dependencies) {
  const changes = {};
  if (dependencies.title !== undefined) changes.title = requiredText(dependencies.title, 'title', 200);
  if (dependencies.description !== undefined) changes.description = nullableText(dependencies.description, 'description', 5000);
  if (dependencies.eventType !== undefined) {
    changes.event_type = requiredText(dependencies.eventType, 'event_type', 100);
    if (!EVENT_TYPES.has(changes.event_type)) fail('invalid_argument', 'event_type is unknown.');
  }
  if (dependencies.eventDate !== undefined) { timestamp(dependencies.eventDate, 'event_date'); changes.event_date = dependencies.eventDate; }
  if (dependencies.location !== undefined) changes.location = nullableText(dependencies.location, 'location', 300);
  if (Object.keys(changes).length === 0) fail('invalid_argument', 'At least one editable event field is required.');
  return editEvent({ ...dependencies, action: 'event.edit', changes });
}
export function setEventCover(dependencies) {
  return editEvent({ ...dependencies, action: 'event.set_cover', changes: { cover_image_url: httpsUrl(dependencies.coverImageUrl, 'cover_image_url', true) } });
}
export async function hideEvent(dependencies) {
  return editEvent({ ...dependencies, action: 'event.hide', changes: { active: false } });
}

export async function addEventMedia({ db, auth, serverTimestamp, operatorUid, eventId, imageUrl, caption, sortOrder, provider, providerPublicId, operationId, reason }) {
  const why = common(operatorUid, operationId, reason);
  validateId(eventId, 'event ID');
  const normalizedProvider = nullableText(provider, 'provider', 200);
  const normalizedPublicId = nullableText(providerPublicId, 'provider_public_id', 512);
  if (normalizedPublicId !== null && normalizedProvider === null) fail('invalid_argument', 'provider_public_id requires provider.');
  if (!Number.isInteger(sortOrder) || sortOrder < 0) fail('invalid_argument', 'sort_order must be nonnegative.');
  const record = await authRecord(auth, operatorUid);
  const ref = db.collection('event_media').doc();
  const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await operator(transaction, db, operatorUid, record);
    const parent = parseEvent(document(await transaction.get(db.collection('events').doc(eventId)), 'Parent event'), eventId);
    if (!parent.active) fail('event_inactive', 'Parent event is inactive.');
    if ((await transaction.get(auditRef)).exists) fail('operation_reused', 'Operation ID has already been used.');
    const value = { event_id: eventId, image_url: httpsUrl(imageUrl, 'image_url'), caption: nullableText(caption, 'caption', 200), sort_order: sortOrder, active: true, uploaded_at: serverTimestamp(), uploaded_by: actor.id, provider: normalizedProvider, provider_public_id: normalizedPublicId };
    transaction.create(ref, value);
    transaction.create(auditRef, audit({ action: 'event_media.add', actor, operatorUid, path: ref.path, operationId, reason: why, changes: { event_id: { after: eventId }, active: { after: true } }, serverTimestamp }));
    return { action: 'event-media-added', mediaId: ref.id, operationId };
  });
}

async function editMedia({ db, auth, serverTimestamp, operatorUid, mediaId, operationId, reason, action, field, value }) {
  const why = common(operatorUid, operationId, reason);
  validateId(mediaId, 'media ID');
  const record = await authRecord(auth, operatorUid);
  const ref = db.collection('event_media').doc(mediaId);
  const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await operator(transaction, db, operatorUid, record);
    const current = parseMedia(document(await transaction.get(ref), 'Event media'), mediaId);
    if (!current.active) fail('media_inactive', 'Event media is inactive.');
    const parent = parseEvent(document(await transaction.get(db.collection('events').doc(current.event_id)), 'Parent event'), current.event_id);
    if (!parent.active) fail('event_inactive', 'Parent event is inactive.');
    if ((await transaction.get(auditRef)).exists) fail('operation_reused', 'Operation ID has already been used.');
    transaction.update(ref, { [field]: value });
    transaction.create(auditRef, audit({ action, actor, operatorUid, path: ref.path, operationId, reason: why, changes: { [field]: { before: current[field], after: value } }, serverTimestamp }));
    return { action, mediaId, operationId };
  });
}
export function editEventMediaCaption(dependencies) {
  return editMedia({ ...dependencies, action: 'event_media.edit_caption', field: 'caption', value: nullableText(dependencies.caption, 'caption', 200) });
}
export function setEventMediaOrder(dependencies) {
  if (!Number.isInteger(dependencies.sortOrder) || dependencies.sortOrder < 0) fail('invalid_argument', 'sort_order must be nonnegative.');
  return editMedia({ ...dependencies, action: 'event_media.set_order', field: 'sort_order', value: dependencies.sortOrder });
}
export function hideEventMedia(dependencies) {
  return editMedia({ ...dependencies, action: 'event_media.hide', field: 'active', value: false });
}

export const eventSchemaFields = { event: EVENT_FIELDS, media: MEDIA_FIELDS };

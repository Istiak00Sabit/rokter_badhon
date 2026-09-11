import {
  AdmissionError,
  authorizeOperatorForRoles,
  parseAuthLink,
  parseUser,
  validateId,
} from './policy.js';
import { parseDonor } from './donor.js';

const DONATION_FIELDS = new Set([
  'donor_id', 'donor_name_snapshot', 'blood_group_snapshot', 'donation_date',
  'location', 'hospital', 'recipient_name', 'recipient_contact', 'recorded_by',
  'created_at', 'updated_at',
]);

function fail(code, message) { throw new AdmissionError(code, message); }
function document(snapshot, label) {
  if (!snapshot?.exists) fail('missing', `${label} does not exist.`);
  return snapshot.data();
}
function text(value, label, max, nullable = false) {
  if (nullable && (value === undefined || value === null)) return null;
  if (typeof value !== 'string' || value.trim().length === 0 || value.trim().length > max) {
    fail('invalid_argument', `${label} must be a non-empty bounded string${nullable ? ' or null' : ''}.`);
  }
  return value.trim();
}
function timestamp(value, label, nullable = false) {
  if (nullable && value === null) return;
  if (!value || typeof value.toMillis !== 'function') fail('malformed', `${label} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`);
}
function parseDonation(data, id) {
  const keys = data && typeof data === 'object' && !Array.isArray(data) ? Object.keys(data) : [];
  if (keys.length !== DONATION_FIELDS.size || keys.some((key) => !DONATION_FIELDS.has(key))) fail('malformed', 'Donation has missing or unapproved fields.');
  validateId(id, 'donation ID');
  validateId(data.donor_id, 'donor_id');
  text(data.donor_name_snapshot, 'donor_name_snapshot', 200);
  text(data.blood_group_snapshot, 'blood_group_snapshot', 10);
  timestamp(data.donation_date, 'donation_date');
  text(data.location, 'location', 300, true);
  text(data.hospital, 'hospital', 300, true);
  text(data.recipient_name, 'recipient_name', 200, true);
  text(data.recipient_contact, 'recipient_contact', 100, true);
  validateId(data.recorded_by, 'recorded_by');
  timestamp(data.created_at, 'created_at');
  timestamp(data.updated_at, 'updated_at', true);
  return { id, ...data };
}
async function authRecord(auth, uid) {
  try { return await auth.getUser(uid); } catch (_) { fail('auth_identity_missing', 'Operator Auth account does not exist.'); }
}
async function resolve(transaction, db, uid, record, allowedRoles) {
  const link = parseAuthLink(document(await transaction.get(db.collection('auth_links').doc(uid)), 'Operator auth link'), uid);
  const user = parseUser(document(await transaction.get(db.collection('users').doc(link.user_id)), 'Operator User'), link.user_id);
  authorizeOperatorForRoles({ authRecord: record, link, user, allowedRoles });
  return user;
}
function common(operatorUid, operationId, reason) {
  validateId(operatorUid, 'operator UID');
  validateId(operationId, 'operation ID');
  return text(reason, 'reason', 2000);
}
function sameTimestamp(left, right) { return left.toMillis() === right.toMillis(); }

export async function recordDonation({ db, auth, serverTimestamp, operatorUid, donorId, donationDate, location, hospital, recipientName, recipientContact, operationId, reason }) {
  const why = common(operatorUid, operationId, reason);
  validateId(donorId, 'donor ID');
  timestamp(donationDate, 'donation_date');
  const input = {
    location: text(location, 'location', 300, true),
    hospital: text(hospital, 'hospital', 300, true),
    recipient_name: text(recipientName, 'recipient_name', 200, true),
    recipient_contact: text(recipientContact, 'recipient_contact', 100, true),
  };
  const record = await authRecord(auth, operatorUid);
  const donationRef = db.collection('donations').doc(operationId);
  const donorRef = db.collection('donors').doc(donorId);
  const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record, ['developer_admin', 'leader', 'executive', 'committee']);
    const [donorSnapshot, existingSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(donorRef), transaction.get(donationRef), transaction.get(auditRef),
    ]);
    const donor = parseDonor(document(donorSnapshot, 'Donor'), donorId);
    if (existingSnapshot.exists) {
      const existing = parseDonation(existingSnapshot.data(), operationId);
      const exactRetry = existing.donor_id === donorId && existing.recorded_by === actor.id && sameTimestamp(existing.donation_date, donationDate) && existing.location === input.location && existing.hospital === input.hospital && existing.recipient_name === input.recipient_name && existing.recipient_contact === input.recipient_contact;
      if (!exactRetry || !auditSnapshot.exists) fail('operation_reused', 'Operation ID is already bound to a different or incomplete operation.');
      return { action: 'donation-already-recorded', donationId: operationId, operationId };
    }
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    if (!donor.active) fail('donor_inactive', 'Donation recording requires an active donor.');
    const createdAt = serverTimestamp();
    transaction.create(donationRef, {
      donor_id: donorId,
      donor_name_snapshot: donor.name,
      blood_group_snapshot: donor.blood_group,
      donation_date: donationDate,
      ...input,
      recorded_by: actor.id,
      created_at: createdAt,
      updated_at: null,
    });
    const last = donor.last_donated_at === null || donationDate.toMillis() > donor.last_donated_at.toMillis() ? donationDate : donor.last_donated_at;
    transaction.update(donorRef, {
      total_donations: donor.total_donations + 1,
      last_donated_at: last,
      updated_at: serverTimestamp(),
      updated_by: actor.id,
    });
    transaction.create(auditRef, {
      action: 'donation.record', actor_user_id: actor.id, actor_auth_uid: operatorUid,
      target_path: donationRef.path, occurred_at: serverTimestamp(), operation_id: operationId,
      outcome: 'committed', changes: { donor_id: { after: donorId } },
      reason: why,
    });
    return { action: 'donation-recorded', donationId: operationId, operationId };
  });
}

export async function correctDonation({ db, auth, serverTimestamp, operatorUid, donationId, donationDate, location, hospital, recipientName, recipientContact, operationId, reason }) {
  const why = common(operatorUid, operationId, reason);
  validateId(donationId, 'donation ID');
  const record = await authRecord(auth, operatorUid);
  const donationRef = db.collection('donations').doc(donationId);
  const auditRef = db.collection('audit_logs').doc(operationId);
  return db.runTransaction(async (transaction) => {
    const actor = await resolve(transaction, db, operatorUid, record, ['developer_admin', 'leader']);
    const current = parseDonation(document(await transaction.get(donationRef), 'Donation'), donationId);
    const donorRef = db.collection('donors').doc(current.donor_id);
    const [donorSnapshot, auditSnapshot, history] = await Promise.all([
      transaction.get(donorRef), transaction.get(auditRef),
      transaction.get(db.collection('donations').where('donor_id', '==', current.donor_id)),
    ]);
    const donor = parseDonor(document(donorSnapshot, 'Referenced donor'), current.donor_id);
    if (auditSnapshot.exists) fail('operation_reused', 'Operation ID has already been used.');
    const changes = {};
    if (donationDate !== undefined) { timestamp(donationDate, 'donation_date'); changes.donation_date = donationDate; }
    if (location !== undefined) changes.location = text(location, 'location', 300, true);
    if (hospital !== undefined) changes.hospital = text(hospital, 'hospital', 300, true);
    if (recipientName !== undefined) changes.recipient_name = text(recipientName, 'recipient_name', 200, true);
    if (recipientContact !== undefined) changes.recipient_contact = text(recipientContact, 'recipient_contact', 100, true);
    if (Object.keys(changes).length === 0) fail('invalid_argument', 'At least one correction field is required.');
    let last = donor.last_donated_at;
    if (changes.donation_date !== undefined) {
      const parsed = history.docs.map((doc) => parseDonation(doc.data(), doc.id));
      last = parsed.reduce((latest, item) => {
        const date = item.id === donationId ? changes.donation_date : item.donation_date;
        return latest === null || date.toMillis() > latest.toMillis() ? date : latest;
      }, null);
    }
    const updatedAt = serverTimestamp();
    transaction.update(donationRef, { ...changes, updated_at: updatedAt });
    transaction.update(donorRef, { last_donated_at: last, updated_at: updatedAt, updated_by: actor.id });
    transaction.create(auditRef, {
      action: 'donation.correct', actor_user_id: actor.id, actor_auth_uid: operatorUid,
      target_path: donationRef.path, occurred_at: serverTimestamp(), operation_id: operationId,
      outcome: 'committed', changes: Object.fromEntries(Object.entries(changes).map(([key, value]) => [key, { before: current[key], after: value }])), reason: why,
    });
    return { action: 'donation-corrected', donationId, operationId };
  });
}

export const donationSchemaFields = DONATION_FIELDS;

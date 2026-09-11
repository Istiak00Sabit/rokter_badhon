import assert from 'node:assert/strict';
import test from 'node:test';

import { correctDonation, donationSchemaFields, recordDonation } from '../src/donation.js';
import { adminUser, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const UID = 'operator-uid';
const USER = 'operator-user';
const DONOR = 'donor-1';
const DATE_1 = { toMillis: () => 100 };
const DATE_2 = { toMillis: () => 200 };
const DATE_3 = { toMillis: () => 300 };

const donor = (changes = {}) => ({
  name: 'Donor One', phone: '01000000000', blood_group: 'A+', gender: null,
  photo_url: null, village: null, union: null, upazila: 'Ghatail', district: 'Tangail',
  profession: null, linked_user_id: null, active: true, last_donated_at: null,
  total_donations: 0, created_at: TIME, created_by: USER, updated_at: TIME,
  updated_by: USER, ...changes,
});
const donation = (changes = {}) => ({
  donor_id: DONOR, donor_name_snapshot: 'Donor One', blood_group_snapshot: 'A+',
  donation_date: DATE_2, location: 'Ghatail', hospital: null, recipient_name: null,
  recipient_contact: null, recorded_by: USER, created_at: TIME, updated_at: null,
  ...changes,
});
function fixture({ role = 'developer_admin', donorValue = donor(), entries = [] } = {}) {
  return {
    db: new FakeFirestore([
      ['auth_links/operator-uid', { user_id: USER, active: true, created_at: TIME, created_by: 'seed' }],
      [`users/${USER}`, adminUser({ access_role: role })],
      [`donors/${DONOR}`, donorValue], ...entries,
    ]),
    auth: new FakeAuth([[UID, { uid: UID, email: 'operator@example.test', emailVerified: true, disabled: false }]]),
  };
}
const common = (base, operationId) => ({ ...base, serverTimestamp: () => SERVER_TIME, operatorUid: UID, operationId, reason: 'Verified donation operation.' });
const recordArgs = (base, operationId = 'donation-record-1') => ({ ...common(base, operationId), donorId: DONOR, donationDate: DATE_2, location: 'Ghatail', hospital: null, recipientName: null, recipientContact: null });
async function code(promise, expected) { await assert.rejects(promise, (error) => error.code === expected); }

test('all four recording roles create exact event and increment aggregates once', async () => {
  for (const role of ['developer_admin', 'leader', 'executive', 'committee']) {
    const base = fixture({ role });
    const result = await recordDonation(recordArgs(base, `record-${role}`));
    const value = base.db.documents.get(`donations/${result.donationId}`);
    assert.deepEqual(new Set(Object.keys(value)), donationSchemaFields);
    assert.equal(value.donor_name_snapshot, 'Donor One');
    assert.equal(value.blood_group_snapshot, 'A+');
    assert.equal(value.recorded_by, USER);
    assert.equal(base.db.documents.get(`donors/${DONOR}`).total_donations, 1);
    assert.equal(base.db.documents.get(`donors/${DONOR}`).last_donated_at, DATE_2);
  }
});

test('exact retry returns receipt without a second aggregate change', async () => {
  const base = fixture();
  await recordDonation(recordArgs(base));
  const retry = await recordDonation(recordArgs(base));
  assert.equal(retry.action, 'donation-already-recorded');
  assert.equal(base.db.documents.get(`donors/${DONOR}`).total_donations, 1);
  assert.equal([...base.db.documents.keys()].filter((path) => path.startsWith('donations/')).length, 1);
});

test('member, inactive donor, malformed donor and conflicting retry fail atomically', async () => {
  await code(recordDonation(recordArgs(fixture({ role: 'member' }))), 'unauthorized');
  await code(recordDonation(recordArgs(fixture({ donorValue: donor({ active: false }) }))), 'donor_inactive');
  await code(recordDonation(recordArgs(fixture({ donorValue: { ...donor(), legacy: true } }))), 'malformed');
  const conflict = fixture({ entries: [['donations/donation-record-1', donation({ location: 'Other' })]] });
  await code(recordDonation(recordArgs(conflict)), 'operation_reused');
  assert.equal(conflict.db.documents.get(`donors/${DONOR}`).total_donations, 0);
});

test('recording derives snapshots and preserves later aggregate when date is older', async () => {
  const base = fixture({ donorValue: donor({ name: 'Authoritative', blood_group: 'O-', total_donations: 5, last_donated_at: DATE_3 }) });
  const result = await recordDonation(recordArgs(base));
  const value = base.db.documents.get(`donations/${result.donationId}`);
  assert.equal(value.donor_name_snapshot, 'Authoritative');
  assert.equal(value.blood_group_snapshot, 'O-');
  assert.equal(base.db.documents.get(`donors/${DONOR}`).total_donations, 6);
  assert.equal(base.db.documents.get(`donors/${DONOR}`).last_donated_at, DATE_3);
});

test('DA and leader correct allowed fields, preserve provenance/count, and recompute latest date', async () => {
  for (const role of ['developer_admin', 'leader']) {
    const base = fixture({ role, donorValue: donor({ total_donations: 2, last_donated_at: DATE_3 }), entries: [
      ['donations/event-1', donation({ donation_date: DATE_3 })],
      ['donations/event-2', donation({ donation_date: DATE_1 })],
    ] });
    const original = { ...base.db.documents.get('donations/event-1') };
    await correctDonation({ ...common(base, `correct-${role}`), donationId: 'event-1', donationDate: DATE_2, location: 'Corrected' });
    const value = base.db.documents.get('donations/event-1');
    assert.equal(value.donor_id, original.donor_id);
    assert.equal(value.recorded_by, original.recorded_by);
    assert.equal(value.created_at, original.created_at);
    assert.equal(value.location, 'Corrected');
    assert.equal(base.db.documents.get(`donors/${DONOR}`).total_donations, 2);
    assert.equal(base.db.documents.get(`donors/${DONOR}`).last_donated_at, DATE_2);
    assert.equal(base.db.documents.get(`audit_logs/correct-${role}`).action, 'donation.correct');
  }
});

test('correction denies lower roles, reused operations, no-op and malformed history', async () => {
  const entries = [['donations/event-1', donation()]];
  await code(correctDonation({ ...common(fixture({ role: 'executive', entries }), 'c-1'), donationId: 'event-1', location: 'No' }), 'unauthorized');
  const reused = fixture({ entries: [...entries, ['audit_logs/c-2', { action: 'old' }]] });
  await code(correctDonation({ ...common(reused, 'c-2'), donationId: 'event-1', location: 'No' }), 'operation_reused');
  await code(correctDonation({ ...common(fixture({ entries }), 'c-3'), donationId: 'event-1' }), 'invalid_argument');
  const malformed = fixture({ entries: [...entries, ['donations/event-2', { ...donation(), old: true }]] });
  await code(correctDonation({ ...common(malformed, 'c-4'), donationId: 'event-1', donationDate: DATE_1 }), 'malformed');
  assert.equal(malformed.db.documents.has('audit_logs/c-4'), false);
});

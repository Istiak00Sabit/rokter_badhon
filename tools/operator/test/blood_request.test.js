import assert from 'node:assert/strict';
import test from 'node:test';

import { bloodRequestSchemaFields, cancelBloodRequest, editBloodRequest, fulfillBloodRequest } from '../src/blood_request.js';
import { adminUser, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const UID = 'operator-uid'; const USER = 'operator-user'; const REQUEST = 'request-1';
const request = (changes = {}) => ({ blood_group: 'A+', patient_name: null, hospital: 'Hospital', location: 'Ghatail', contact_name: 'Contact', contact_phone: '01000000000', required_at: null, status: 'active', created_by: 'creator-user', created_at: TIME, fulfilled_by: null, fulfilled_at: null, ...changes });
function fixture({ role = 'developer_admin', value = request(), entries = [] } = {}) {
  return { db: new FakeFirestore([
    ['auth_links/operator-uid', { user_id: USER, active: true, created_at: TIME, created_by: 'seed' }],
    [`users/${USER}`, adminUser({ access_role: role })], [`blood_requests/${REQUEST}`, value], ...entries,
  ]), auth: new FakeAuth([[UID, { uid: UID, email: 'operator@example.test', emailVerified: true, disabled: false }]]) };
}
const common = (base, operationId) => ({ ...base, serverTimestamp: () => SERVER_TIME, operatorUid: UID, requestId: REQUEST, operationId, reason: 'Reviewed request operation.' });
async function code(promise, expected) { await assert.rejects(promise, (error) => error.code === expected); }

test('request schema is exact and all four operational roles can edit active input only', async () => {
  assert.equal(bloodRequestSchemaFields.size, 12);
  for (const role of ['developer_admin', 'leader', 'executive', 'committee']) {
    const base = fixture({ role });
    const before = { ...base.db.documents.get(`blood_requests/${REQUEST}`) };
    await editBloodRequest({ ...common(base, `edit-${role}`), location: 'New location' });
    assert.deepEqual(base.db.documents.get(`blood_requests/${REQUEST}`), { ...before, location: 'New location' });
    assert.equal(base.db.documents.get(`audit_logs/edit-${role}`).action, 'blood_request.edit');
  }
});

test('member, terminal, malformed and reused-operation edits fail atomically', async () => {
  await code(editBloodRequest({ ...common(fixture({ role: 'member' }), 'e-1'), location: 'No' }), 'unauthorized');
  await code(editBloodRequest({ ...common(fixture({ value: request({ status: 'cancelled' }) }), 'e-2'), location: 'No' }), 'request_terminal');
  await code(editBloodRequest({ ...common(fixture({ value: { ...request(), legacy: true } }), 'e-3'), location: 'No' }), 'malformed');
  const reused = fixture({ entries: [['audit_logs/e-4', { action: 'old' }]] });
  await code(editBloodRequest({ ...common(reused, 'e-4'), location: 'No' }), 'operation_reused');
  assert.equal(reused.db.documents.get(`blood_requests/${REQUEST}`).location, 'Ghatail');
});

test('fulfill derives actor/time and exact retry has no duplicate audit', async () => {
  const base = fixture({ role: 'executive' });
  await fulfillBloodRequest(common(base, 'fulfill-1'));
  const value = base.db.documents.get(`blood_requests/${REQUEST}`);
  assert.equal(value.status, 'fulfilled'); assert.equal(value.fulfilled_by, USER); assert.equal(value.fulfilled_at, SERVER_TIME);
  const retry = await fulfillBloodRequest(common(base, 'fulfill-1'));
  assert.equal(retry.action, 'blood-request-already-fulfilled');
  assert.equal([...base.db.documents.keys()].filter((path) => path === 'audit_logs/fulfill-1').length, 1);
});

test('cancel is one-way, retains null fulfillment metadata, and exact retry is safe', async () => {
  const base = fixture({ role: 'committee' });
  await cancelBloodRequest(common(base, 'cancel-1'));
  assert.deepEqual(base.db.documents.get(`blood_requests/${REQUEST}`), { ...request(), status: 'cancelled' });
  assert.equal((await cancelBloodRequest(common(base, 'cancel-1'))).action, 'blood-request-already-cancelled');
  await code(fulfillBloodRequest(common(base, 'fulfill-after-cancel')), 'request_terminal');
});

test('terminal transitions reject member, malformed metadata, and unrelated operation reuse', async () => {
  await code(fulfillBloodRequest(common(fixture({ role: 'member' }), 't-1')), 'unauthorized');
  await code(cancelBloodRequest(common(fixture({ value: request({ fulfilled_by: USER }) }), 't-2')), 'malformed');
  const reused = fixture({ entries: [['audit_logs/t-3', { action: 'event.create', target_path: `blood_requests/${REQUEST}`, actor_user_id: USER }]] });
  await code(cancelBloodRequest(common(reused, 't-3')), 'operation_reused');
});

test('creation remains absent from trusted operator because exact client Rules grant it', () => {
  const source = String.raw`${editBloodRequest}${fulfillBloodRequest}${cancelBloodRequest}`;
  assert.equal(source.includes("collection('blood_requests').doc()"), false);
});

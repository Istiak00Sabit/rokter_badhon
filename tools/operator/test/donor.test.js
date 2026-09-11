import assert from 'node:assert/strict';
import test from 'node:test';

import { deactivateDonor, donorSchemaFields } from '../src/donor.js';
import { adminUser, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const donor = (changes = {}) => ({
  name: 'Synthetic Donor', phone: '01000000000', blood_group: 'A+', gender: null,
  photo_url: null, village: null, union: null, upazila: 'Ghatail', district: 'Tangail',
  profession: null, linked_user_id: null, active: true, last_donated_at: null,
  total_donations: 0, created_at: TIME, created_by: 'creator-id', updated_at: TIME,
  updated_by: 'creator-id', ...changes,
});

function args(role = 'developer_admin', donorChanges = {}, entries = []) {
  return {
    db: new FakeFirestore([
      ['auth_links/operator-uid', { user_id: 'operator-id', active: true, created_at: TIME, created_by: 'operator-id' }],
      ['users/operator-id', adminUser({ access_role: role })],
      ['donors/donor-id', donor(donorChanges)],
      ...entries,
    ]),
    auth: new FakeAuth([['operator-uid', { uid: 'operator-uid', emailVerified: true, disabled: false }]]),
    serverTimestamp: () => SERVER_TIME,
    operatorUid: 'operator-uid', donorId: 'donor-id', operationId: 'operation-id',
    reason: 'Reviewed donor archive.',
  };
}

async function rejectsCode(promise, code) {
  await assert.rejects(promise, (error) => error.code === code);
}

test('developer_admin and leader deactivate donor atomically with minimal audit', async () => {
  for (const role of ['developer_admin', 'leader']) {
    const input = args(role);
    const result = await deactivateDonor(input);
    const stored = input.db.documents.get('donors/donor-id');
    assert.equal(result.donorId, 'donor-id');
    assert.equal(stored.active, false);
    assert.equal(stored.updated_by, 'operator-id');
    assert.equal(stored.total_donations, 0);
    assert.equal(input.db.documents.has('donors/donor-id'), true);
    assert.deepEqual(input.db.documents.get('audit_logs/operation-id').changes, {
      active: { before: true, after: false },
    });
  }
});

test('lower roles, inactive donor, malformed donor, and reused operation deny without writes', async () => {
  for (const role of ['executive', 'committee', 'member']) {
    const input = args(role);
    await rejectsCode(deactivateDonor(input), 'unauthorized');
    assert.equal(input.db.documents.get('donors/donor-id').active, true);
  }
  await rejectsCode(deactivateDonor(args('leader', { active: false })), 'already_inactive');
  await rejectsCode(deactivateDonor(args('leader', { created_at: 'legacy-date' })), 'malformed');
  await rejectsCode(deactivateDonor(args('leader', {}, [['audit_logs/operation-id', { action: 'other' }]])), 'operation_reused');
});

test('donor schema is exact and contains no legacy aliases', () => {
  assert.equal(donorSchemaFields.size, 18);
  for (const field of ['photo', 'upazilla', 'last_donated']) assert.equal(donorSchemaFields.has(field), false);
});

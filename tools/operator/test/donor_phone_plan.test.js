import assert from 'node:assert/strict';
import test from 'node:test';

import {
  canonicalDonorPhone,
  planDonorPhoneReservations,
  auditDonorPhoneIdentities,
} from '../src/donor_phone_plan.js';

test('Bangladesh mobile identity canonicalizes domestic, +880 and Bengali digits', () => {
  for (const value of [
    '01712345678', '+8801712345678', '8801712345678',
    '+880 1712-345678', '০১৭১২৩৪৫৬৭৮',
  ]) {
    assert.equal(canonicalDonorPhone(value), '01712345678');
  }
  for (const value of ['017', '01012345678', '+991712345678', null]) {
    assert.throws(() => canonicalDonorPhone(value), e => e.code === 'invalid_phone');
  }
});

test('read-only migration review finds legacy, inactive and cross-format duplicates', () => {
  const result = planDonorPhoneReservations([
    { id: 'active-one', phone: '01712345678', active: true },
    { id: 'archived-two', phone: '+8801712345678', active: false },
    { id: 'invalid-three', phone: '017', active: true },
    { id: 'unique-four', phone: '01812345678', active: true },
  ]);
  assert.equal(result.total, 4);
  assert.equal(result.validUniquePhones, 2);
  assert.equal(result.migrationReady, false);
  assert.deepEqual(result.invalidIds, ['invalid-three']);
  assert.deepEqual(result.duplicateGroups, [{
    phone: '01712345678',
    donorIds: ['active-one', 'archived-two'],
  }]);
});

test('only a fully clean historical identity audit is migration-ready', () => {
  const result = planDonorPhoneReservations([
    { id: 'first', phone: '01712345678', active: false },
    { id: 'second', phone: '০১৮১২৩৪৫৬৭৮', active: true },
  ]);
  assert.equal(result.migrationReady, true);
  assert.equal(result.validUniquePhones, 2);
  assert.deepEqual(result.duplicateGroups, []);
  assert.deepEqual(result.invalidIds, []);
});

function fakeDonorReader(records) {
  const docs = records.map(record => ({
    id: record.id,
    data: () => ({ phone: record.phone, active: record.active }),
  }));
  let reads = 0;
  const makeQuery = (start, size) => ({
    async get() {
      reads++;
      return { docs: docs.slice(start, start + size) };
    },
    startAfter(cursor) {
      return makeQuery(docs.indexOf(cursor) + 1, size);
    },
  });
  return {
    db: {
      collection(name) {
        assert.equal(name, 'donors');
        return {
          orderBy(field) {
            assert.equal(field, '__name__');
            return { limit(size) { return makeQuery(0, size); } };
          },
        };
      },
    },
    get reads() { return reads; },
  };
}

test('identity audit paginates historical records and does not skip the last page', async () => {
  const reader = fakeDonorReader([
    { id: 'a', phone: '01712345678', active: true },
    { id: 'b', phone: '01812345678', active: false },
    { id: 'c', phone: '+8801712345678', active: true },
  ]);
  const result = await auditDonorPhoneIdentities({
    db: reader.db, pageSize: 2, maxRecords: 10,
  });
  assert.equal(reader.reads, 2);
  assert.equal(result.total, 3);
  assert.equal(result.migrationReady, false);
  assert.deepEqual(result.duplicateGroups[0].donorIds, ['a', 'c']);
});

test('identity audit stops rather than incorrectly declaring a truncated scan clean', async () => {
  const reader = fakeDonorReader([
    { id: 'a', phone: '01712345678', active: true },
    { id: 'b', phone: '01812345678', active: true },
    { id: 'c', phone: '01912345678', active: true },
  ]);
  await assert.rejects(auditDonorPhoneIdentities({
    db: reader.db, pageSize: 2, maxRecords: 2,
  }), e => e.code === 'limit_exceeded');
});

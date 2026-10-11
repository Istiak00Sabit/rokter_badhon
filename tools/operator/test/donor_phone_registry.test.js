import assert from 'node:assert/strict';
import test from 'node:test';
import {
  verifyDonorPhoneRegistry,
  auditDonorPhoneRegistry,
} from '../src/donor_phone_plan.js';

const donor = (id, phone, active = true) => ({ id, phone, active });
const key = (phone, donorId) => ({ id: phone, phone, donorId });
const ready = { ready: true, schema_version: 1 };
const goodDonors = [
  donor('person-a', '01712345678'),
  donor('person-b', '01812345678', false),
];
const goodKeys = [
  key('01712345678', 'person-a'),
  key('01812345678', 'person-b'),
];

test('complete registry scan has zero missing or mismatched reservations, including archived donors', () => {
  const report = verifyDonorPhoneRegistry(goodDonors, goodKeys, ready);
  assert.equal(report.releaseReady, true);
  assert.equal(report.reservationIntegrityReady, true);
  assert.equal(report.donorsScanned, 2);
  assert.equal(report.reservationsScanned, 2);
  assert.equal(report.writesPerformed, 0);
  const encoded = JSON.stringify(report);
  assert.doesNotMatch(encoded, /person-a|01712345678|person-b|01812345678/);
});

test('readiness remains false before trusted owner-controlled registry activation', () => {
  const absent = verifyDonorPhoneRegistry(goodDonors, goodKeys);
  assert.equal(absent.reservationIntegrityReady, true);
  assert.equal(absent.registryReady, false);
  assert.equal(absent.releaseReady, false);
  for (const registry of [{ ready: false, schema_version: 1 }, { ready: true, schema_version: 0 }]) {
    assert.equal(verifyDonorPhoneRegistry(goodDonors, goodKeys, registry).releaseReady, false);
  }
});

test('missing, extra, wrong-owner and malformed reservations fail closed', () => {
  const cases = [
    [goodDonors, goodKeys.slice(0, 1), 'missingKeys', 1],
    [goodDonors, [...goodKeys, key('01912345678', 'unknown')], 'orphanKeys', 1],
    [goodDonors, [key('01712345678', 'person-b'), goodKeys[1]], 'mismatchedKeys', 1],
    [goodDonors, [{ id: '+8801712345678', phone: '+8801712345678', donorId: 'person-a' }, goodKeys[1]], 'malformedKeys', 1],
    [goodDonors, [{ id: '01712345678', phone: '01912345678', donorId: 'person-a' }, goodKeys[1]], 'malformedKeys', 1],
  ];
  for (const [donors, reservations, field, expected] of cases) {
    const report = verifyDonorPhoneRegistry(donors, reservations, ready);
    assert.equal(report.releaseReady, false);
    assert.equal(report[field], expected);
    assert.equal(report.writesPerformed, 0);
  }
});

test('uncanonical, duplicate and invalid historical donor numbers require manual migration', () => {
  const cases = [
    [[donor('person-a', '+8801712345678'), goodDonors[1]], 'noncanonicalDonors'],
    [[donor('person-a', '01712345678'), donor('person-c', '+8801712345678')], 'duplicatePhones'],
    [[donor('person-a', '017'), goodDonors[1]], 'invalidDonors'],
    [[donor('person-a', '০১৭১২৩৪৫৬৭৮'), goodDonors[1]], 'noncanonicalDonors'],
  ];
  for (const [donors, field] of cases) {
    const report = verifyDonorPhoneRegistry(donors, goodKeys, ready);
    assert.equal(report.releaseReady, false);
    assert.ok(report[field] > 0);
    assert.equal(report.writesPerformed, 0);
  }
});

function fakeReader({ donors, keys, registry }) {
  let writes = 0, reads = 0;
  const collections = { donors, donor_phone_keys: keys };
  const db = {
    collection(name) {
      if (name === 'system_config') {
        return {
          doc(id) {
            assert.equal(id, 'donor_phone_registry');
            return {
              async get() {
                reads++;
                return { exists: registry != null, data: () => registry };
              },
            };
          },
        };
      }
      assert.ok(Object.hasOwn(collections, name));
      const docs = collections[name].map(entry => ({
        id: entry.id,
        data: () => ({ ...entry, donor_id: entry.donorId }),
      }));
      const paginate = (from, size) => ({
        async get() {
          reads++;
          return { docs: docs.slice(from, from + size) };
        },
        startAfter(cursor) {
          return paginate(docs.findIndex(x => x.id === cursor.id) + 1, size);
        },
      });
      return {
        orderBy(field) {
          assert.equal(field, '__name__');
          return { limit(size) { return paginate(0, size); } };
        },
      };
    },
  };
  return { db, get reads() { return reads; }, get writes() { return writes; } };
}

test('emulator-only checker fully paginates donors and reservations without writes', async () => {
  const fake = fakeReader({ donors: goodDonors, keys: goodKeys, registry: ready });
  const report = await auditDonorPhoneRegistry({
    db: fake.db, pageSize: 1, maxRecords: 5,
  });
  assert.equal(report.releaseReady, true);
  assert.equal(fake.reads, 7); // two full pages + empty tail per collection, registry
  assert.equal(fake.writes, 0);
});

test('registry reader refuses incomplete scans rather than reporting a clean migration', async () => {
  const fake = fakeReader({ donors: goodDonors, keys: goodKeys, registry: ready });
  await assert.rejects(
    auditDonorPhoneRegistry({ db: fake.db, pageSize: 1, maxRecords: 1 }),
    error => error.code === 'limit_exceeded' || error.code === 'invalid_argument',
  );
});

test('duplicate scan IDs are treated as malformed rather than silently overwritten', () => {
  assert.throws(
    () => verifyDonorPhoneRegistry([donor('same', '01712345678'), donor('same', '01812345678')], goodKeys, ready),
    error => error.code === 'malformed',
  );
});

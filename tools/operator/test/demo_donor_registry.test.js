import assert from 'node:assert/strict';
import test from 'node:test';
import { seedEmptyDemoDonorRegistry } from '../src/demo_donor_registry.js';

function fake({ donors = [], keys = [], registry = null } = {}) {
  const data = {
    donors: new Map(donors.map(item => [item.id, item])),
    donor_phone_keys: new Map(keys.map(item => [item.id, item])),
    system_config: new Map(registry == null ? [] : [['donor_phone_registry', registry]]),
  };
  let writes = 0;
  const getDocs = (name) => [...data[name].entries()].map(([id, value]) => ({
    id,
    data: () => value,
  }));
  const query = (name, size) => ({
    async get() {
      return { docs: getDocs(name).slice(0, size) };
    },
    startAfter(cursor) {
      const docs = getDocs(name);
      return { async get() { return { docs: docs.slice(docs.findIndex(x => x.id === cursor.id) + 1,
        docs.findIndex(x => x.id === cursor.id) + 1 + size) }; } };
    },
  });
  const db = {
    collection(name) {
      assert.ok(Object.hasOwn(data, name));
      return {
        orderBy(field) {
          assert.equal(field, '__name__');
          return { limit(size) { return query(name, size); } };
        },
        limit(size) { return query(name, size); },
        doc(id) {
          return {
            name, id,
            async get() { return { exists: data[name].has(id), data: () => data[name].get(id) }; },
          };
        },
      };
    },
    async runTransaction(callback) {
      const modifications = [];
      const transaction = {
        async get(ref) {
          if (typeof ref.get === 'function') {
            const result = await ref.get();
            if (Array.isArray(result.docs)) return { ...result, empty: result.docs.length === 0 };
            return result;
          }
          throw new Error('Unknown fake read');
        },
        create(ref, value) { modifications.push({ op: 'create', ref, value }); },
        update(ref, value) { modifications.push({ op: 'update', ref, value }); },
      };
      const result = await callback(transaction);
      for (const item of modifications) {
        writes++;
        if (item.op === 'create') {
          assert.equal(data[item.ref.name].has(item.ref.id), false);
          data[item.ref.name].set(item.ref.id, item.value);
        } else {
          data[item.ref.name].set(item.ref.id, { ...data[item.ref.name].get(item.ref.id), ...item.value });
        }
      }
      return result;
    },
  };
  return { db, data, get writes() { return writes; } };
}

const args = db => ({
  db, projectId: 'demo-rokter-badhon',
  firestoreEmulatorHost: '127.0.0.1:8080',
  authEmulatorHost: '127.0.0.1:9099',
});

test('empty demo database gets exactly one repeatable phone-registry fixture', async () => {
  const f = fake();
  const first = await seedEmptyDemoDonorRegistry(args(f.db));
  assert.equal(first.action, 'demo_donor_registry_seeded');
  assert.equal(f.data.system_config.get('donor_phone_registry').ready, true);
  const second = await seedEmptyDemoDonorRegistry(args(f.db));
  assert.equal(second.action, 'demo_donor_registry_already_seeded');
  assert.equal(f.writes, 1);
});

test('fixture rejects all non-demo and missing-emulator targets before reading', async () => {
  const f = fake();
  for (const change of [
    { projectId: 'rokterbadhon-b247b' },
    { firestoreEmulatorHost: null },
    { authEmulatorHost: null },
  ]) {
    await assert.rejects(
      seedEmptyDemoDonorRegistry({ ...args(f.db), ...change }),
      error => error.code === 'unsafe_target',
    );
  }
  assert.equal(f.writes, 0);
});

test('existing donor records, orphan keys and malformed registry states cannot be auto-migrated', async () => {
  for (const scenario of [
    { donors: [{ id: 'x', phone: '01712345678', active: true }] },
    { keys: [{ id: '01712345678', phone: '01712345678', donor_id: 'x' }] },
    { registry: { ready: true, schema_version: 99 } },
    { registry: { ready: false, schema_version: 7 } },
  ]) {
    const f = fake(scenario);
    await assert.rejects(
      seedEmptyDemoDonorRegistry(args(f.db)),
      error => ['requires_manual_review', 'ambiguous_state'].includes(error.code),
    );
    assert.equal(f.writes, 0);
  }
});

test('locally pre-disabled and schema-matched empty registry may be activated', async () => {
  const f = fake({ registry: { ready: false, schema_version: 1 } });
  const result = await seedEmptyDemoDonorRegistry(args(f.db));
  assert.equal(result.action, 'demo_donor_registry_seeded');
  assert.equal(f.data.system_config.get('donor_phone_registry').ready, true);
  assert.equal(f.writes, 1);
});

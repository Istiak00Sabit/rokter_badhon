import assert from 'node:assert/strict';
import test from 'node:test';

import { LOCAL_TEST_ADMIN, seedLocalTestAdmin } from '../src/seed_test_admin.js';
import { schemaFields } from '../src/policy.js';
import { FakeAuth, FakeFirestore, SERVER_TIME } from './fakes.js';
import { internalAuthEmailForPhone } from '../src/auth_identity.js';

class SeedAuth extends FakeAuth {
  constructor() {
    super([]);
  }

  async getUserByEmail(email) {
    const record = [...this.users.values()].find((value) => value.email === email);
    if (!record) throw Object.assign(new Error('missing'), { code: 'auth/user-not-found' });
    return record;
  }

  async createUser(input) {
    const record = { uid: 'local-test-admin-auth', ...input };
    this.users.set(record.uid, record);
    return record;
  }

  async updateUser(uid, changes) {
    const record = { ...this.users.get(uid), ...changes };
    this.users.set(uid, record);
    return record;
  }
}

test('local seed creates a verified identity satisfying the normal admission gates', async () => {
  assert.equal(LOCAL_TEST_ADMIN.email, 'a@a.com');
  assert.equal(LOCAL_TEST_ADMIN.password, '123456');
  const db = new FakeFirestore();
  const auth = new SeedAuth();
  const result = await seedLocalTestAdmin({
    projectId: 'demo-rokter-badhon',
    db,
    auth,
    serverTimestamp: () => SERVER_TIME,
  });
  const authRecord = await auth.getUser('local-test-admin-auth');
  const link = db.documents.get('auth_links/local-test-admin-auth');
  const user = db.documents.get(`users/${result.userId}`);
  const directory = db.documents.get(`user_directory/${result.userId}`);

  assert.equal(authRecord.email, internalAuthEmailForPhone(LOCAL_TEST_ADMIN.phone));
  assert.equal(authRecord.emailVerified, false);
  assert.equal(authRecord.disabled, false);
  assert.equal(authRecord.password, LOCAL_TEST_ADMIN.password);
  assert.deepEqual(new Set(Object.keys(link)), schemaFields.link);
  assert.deepEqual(new Set(Object.keys(user)), schemaFields.user);
  assert.deepEqual(new Set(Object.keys(directory)), schemaFields.directory);
  assert.equal(link.active, true);
  assert.equal(user.access_role, 'developer_admin');
  assert.equal(user.active, true);
  assert.equal(user.login_enabled, true);
});

test('local seed refuses every non-demo production-like target', async () => {
  await assert.rejects(
    seedLocalTestAdmin({
      projectId: 'rokterbadhon-b247b',
      db: new FakeFirestore(),
      auth: new SeedAuth(),
      serverTimestamp: () => SERVER_TIME,
    }),
    (error) => error.code === 'unsafe_target',
  );
});

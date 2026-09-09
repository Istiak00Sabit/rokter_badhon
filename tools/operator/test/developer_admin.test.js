import assert from 'node:assert/strict';
import test from 'node:test';

import { bootstrapDeveloperAdmin, recoverDeveloperAdmin } from '../src/developer_admin.js';
import { schemaFields } from '../src/policy.js';
import {
  FakeAuth,
  FakeFirestore,
  SERVER_TIME,
  TIME,
  adminUser,
  directoryFor,
} from './fakes.js';

const identity = {
  name: 'Protected Admin',
  phone: '01111111111',
  email: 'new-admin@example.test',
  blood_group: null,
  profession: null,
  address: null,
  preferred_language: 'en',
};

function authRecord(uid = 'new-auth-uid', changes = {}) {
  return {
    uid,
    email: 'new-admin@example.test',
    emailVerified: true,
    disabled: false,
    ...changes,
  };
}

function bootstrapArgs({ entries = [], authChanges = {}, overrides = {} } = {}) {
  return {
    db: new FakeFirestore(entries),
    auth: new FakeAuth([['new-auth-uid', authRecord('new-auth-uid', authChanges)]]),
    serverTimestamp: () => SERVER_TIME,
    authUid: 'new-auth-uid',
    identity,
    operationId: 'bootstrap-1',
    reason: 'Initial protected custodian bootstrap in demo environment.',
    ...overrides,
  };
}

function recoveryArgs({ oldUserChanges = {}, oldAuthChanges = {}, entries = [], overrides = {} } = {}) {
  const old = adminUser(oldUserChanges);
  return {
    db: new FakeFirestore([
      ['users/old-admin-user', old],
      ['user_directory/old-admin-user', directoryFor(old)],
      ['auth_links/old-auth-uid', {
        user_id: 'old-admin-user',
        active: true,
        created_at: TIME,
        created_by: 'old-admin-user',
      }],
      ...entries,
    ]),
    auth: new FakeAuth([
      ['new-auth-uid', authRecord()],
      ['old-auth-uid', {
        uid: 'old-auth-uid',
        email: 'old-admin@example.test',
        emailVerified: true,
        disabled: true,
        ...oldAuthChanges,
      }],
    ]),
    serverTimestamp: () => SERVER_TIME,
    authUid: 'new-auth-uid',
    oldUserId: 'old-admin-user',
    identity,
    operationId: 'recovery-1',
    reason: 'Broken administrator identity replaced under protected recovery.',
    ...overrides,
  };
}

async function rejectsCode(promise, code) {
  await assert.rejects(promise, (error) => error.code === code);
}

test('valid first bootstrap creates exact User, directory, link, and audit only', async () => {
  const args = bootstrapArgs();
  const result = await bootstrapDeveloperAdmin(args);
  const user = args.db.documents.get(`users/${result.userId}`);
  const directory = args.db.documents.get(`user_directory/${result.userId}`);
  const link = args.db.documents.get('auth_links/new-auth-uid');
  const audit = args.db.documents.get('audit_logs/bootstrap-1');

  assert.deepEqual(new Set(Object.keys(user)), schemaFields.user);
  assert.deepEqual(new Set(Object.keys(directory)), schemaFields.directory);
  assert.deepEqual(new Set(Object.keys(link)), schemaFields.link);
  assert.deepEqual(directory, directoryFor(user));
  assert.equal(user.access_role, 'developer_admin');
  assert.equal(user.active, true);
  assert.equal(user.login_enabled, true);
  assert.equal(audit.action, 'admin.provision');
  assert.equal(audit.actor_user_id, null);
  assert.equal([...args.db.documents.keys()].some((path) => path.startsWith('registration_requests/')), false);
});

test('bootstrap denies unverified or disabled Auth', async () => {
  await rejectsCode(
    bootstrapDeveloperAdmin(bootstrapArgs({ authChanges: { emailVerified: false } })),
    'email_unverified',
  );
  await rejectsCode(
    bootstrapDeveloperAdmin(bootstrapArgs({ authChanges: { disabled: true } })),
    'auth_disabled',
  );
});

test('bootstrap denies existing auth link and existing developer_admin', async () => {
  await rejectsCode(
    bootstrapDeveloperAdmin(bootstrapArgs({
      entries: [['auth_links/new-auth-uid', {
        user_id: 'someone', active: false, created_at: TIME, created_by: 'someone',
      }]],
    })),
    'existing_auth_link',
  );
  const existing = adminUser();
  const existingArgs = bootstrapArgs({ entries: [
      ['users/existing-admin', existing],
      ['user_directory/existing-admin', directoryFor(existing)],
      ['auth_links/existing-auth', {
        user_id: 'existing-admin', active: true, created_at: TIME, created_by: 'existing-admin',
      }],
    ] });
  existingArgs.auth.users.set('existing-auth', {
    uid: 'existing-auth',
    email: existing.email,
    emailVerified: true,
    disabled: false,
  });
  await rejectsCode(
    bootstrapDeveloperAdmin(existingArgs),
    'existing_admin_state',
  );
});

test('failed bootstrap has zero partial writes and operation-ID reuse is denied', async () => {
  const failed = bootstrapArgs({ authChanges: { emailVerified: false } });
  await rejectsCode(bootstrapDeveloperAdmin(failed), 'email_unverified');
  assert.equal(failed.db.documents.size, 0);

  const reused = bootstrapArgs({ entries: [['audit_logs/bootstrap-1', { action: 'old' }]] });
  const before = new Set(reused.db.documents.keys());
  await rejectsCode(bootstrapDeveloperAdmin(reused), 'operation_reused');
  assert.deepEqual(new Set(reused.db.documents.keys()), before);
});

test('valid broken-admin recovery preserves and deactivates old records with audit', async () => {
  const args = recoveryArgs();
  const result = await recoverDeveloperAdmin(args);
  const oldUser = args.db.documents.get('users/old-admin-user');
  const oldDirectory = args.db.documents.get('user_directory/old-admin-user');
  const oldLink = args.db.documents.get('auth_links/old-auth-uid');
  const replacement = args.db.documents.get(`users/${result.userId}`);

  assert.equal(oldUser.active, false);
  assert.equal(oldUser.login_enabled, false);
  assert.equal(oldDirectory.active, false);
  assert.equal(oldLink.active, false);
  assert.equal(args.db.documents.has('users/old-admin-user'), true);
  assert.equal(args.db.documents.has('auth_links/old-auth-uid'), true);
  assert.equal(replacement.access_role, 'developer_admin');
  assert.equal(args.db.documents.get('audit_logs/recovery-1').action, 'admin.recover');
});

test('healthy existing developer_admin prevents recovery', async () => {
  await rejectsCode(
    recoverDeveloperAdmin(recoveryArgs({ oldAuthChanges: { disabled: false } })),
    'healthy_admin_exists',
  );
});

test('ambiguous multiple current developer_admin records deny recovery', async () => {
  const second = adminUser({ email: 'second@example.test' });
  await rejectsCode(
    recoverDeveloperAdmin(recoveryArgs({ entries: [
      ['users/second-admin', second],
      ['user_directory/second-admin', directoryFor(second)],
    ] })),
    'ambiguous_admin_state',
  );
});

test('ordinary User cannot be silently promoted through recovery', async () => {
  const args = recoveryArgs({ oldUserChanges: { access_role: 'leader' } });
  const before = new Set(args.db.documents.keys());
  await rejectsCode(recoverDeveloperAdmin(args), 'ordinary_promotion_denied');
  assert.deepEqual(new Set(args.db.documents.keys()), before);
});

test('failed recovery leaves no partial replacement state and retry is denied', async () => {
  const failed = recoveryArgs();
  failed.db.documents.delete('user_directory/old-admin-user');
  const before = new Set(failed.db.documents.keys());
  await rejectsCode(recoverDeveloperAdmin(failed), 'missing');
  assert.deepEqual(new Set(failed.db.documents.keys()), before);

  const retry = recoveryArgs();
  await recoverDeveloperAdmin(retry);
  const committed = new Set(retry.db.documents.keys());
  await rejectsCode(recoverDeveloperAdmin(retry), 'ambiguous_admin_state');
  assert.deepEqual(new Set(retry.db.documents.keys()), committed);
  assert.equal([...retry.db.documents.keys()].filter((path) => path.startsWith('audit_logs/')).length, 1);
});

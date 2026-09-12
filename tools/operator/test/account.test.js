import assert from 'node:assert/strict';
import test from 'node:test';
import {
  assignAccessRole,
  createAuthLink,
  createOrganizationUser,
  replaceAuthLink,
  setLoginEnabled,
  setUserActive,
  updateOwnPhoto,
} from '../src/account.js';
import { adminUser, directoryFor, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const UID = 'operator-uid'; const ACTOR = 'operator-user'; const TARGET = 'target-user';
const link = (userId, changes = {}) => ({ user_id: userId, active: true, created_at: TIME, created_by: 'seed', ...changes });
const user = (changes = {}) => adminUser({ name: 'Target', phone: '01234567890', email: 'target@example.test', access_role: 'member', login_enabled: false, ...changes });
function fixture({ actorRole = 'developer_admin', target = user(), targetLinkUid, entries = [], authUsers = [] } = {}) {
  const actor = adminUser({ access_role: actorRole }); const docs = [['auth_links/operator-uid', link(ACTOR)], [`users/${ACTOR}`, actor], [`user_directory/${ACTOR}`, directoryFor(actor)], [`users/${TARGET}`, target], [`user_directory/${TARGET}`, directoryFor(target)], ...entries];
  if (targetLinkUid) docs.push([`auth_links/${targetLinkUid}`, link(TARGET)]);
  return { db: new FakeFirestore(docs), auth: new FakeAuth([[UID, { uid: UID, email: 'operator@example.test', emailVerified: true, disabled: false }], ...authUsers]) };
}
const common = (base, operationId) => ({ ...base, serverTimestamp: () => SERVER_TIME, operatorUid: UID, operationId, reason: 'Identity verified and reviewed.' });
async function denied(promise, expected) { await assert.rejects(promise, (error) => error.code === expected); }

test('DA and leader create exact organization-only member without login or link', async () => {
  for (const actorRole of ['developer_admin', 'leader']) {
    const base = fixture({ actorRole });
    const input = { name: 'New User', phone: '01900000000', email: null, bloodGroup: null, profession: null, address: null, photoUrl: null, preferredLanguage: 'bn' };
    const result = await createOrganizationUser({ ...common(base, `create-${actorRole}`), ...input }); const created = base.db.documents.get(`users/${result.userId}`);
    assert.equal(created.access_role, 'member'); assert.equal(created.active, true); assert.equal(created.login_enabled, false); assert.equal(base.db.documents.has(`auth_links/${result.userId}`), false); assert.deepEqual(base.db.documents.get(`user_directory/${result.userId}`), directoryFor(created));
    assert.equal((await createOrganizationUser({ ...common(base, `create-${actorRole}`), ...input })).action, 'user-already-created');
  }
});

test('user creation rejects lower roles, malformed input, and altered retries', async () => {
  const input = { name: 'New', phone: '019', email: null, bloodGroup: null, profession: null, address: null, photoUrl: null, preferredLanguage: null };
  await denied(createOrganizationUser({ ...common(fixture({ actorRole: 'executive' }), 'c-1'), ...input }), 'unauthorized');
  await denied(createOrganizationUser({ ...common(fixture(), 'c-2'), ...input, photoUrl: 'http://unsafe' }), 'invalid_argument');
  const base = fixture(); await createOrganizationUser({ ...common(base, 'c-3'), ...input }); await denied(createOrganizationUser({ ...common(base, 'c-3'), ...input, phone: 'changed' }), 'operation_reused');
});

test('role assignment follows ordinary and leader target boundaries without side effects', async () => {
  const leader = fixture({ actorRole: 'leader' }); await assignAccessRole({ ...common(leader, 'r-1'), userId: TARGET, targetRole: 'executive' });
  assert.equal(leader.db.documents.get(`users/${TARGET}`).access_role, 'executive'); assert.equal(leader.db.documents.get(`users/${TARGET}`).login_enabled, false);
  await denied(assignAccessRole({ ...common(fixture({ actorRole: 'leader' }), 'r-2'), userId: TARGET, targetRole: 'leader' }), 'unauthorized');
  const promote = fixture(); await assignAccessRole({ ...common(promote, 'r-3'), userId: TARGET, targetRole: 'leader' }); assert.equal(promote.db.documents.get(`users/${TARGET}`).access_role, 'leader');
  const demoteLeader = fixture({ target: user({ access_role: 'leader' }) }); await assignAccessRole({ ...common(demoteLeader, 'r-4'), userId: TARGET, targetRole: 'member' }); assert.equal(demoteLeader.db.documents.get(`users/${TARGET}`).access_role, 'member');
});

test('disable/reactivate preserves role and login while synchronizing directory', async () => {
  const base = fixture({ actorRole: 'leader', target: user({ login_enabled: true }) }); await setUserActive({ ...common(base, 'd-1'), userId: TARGET, active: false });
  assert.equal(base.db.documents.get(`users/${TARGET}`).active, false); assert.equal(base.db.documents.get(`users/${TARGET}`).login_enabled, true); assert.equal(base.db.documents.get(`user_directory/${TARGET}`).active, false);
  await setUserActive({ ...common(base, 'd-2'), userId: TARGET, active: true }); assert.equal(base.db.documents.get(`users/${TARGET}`).active, true);
});

test('only DA may use explicit leader state and login operations', async () => {
  const target = user({ access_role: 'leader', active: true, login_enabled: true }); const deniedBase = fixture({ actorRole: 'leader', target });
  await denied(setUserActive({ ...common(deniedBase, 'ld-1'), userId: TARGET, active: false, leaderTarget: true }), 'unauthorized_target');
  const base = fixture({ target, targetLinkUid: 'leader-auth', authUsers: [['leader-auth', { uid: 'leader-auth', email: 'target@example.test', emailVerified: true, disabled: false }]] });
  await setLoginEnabled({ ...common(base, 'ld-2'), userId: TARGET, enabled: false, leaderTarget: true }); assert.equal(base.db.documents.get(`users/${TARGET}`).login_enabled, false);
  await setLoginEnabled({ ...common(base, 'ld-3'), userId: TARGET, enabled: true, leaderTarget: true }); assert.equal(base.db.documents.get(`users/${TARGET}`).login_enabled, true);
});

test('login enable requires exactly one enabled verified matching active link', async () => {
  const good = fixture({ targetLinkUid: 'target-auth', authUsers: [['target-auth', { uid: 'target-auth', email: 'target@example.test', emailVerified: true, disabled: false }]] });
  await setLoginEnabled({ ...common(good, 'l-1'), userId: TARGET, enabled: true }); assert.equal(good.db.documents.get(`users/${TARGET}`).login_enabled, true);
  const missing = fixture(); await denied(setLoginEnabled({ ...common(missing, 'l-2'), userId: TARGET, enabled: true }), 'link_state_invalid');
  const mismatch = fixture({ targetLinkUid: 'target-auth', authUsers: [['target-auth', { uid: 'target-auth', email: 'other@example.test', emailVerified: true, disabled: false }]] }); await denied(setLoginEnabled({ ...common(mismatch, 'l-3'), userId: TARGET, enabled: true }), 'target_identity_invalid');
});

test('auth link create enforces verification, uniqueness, role boundary, and exact retry', async () => {
  const base = fixture({ authUsers: [['new-auth', { uid: 'new-auth', email: 'target@example.test', emailVerified: true, disabled: false }]] });
  const args = { ...common(base, 'a-1'), userId: TARGET, targetAuthUid: 'new-auth' }; await createAuthLink(args); assert.deepEqual(base.db.documents.get('auth_links/new-auth'), { user_id: TARGET, active: true, created_at: SERVER_TIME, created_by: ACTOR }); assert.equal((await createAuthLink(args)).action, 'auth-link-already-created');
  const leader = fixture({ actorRole: 'leader', target: user({ access_role: 'leader' }), authUsers: [['new-auth', { uid: 'new-auth', email: 'target@example.test', emailVerified: true, disabled: false }]] }); await denied(createAuthLink({ ...common(leader, 'a-2'), userId: TARGET, targetAuthUid: 'new-auth', leaderTarget: true }), 'unauthorized_target');
});

test('auth link replacement atomically retires old identity and rejects conflicts', async () => {
  const base = fixture({ targetLinkUid: 'old-auth', authUsers: [['new-auth', { uid: 'new-auth', email: 'target@example.test', emailVerified: true, disabled: false }]] });
  const args = { ...common(base, 'x-1'), userId: TARGET, oldAuthUid: 'old-auth', newAuthUid: 'new-auth' }; await replaceAuthLink(args);
  assert.equal(base.db.documents.get('auth_links/old-auth').active, false); assert.equal(base.db.documents.get('auth_links/new-auth').active, true); assert.equal((await replaceAuthLink(args)).action, 'auth-link-already-replaced');
  const conflict = fixture({ targetLinkUid: 'old-auth', entries: [['auth_links/new-auth', link('someone-else')]], authUsers: [['new-auth', { uid: 'new-auth', email: 'target@example.test', emailVerified: true, disabled: false }]] }); await denied(replaceAuthLink({ ...common(conflict, 'x-2'), userId: TARGET, oldAuthUid: 'old-auth', newAuthUid: 'new-auth' }), 'link_conflict');
});

test('photo workflow is own-only, HTTPS validated, audited, and Q synchronized', async () => {
  const base = fixture({ actorRole: 'member' }); await updateOwnPhoto({ ...common(base, 'p-1'), photoUrl: 'https://images.example.test/me.jpg' });
  assert.equal(base.db.documents.get(`users/${ACTOR}`).photo_url, 'https://images.example.test/me.jpg'); assert.equal(base.db.documents.get(`user_directory/${ACTOR}`).photo_url, 'https://images.example.test/me.jpg');
  await denied(updateOwnPhoto({ ...common(fixture(), 'p-2'), photoUrl: 'data:image/png;base64,x' }), 'invalid_argument');
});

test('malformed or stale target projection fails before any privileged write', async () => {
  const base = fixture({ entries: [[`user_directory/${TARGET}`, { ...directoryFor(user()), name: 'Stale' }]] }); await denied(setUserActive({ ...common(base, 'q-1'), userId: TARGET, active: false }), 'projection_mismatch'); assert.equal(base.db.documents.has('audit_logs/q-1'), false);
  const protectedBase = fixture({ target: user({ access_role: 'developer_admin' }) }); await denied(setUserActive({ ...common(protectedBase, 'q-2'), userId: TARGET, active: false }), 'protected_admin');
});

test('organization user to admitted account flow is exact and audited end to end', async () => {
  const base = fixture();
  const created = await createOrganizationUser({
    ...common(base, 'flow-create'),
    name: 'Flow User',
    phone: '01999999999',
    email: 'flow@example.test',
    bloodGroup: 'O+',
    profession: null,
    address: null,
    photoUrl: null,
    preferredLanguage: 'bn',
  });
  base.auth.users.set('flow-auth', {
    uid: 'flow-auth',
    email: 'flow@example.test',
    emailVerified: true,
    disabled: false,
  });
  await createAuthLink({
    ...common(base, 'flow-link'),
    userId: created.userId,
    targetAuthUid: 'flow-auth',
  });
  await setLoginEnabled({
    ...common(base, 'flow-login'),
    userId: created.userId,
    enabled: true,
  });
  await assignAccessRole({
    ...common(base, 'flow-role'),
    userId: created.userId,
    targetRole: 'committee',
  });

  const admitted = base.db.documents.get(`users/${created.userId}`);
  assert.equal(admitted.active, true);
  assert.equal(admitted.login_enabled, true);
  assert.equal(admitted.access_role, 'committee');
  assert.equal(base.db.documents.get('auth_links/flow-auth').user_id, created.userId);
  assert.deepEqual(base.db.documents.get(`user_directory/${created.userId}`), directoryFor(admitted));
  assert.deepEqual(
    ['flow-create', 'flow-link', 'flow-login', 'flow-role'].map((id) =>
      base.db.documents.get(`audit_logs/${id}`).operation_id),
    ['flow-create', 'flow-link', 'flow-login', 'flow-role'],
  );
});

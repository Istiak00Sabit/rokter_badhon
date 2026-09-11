import assert from 'node:assert/strict';
import test from 'node:test';
import { archiveNotice, createNotice, editNotice, noticeSchemaFields, publishNotice } from '../src/notice.js';
import { adminUser, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const UID = 'operator-uid'; const USER = 'operator-user'; const NOTICE = 'notice-1';
const notice = (changes = {}) => ({ title: 'Meeting', body: 'Body', important: false, status: 'draft', created_by: USER, created_at: TIME, updated_by: null, updated_at: null, ...changes });
function fixture({ role = 'developer_admin', value, entries = [] } = {}) {
  const docs = [['auth_links/operator-uid', { user_id: USER, active: true, created_at: TIME, created_by: 'seed' }], [`users/${USER}`, adminUser({ access_role: role })], ...entries];
  if (value !== undefined) docs.push([`notices/${NOTICE}`, value]);
  return { db: new FakeFirestore(docs), auth: new FakeAuth([[UID, { uid: UID, email: 'operator@example.test', emailVerified: true, disabled: false }]]) };
}
const common = (base, operationId) => ({ ...base, serverTimestamp: () => SERVER_TIME, operatorUid: UID, operationId, reason: 'Reviewed notice operation.' });
async function code(promise, expected) { await assert.rejects(promise, (error) => error.code === expected); }

test('DA and leader create exact audited drafts only', async () => {
  for (const role of ['developer_admin', 'leader']) {
    const base = fixture({ role });
    const result = await createNotice({ ...common(base, `create-${role}`), title: 'Notice', body: 'Body', important: true });
    const value = base.db.documents.get(`notices/${result.noticeId}`);
    assert.deepEqual(new Set(Object.keys(value)), noticeSchemaFields); assert.equal(value.status, 'draft'); assert.equal(value.created_by, USER); assert.equal(value.updated_at, null);
    assert.equal(base.db.documents.get(`audit_logs/create-${role}`).action, 'notice.create');
  }
});

test('lower roles, malformed input and operation reuse cannot create', async () => {
  await code(createNotice({ ...common(fixture({ role: 'executive' }), 'n-1'), title: 'N', body: 'B', important: false }), 'unauthorized');
  await code(createNotice({ ...common(fixture(), 'n-2'), title: '', body: 'B', important: false }), 'invalid_argument');
  const reused = fixture({ entries: [['audit_logs/n-3', { action: 'old' }]] });
  await code(createNotice({ ...common(reused, 'n-3'), title: 'N', body: 'B', important: false }), 'operation_reused');
});

test('draft and published edit changes only content plus update metadata', async () => {
  for (const status of ['draft', 'published']) {
    const base = fixture({ role: 'leader', value: notice({ status }) }); const before = { ...base.db.documents.get(`notices/${NOTICE}`) };
    await editNotice({ ...common(base, `edit-${status}`), noticeId: NOTICE, body: 'Updated', important: true });
    assert.deepEqual(base.db.documents.get(`notices/${NOTICE}`), { ...before, body: 'Updated', important: true, updated_by: USER, updated_at: SERVER_TIME });
  }
});

test('archived, malformed, lower-role and no-op edits fail closed', async () => {
  await code(editNotice({ ...common(fixture({ value: notice({ status: 'archived', updated_by: USER, updated_at: TIME }) }), 'e-1'), noticeId: NOTICE, body: 'No' }), 'notice_archived');
  await code(editNotice({ ...common(fixture({ value: { ...notice(), legacy: true } }), 'e-2'), noticeId: NOTICE, body: 'No' }), 'malformed');
  await code(editNotice({ ...common(fixture({ role: 'committee', value: notice() }), 'e-3'), noticeId: NOTICE, body: 'No' }), 'unauthorized');
  await code(editNotice({ ...common(fixture({ value: notice() }), 'e-4'), noticeId: NOTICE }), 'invalid_argument');
});

test('publish and archive enforce one-way states with exact safe retries', async () => {
  const publish = fixture({ value: notice() });
  await publishNotice({ ...common(publish, 'publish-1'), noticeId: NOTICE });
  assert.equal(publish.db.documents.get(`notices/${NOTICE}`).status, 'published');
  assert.equal((await publishNotice({ ...common(publish, 'publish-1'), noticeId: NOTICE })).action, 'notice-already-published');
  const archive = fixture({ value: notice({ status: 'published' }) });
  await archiveNotice({ ...common(archive, 'archive-1'), noticeId: NOTICE });
  assert.equal(archive.db.documents.get(`notices/${NOTICE}`).status, 'archived');
  assert.equal((await archiveNotice({ ...common(archive, 'archive-1'), noticeId: NOTICE })).action, 'notice-already-archived');
  await code(publishNotice({ ...common(archive, 'restore-1'), noticeId: NOTICE }), 'invalid_transition');
});

test('unrelated audit collision and invalid transitions do not mutate', async () => {
  const collision = fixture({ value: notice(), entries: [['audit_logs/x-1', { action: 'event.create', target_path: `notices/${NOTICE}`, actor_user_id: USER }]] });
  await code(publishNotice({ ...common(collision, 'x-1'), noticeId: NOTICE }), 'operation_reused');
  const published = fixture({ value: notice({ status: 'published' }) });
  await code(publishNotice({ ...common(published, 'x-2'), noticeId: NOTICE }), 'invalid_transition');
});

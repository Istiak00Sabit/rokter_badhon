import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assignCommitteePosition,
  committeeSchemaFields,
  endCommitteeAssignment,
} from '../src/committee.js';
import { adminUser, directoryFor, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const OPERATOR_UID = 'operator-uid';
const OPERATOR_ID = 'operator-user';
const TARGET_ID = 'target-user';
const TERM_ID = 'term-2026';

function user(role = 'member', changes = {}) {
  return adminUser({
    name: 'Target Person',
    phone: '01111111111',
    email: 'target@example.test',
    access_role: role,
    ...changes,
  });
}

function term(changes = {}) {
  return {
    name: '2026-2028',
    start_year: 2026,
    end_year: 2028,
    start_date: null,
    end_date: null,
    active: true,
    group_photo_url: null,
    created_at: TIME,
    created_by: OPERATOR_ID,
    ...changes,
  };
}

function assignment(changes = {}) {
  return {
    user_id: TARGET_ID,
    term_id: TERM_ID,
    position: 'president',
    active: true,
    assigned_at: TIME,
    assigned_by: OPERATOR_ID,
    ended_at: null,
    ...changes,
  };
}

function fixture({ operatorRole = 'developer_admin', operatorChanges = {}, targetChanges = {}, termChanges = {}, entries = [], auth = true } = {}) {
  const operator = adminUser({ access_role: operatorRole, ...operatorChanges });
  const target = user('member', targetChanges);
  const db = new FakeFirestore([
    ['auth_links/operator-uid', { user_id: OPERATOR_ID, active: true, created_at: TIME, created_by: 'seed' }],
    [`users/${OPERATOR_ID}`, operator],
    [`users/${TARGET_ID}`, target],
    [`user_directory/${TARGET_ID}`, directoryFor(target)],
    [`committee_terms/${TERM_ID}`, term(termChanges)],
    ...entries,
  ]);
  const authService = new FakeAuth(auth ? [[OPERATOR_UID, {
    uid: OPERATOR_UID,
    email: 'operator@example.test',
    emailVerified: true,
    disabled: false,
  }]] : []);
  return { db, auth: authService };
}

function assignArgs(options = {}) {
  const base = fixture(options.fixture);
  return {
    ...base,
    serverTimestamp: () => SERVER_TIME,
    operatorUid: OPERATOR_UID,
    targetUserId: TARGET_ID,
    termId: TERM_ID,
    position: 'president',
    operationId: 'committee-operation-1',
    reason: 'Reviewed committee appointment.',
    ...options,
    ...base,
  };
}

async function rejectsCode(promise, code) {
  await assert.rejects(promise, (error) => error.code === code);
}

test('developer_admin assignment creates exact assignment and audit without changing access_role', async () => {
  const args = assignArgs();
  const before = args.db.documents.get(`users/${TARGET_ID}`).access_role;
  const result = await assignCommitteePosition(args);
  const created = args.db.documents.get(`committee_assignments/${result.assignmentId}`);
  const audit = args.db.documents.get('audit_logs/committee-operation-1');
  assert.deepEqual(new Set(Object.keys(created)), committeeSchemaFields.assignment);
  assert.deepEqual(created, {
    user_id: TARGET_ID,
    term_id: TERM_ID,
    position: 'president',
    active: true,
    assigned_at: SERVER_TIME,
    assigned_by: OPERATOR_ID,
    ended_at: null,
  });
  assert.equal(audit.action, 'committee.assign');
  assert.equal(audit.actor_auth_uid, OPERATOR_UID);
  assert.equal(args.db.documents.get(`users/${TARGET_ID}`).access_role, before);
});

test('leader has committee.assign capability', async () => {
  const args = assignArgs({ fixture: { operatorRole: 'leader' }, operationId: 'leader-assign' });
  await assignCommitteePosition(args);
  assert.equal(args.db.documents.get('audit_logs/leader-assign').actor_user_id, OPERATOR_ID);
});

test('unauthorized and inactive operators are denied', async () => {
  await rejectsCode(assignCommitteePosition(assignArgs({ fixture: { operatorRole: 'executive' } })), 'unauthorized');
  await rejectsCode(assignCommitteePosition(assignArgs({ fixture: { operatorChanges: { active: false } } })), 'operator_not_admitted');
});

test('missing, broken, or malformed operator identity fails closed', async () => {
  const noAuth = assignArgs({ fixture: { auth: false } });
  await rejectsCode(assignCommitteePosition(noAuth), 'auth_identity_missing');
  const missingLink = assignArgs();
  missingLink.db.documents.delete('auth_links/operator-uid');
  await rejectsCode(assignCommitteePosition(missingLink), 'missing');
  const brokenLink = assignArgs();
  brokenLink.db.documents.set('auth_links/operator-uid', { user_id: 'absent', active: true, created_at: TIME, created_by: 'seed' });
  await rejectsCode(assignCommitteePosition(brokenLink), 'missing');
});

test('inactive target, broken directory, inactive term, and admin target are denied', async () => {
  await rejectsCode(assignCommitteePosition(assignArgs({ fixture: { targetChanges: { active: false } } })), 'target_inactive');
  const brokenDirectory = assignArgs();
  brokenDirectory.db.documents.get(`user_directory/${TARGET_ID}`).phone = '01999999999';
  await rejectsCode(assignCommitteePosition(brokenDirectory), 'directory_mismatch');
  await rejectsCode(assignCommitteePosition(assignArgs({ fixture: { termChanges: { active: false } } })), 'term_inactive');
  await rejectsCode(assignCommitteePosition(assignArgs({ fixture: { targetChanges: { access_role: 'developer_admin' } } })), 'unauthorized_target');
});

test('duplicate active assignment for the same User and term is denied atomically', async () => {
  const args = assignArgs({ fixture: { entries: [['committee_assignments/existing', assignment()]] } });
  const paths = new Set(args.db.documents.keys());
  await rejectsCode(assignCommitteePosition(args), 'duplicate_assignment');
  assert.deepEqual(new Set(args.db.documents.keys()), paths);
  assert.equal(args.db.documents.has('audit_logs/committee-operation-1'), false);
});

test('the same position may be assigned to multiple Users', async () => {
  const other = user('committee', { name: 'Other Person', phone: '01222222222', email: 'other@example.test' });
  const args = assignArgs({ fixture: { entries: [
    ['users/other-user', other],
    ['user_directory/other-user', directoryFor(other)],
    ['committee_assignments/existing', assignment({ user_id: 'other-user' })],
  ] } });
  const result = await assignCommitteePosition(args);
  assert.equal(args.db.documents.get(`committee_assignments/${result.assignmentId}`).position, 'president');
});

test('an ended historical assignment does not consume the active slot', async () => {
  const args = assignArgs({ fixture: { entries: [['committee_assignments/history', assignment({ active: false, ended_at: TIME })]] } });
  const result = await assignCommitteePosition(args);
  assert.equal(args.db.documents.get(`committee_assignments/${result.assignmentId}`).active, true);
  assert.equal(args.db.documents.get('committee_assignments/history').position, 'president');
});

test('operation ID reuse and invalid machine position are denied without partial writes', async () => {
  const reused = assignArgs({ fixture: { entries: [['audit_logs/committee-operation-1', { action: 'other' }]] } });
  const before = new Set(reused.db.documents.keys());
  await rejectsCode(assignCommitteePosition(reused), 'operation_reused');
  assert.deepEqual(new Set(reused.db.documents.keys()), before);
  await rejectsCode(assignCommitteePosition(assignArgs({ position: 'President Chair' })), 'invalid_position');
});

test('developer_admin and leader can end active assignments with exact history and audit preserved', async () => {
  for (const role of ['developer_admin', 'leader']) {
    const base = fixture({ operatorRole: role, entries: [['committee_assignments/current', assignment()]] });
    const before = { ...base.db.documents.get('committee_assignments/current') };
    const targetRoleBefore = base.db.documents.get(`users/${TARGET_ID}`).access_role;
    const result = await endCommitteeAssignment({
      ...base,
      serverTimestamp: () => SERVER_TIME,
      operatorUid: OPERATOR_UID,
      assignmentId: 'current',
      operationId: `end-${role}`,
      reason: 'Requested assignment ending.',
    });
    assert.equal(result.action, 'committee-assignment-ended');
    assert.deepEqual(base.db.documents.get('committee_assignments/current'), {
      ...before,
      active: false,
      ended_at: SERVER_TIME,
    });
    const audit = base.db.documents.get(`audit_logs/end-${role}`);
    assert.equal(audit.action, 'committee.assignment_end');
    assert.equal(audit.actor_user_id, OPERATOR_ID);
    assert.equal(audit.target_path, 'committee_assignments/current');
    assert.deepEqual(audit.changes, {
      active: { before: true, after: false },
      ended_at: { before: null, after: SERVER_TIME },
    });
    assert.equal(base.db.documents.get(`users/${TARGET_ID}`).access_role, targetRoleBefore);
  }
});

test('executive, committee, and member cannot end assignments', async () => {
  for (const role of ['executive', 'committee', 'member']) {
    const base = fixture({ operatorRole: role, entries: [['committee_assignments/current', assignment()]] });
    const before = { ...base.db.documents.get('committee_assignments/current') };
    await rejectsCode(endCommitteeAssignment({
      ...base,
      serverTimestamp: () => SERVER_TIME,
      operatorUid: OPERATOR_UID,
      assignmentId: 'current',
      operationId: `end-${role}`,
      reason: 'Unauthorized assignment ending.',
    }), 'unauthorized');
    assert.deepEqual(base.db.documents.get('committee_assignments/current'), before);
    assert.equal(base.db.documents.has(`audit_logs/end-${role}`), false);
  }
});

test('already-ended assignment fails clearly and preserves historical position', async () => {
  const base = fixture({ entries: [['committee_assignments/history', assignment({ active: false, ended_at: TIME })]] });
  await rejectsCode(endCommitteeAssignment({
    ...base,
    serverTimestamp: () => SERVER_TIME,
    operatorUid: OPERATOR_UID,
    assignmentId: 'history',
    operationId: 'end-history',
    reason: 'Duplicate ending attempt.',
  }), 'already_ended');
  assert.equal(base.db.documents.get('committee_assignments/history').position, 'president');
  assert.equal(base.db.documents.has('audit_logs/end-history'), false);
});

test('failed end and reused operation ID leave no partial state', async () => {
  const missingParent = fixture({ entries: [['committee_assignments/current', assignment({ term_id: 'missing-term' })]] });
  const beforeMissing = { ...missingParent.db.documents.get('committee_assignments/current') };
  await rejectsCode(endCommitteeAssignment({
    ...missingParent,
    serverTimestamp: () => SERVER_TIME,
    operatorUid: OPERATOR_UID,
    assignmentId: 'current',
    operationId: 'end-missing-parent',
    reason: 'End after parent validation.',
  }), 'missing');
  assert.deepEqual(missingParent.db.documents.get('committee_assignments/current'), beforeMissing);
  assert.equal(missingParent.db.documents.has('audit_logs/end-missing-parent'), false);

  const reused = fixture({ entries: [
    ['committee_assignments/current', assignment()],
    ['audit_logs/end-reused', { action: 'other' }],
  ] });
  const beforeReused = { ...reused.db.documents.get('committee_assignments/current') };
  await rejectsCode(endCommitteeAssignment({
    ...reused,
    serverTimestamp: () => SERVER_TIME,
    operatorUid: OPERATOR_UID,
    assignmentId: 'current',
    operationId: 'end-reused',
    reason: 'Conflicting retry.',
  }), 'operation_reused');
  assert.deepEqual(reused.db.documents.get('committee_assignments/current'), beforeReused);
  assert.deepEqual(reused.db.documents.get('audit_logs/end-reused'), { action: 'other' });
});

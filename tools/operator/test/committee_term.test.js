import assert from 'node:assert/strict';
import test from 'node:test';

import { rolloverCommitteeTerm } from '../src/committee_term.js';
import { adminUser, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const OPERATOR_UID = 'operator-uid';
const OPERATOR_ID = 'operator-user';

function term(active = true, changes = {}) {
  return {
    name: '2024-2026',
    start_year: 2024,
    end_year: 2026,
    start_date: TIME,
    end_date: TIME,
    active,
    group_photo_url: null,
    created_at: TIME,
    created_by: OPERATOR_ID,
    ...changes,
  };
}

function fixture({ role = 'developer_admin', entries = [] } = {}) {
  return {
    db: new FakeFirestore([
      ['auth_links/operator-uid', { user_id: OPERATOR_ID, active: true, created_at: TIME, created_by: 'seed' }],
      [`users/${OPERATOR_ID}`, adminUser({ access_role: role })],
      ...entries,
    ]),
    auth: new FakeAuth([[OPERATOR_UID, {
      uid: OPERATOR_UID,
      email: 'operator@example.test',
      emailVerified: true,
      disabled: false,
    }]]),
  };
}

function args(base, overrides = {}) {
  return {
    ...base,
    serverTimestamp: () => SERVER_TIME,
    operatorUid: OPERATOR_UID,
    currentTermId: null,
    name: '2026-2028',
    startYear: 2026,
    endYear: 2028,
    startDate: null,
    endDate: null,
    groupPhotoUrl: null,
    operationId: 'term-rollover-1',
    reason: 'Approved committee term lifecycle operation.',
    ...overrides,
  };
}

async function rejectsCode(promise, code) {
  await assert.rejects(promise, (error) => error.code === code);
}

test('developer_admin can initialize the first exact active term atomically', async () => {
  const base = fixture();
  const result = await rolloverCommitteeTerm(args(base));
  assert.deepEqual(base.db.documents.get(`committee_terms/${result.termId}`), {
    name: '2026-2028', start_year: 2026, end_year: 2028,
    start_date: null, end_date: null, active: true, group_photo_url: null,
    created_at: SERVER_TIME, created_by: OPERATOR_ID,
  });
  assert.equal(base.db.documents.get('audit_logs/term-rollover-1').action, 'committee.term_rollover');
});

test('leader can atomically retire the single current term and create its successor', async () => {
  const base = fixture({ role: 'leader', entries: [['committee_terms/current', term()]] });
  const before = { ...base.db.documents.get('committee_terms/current') };
  const result = await rolloverCommitteeTerm(args(base, {
    currentTermId: 'current',
    groupPhotoUrl: 'https://example.test/new-term.jpg',
  }));
  assert.deepEqual(base.db.documents.get('committee_terms/current'), { ...before, active: false });
  assert.equal(base.db.documents.get(`committee_terms/${result.termId}`).active, true);
  assert.equal(base.db.documents.get(`committee_terms/${result.termId}`).group_photo_url, 'https://example.test/new-term.jpg');
});

test('lower roles cannot initialize or roll over committee terms', async () => {
  for (const role of ['executive', 'committee', 'member']) {
    const base = fixture({ role });
    await rejectsCode(rolloverCommitteeTerm(args(base, { operationId: `rollover-${role}` })), 'unauthorized');
    assert.equal([...base.db.documents.keys()].some((path) => path.startsWith('committee_terms/')), false);
  }
});

test('multiple or stale active-term state fails closed with no partial writes', async () => {
  const multiple = fixture({ entries: [
    ['committee_terms/one', term()],
    ['committee_terms/two', term()],
  ] });
  const multiplePaths = new Set(multiple.db.documents.keys());
  await rejectsCode(rolloverCommitteeTerm(args(multiple, { currentTermId: 'one' })), 'ambiguous_current_term');
  assert.deepEqual(new Set(multiple.db.documents.keys()), multiplePaths);

  const stale = fixture({ entries: [['committee_terms/current', term()]] });
  const before = { ...stale.db.documents.get('committee_terms/current') };
  await rejectsCode(rolloverCommitteeTerm(args(stale, { currentTermId: 'wrong' })), 'stale_current_term');
  assert.deepEqual(stale.db.documents.get('committee_terms/current'), before);

  const malformed = fixture({ entries: [['committee_terms/current', { active: true }]] });
  const malformedBefore = { ...malformed.db.documents.get('committee_terms/current') };
  await rejectsCode(rolloverCommitteeTerm(args(malformed, { currentTermId: 'current' })), 'malformed');
  assert.deepEqual(malformed.db.documents.get('committee_terms/current'), malformedBefore);
});

test('operation reuse and malformed term input are denied atomically', async () => {
  const reused = fixture({ entries: [
    ['committee_terms/current', term()],
    ['audit_logs/term-rollover-1', { action: 'existing' }],
    ['committee_assignments/history', { position: 'president' }],
  ] });
  const before = new Map(reused.db.documents);
  await rejectsCode(rolloverCommitteeTerm(args(reused, { currentTermId: 'current' })), 'operation_reused');
  assert.deepEqual(reused.db.documents, before);

  const invalid = fixture();
  await rejectsCode(rolloverCommitteeTerm(args(invalid, { startYear: 2029, endYear: 2028 })), 'invalid_argument');
  await rejectsCode(rolloverCommitteeTerm(args(invalid, { groupPhotoUrl: 'http://example.test/group.jpg' })), 'invalid_argument');
});

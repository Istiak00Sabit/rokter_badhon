import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  OFFICIAL_COMMITTEE_TERM_ID,
  seedOfficialCommittee,
  validateOfficialCommitteeSource,
} from '../src/official_committee.js';
import { FakeFirestore, SERVER_TIME } from './fakes.js';

const source = JSON.parse(fs.readFileSync(new URL('../../../data/committee_2025_2027.json', import.meta.url), 'utf8'));

test('reviewed official source contains exactly 51 unique identities and frozen role totals', () => {
  const rows = validateOfficialCommitteeSource(source);
  assert.equal(rows.length, 51);
  assert.equal(new Set(rows.map((row) => row.phone)).size, 51);
  assert.deepEqual(
    Object.fromEntries(['leader', 'executive', 'committee'].map((role) => [role, rows.filter((row) => row.access_role === role).length])),
    { leader: 2, executive: 31, committee: 18 },
  );
  assert.ok(rows.filter((row) => row.position === 'সদস্য').every((row) => row.access_role === 'committee'));
  assert.ok(rows.every((row) => row.access_role !== 'developer_admin'));
});

test('emulator preload creates 51 Users and exact assignments without Auth identities and is idempotent', async () => {
  const db = new FakeFirestore();
  const first = await seedOfficialCommittee({
    projectId: 'demo-rokter-badhon', db, serverTimestamp: () => SERVER_TIME, rows: source,
  });
  assert.equal(first.createdUsers, 51);
  assert.equal(first.createdAssignments, 51);
  assert.equal([...db.documents.keys()].filter((key) => key.startsWith('users/')).length, 51);
  assert.equal([...db.documents.keys()].filter((key) => key.startsWith('user_directory/')).length, 51);
  assert.equal([...db.documents.keys()].filter((key) => key.startsWith('committee_assignments/')).length, 51);
  assert.equal(db.documents.get(`committee_terms/${OFFICIAL_COMMITTEE_TERM_ID}`).name, '2025-2027');
  for (const row of source) {
    const suffix = String(row.serial).padStart(3, '0');
    const user = db.documents.get(`users/committee-2025-2027-${suffix}`);
    const assignment = db.documents.get(`committee_assignments/2025-2027-${suffix}`);
    assert.equal(user.name, row.name);
    assert.equal(user.phone, row.phone);
    assert.equal(user.profession, row.profession);
    assert.equal(user.blood_group, row.blood_group);
    assert.equal(user.access_role, row.access_role);
    assert.equal(user.login_enabled, false);
    assert.equal(user.email, null);
    assert.equal(assignment.position, row.position);
    assert.equal(assignment.user_id, `committee-2025-2027-${suffix}`);
    assert.equal(assignment.term_id, OFFICIAL_COMMITTEE_TERM_ID);
  }
  const second = await seedOfficialCommittee({
    projectId: 'demo-rokter-badhon', db, serverTimestamp: () => SERVER_TIME, rows: source,
  });
  assert.equal(second.action, 'official_committee_already_seeded');
  assert.equal(second.createdUsers, 0);
  assert.equal(second.createdAssignments, 0);
  assert.equal([...db.documents.keys()].length, 154);
});

test('preload fails closed on duplicate identity, conflicting records, and non-demo projects', async () => {
  const duplicated = structuredClone(source);
  duplicated[1].phone = duplicated[0].phone;
  assert.throws(() => validateOfficialCommitteeSource(duplicated), (error) => error.code === 'duplicate_identity');

  const db = new FakeFirestore([['users/unrelated', {
    name: 'Unrelated', phone: source[0].phone,
  }]]);
  await assert.rejects(
    seedOfficialCommittee({ projectId: 'demo-rokter-badhon', db, serverTimestamp: () => SERVER_TIME, rows: source }),
    (error) => error.code === 'duplicate_identity',
  );
  await assert.rejects(
    seedOfficialCommittee({ projectId: 'production-project', db: new FakeFirestore(), serverTimestamp: () => SERVER_TIME, rows: source }),
    (error) => error.code === 'unsafe_target',
  );
  await assert.rejects(
    seedOfficialCommittee({ projectId: 'rokterbadhon-b247b', db: new FakeFirestore(), serverTimestamp: () => SERVER_TIME, rows: source }),
    (error) => error.code === 'unsafe_target',
  );
});

test('explicit trusted production import creates directory-only members safely', async () => {
  const db = new FakeFirestore();
  const args = {
    projectId: 'rokterbadhon-b247b',
    db,
    serverTimestamp: () => SERVER_TIME,
    rows: source,
    allowProduction: true,
  };
  const first = await seedOfficialCommittee(args);
  assert.equal(first.createdUsers, 51);
  assert.equal(first.createdAssignments, 51);
  const leader = db.documents.get('users/committee-2025-2027-001');
  assert.equal(leader.login_enabled, false);
  assert.equal(leader.access_role, 'leader');
  assert.equal(
    db.documents.get('committee_assignments/2025-2027-001').assigned_by,
    'trusted-operator-official-committee-import',
  );
  const retry = await seedOfficialCommittee(args);
  assert.equal(retry.createdUsers, 0);
  assert.equal(retry.createdAssignments, 0);
});

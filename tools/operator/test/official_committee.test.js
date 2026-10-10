import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  OFFICIAL_COMMITTEE_TERM_ID,
  assertOfficialCommitteeProductionIntent,
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

test('bundled app preview is byte-identical to approved official roster', () => {
  const bundled = fs.readFileSync(
    new URL('../../../assets/data/committee_2025_2027.json', import.meta.url),
    'utf8',
  );
  const canonical = fs.readFileSync(
    new URL('../../../data/committee_2025_2027.json', import.meta.url),
    'utf8',
  );
  assert.equal(bundled, canonical);
});

test('owner-approved president and general secretary cannot be replaced, reordered or promoted', () => {
  const leaders = source.filter(row => row.access_role === 'leader');
  assert.deepEqual(leaders.map(row => ({
    serial: row.serial, position: row.position, name: row.name,
  })), [
    { serial: 1, position: 'সভাপতি', name: 'মোঃ আনোয়ার হোসাইন' },
    { serial: 9, position: 'সাধারণ সম্পাদক', name: 'মোঃ সৈকত হাসান' },
  ]);
  for (const change of [
    rows => { rows[0].access_role = 'executive'; rows[1].access_role = 'leader'; },
    rows => { rows[8].name = 'Unreviewed Name'; },
    rows => { rows[8].position = 'সভাপতি'; },
    rows => { rows[3].access_role = 'leader'; rows[8].access_role = 'executive'; },
    rows => { rows[9].phone = '12345'; },
    rows => { rows[9].blood_group = 'X+'; },
  ]) {
    const modified = structuredClone(source);
    change(modified);
    assert.throws(() => validateOfficialCommitteeSource(modified),
      (error) => ['invalid_source', 'invalid_role_mapping'].includes(error.code));
  }
});

test('official live import requires all explicit human confirmations before Firebase', () => {
  const valid = {
    'allow-production': 'true',
    'confirm-command': 'seed-official-committee',
    'confirm-roster': '51:2:31:18',
    'confirm-leaders': '001,009',
    'acknowledge-no-login': 'true',
    reason: 'Organization owner authorized a reviewed committee import',
  };
  assert.equal(
    assertOfficialCommitteeProductionIntent(valid),
    valid.reason,
  );
  for (const [key, unexpected] of [
    ['allow-production', 'false'],
    ['confirm-command', 'approve'],
    ['confirm-roster', '51:3:30:18'],
    ['confirm-leaders', '001,049'],
    ['acknowledge-no-login', 'false'],
    ['reason', 'short'],
    ['reason', ' untrimmed reviewed import '],
  ]) {
    assert.throws(
      () => assertOfficialCommitteeProductionIntent({ ...valid, [key]: unexpected }),
      (error) => error.code === 'production_confirmation_required',
    );
  }
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
  // Even when the private Users collection has no conflicting phone, the
  // directory may hold an existing entry created through an older workflow.
  const directoryCollision = new FakeFirestore([['user_directory/unrelated', {
    name: 'Synthetic Previous Member', phone: source[0].phone,
  }]]);
  await assert.rejects(
    seedOfficialCommittee({
      projectId: 'demo-rokter-badhon', db: directoryCollision,
      serverTimestamp: () => SERVER_TIME, rows: source,
    }),
    (error) => error.code === 'duplicate_identity',
  );
  assert.equal(
    [...directoryCollision.documents.keys()].filter(path => path.startsWith('committee_assignments/')).length,
    0,
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
  const first = await seedOfficialCommittee({
    ...args, auditReason: 'Owner reviewed 51 committee members and accepted no-login import',
  });
  assert.equal(first.createdUsers, 51);
  assert.equal(first.createdAssignments, 51);
  const leader = db.documents.get('users/committee-2025-2027-001');
  assert.equal(leader.login_enabled, false);
  assert.equal(leader.access_role, 'leader');
  assert.equal(
    db.documents.get('committee_assignments/2025-2027-001').assigned_by,
    'trusted-operator-official-committee-import',
  );
  assert.equal(
    [...db.documents.keys()].filter((key) => key.startsWith('audit_logs/')).length,
    51,
  );
  assert.equal(
    db.documents.get('audit_logs/official-committee-2025-2027-001').action,
    'committee.member_seed',
  );
  assert.equal(
    db.documents.get('audit_logs/official-committee-2025-2027-001').reason,
    'Owner reviewed 51 committee members and accepted no-login import',
  );
  const retry = await seedOfficialCommittee(args);
  assert.equal(retry.createdUsers, 0);
  assert.equal(retry.createdAssignments, 0);
});

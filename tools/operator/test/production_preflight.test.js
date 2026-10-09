import assert from 'node:assert/strict';
import test from 'node:test';

import { FakeFirestore, FakeAuth, SERVER_TIME } from './fakes.js';
import { internalAuthEmailForPhone } from '../src/auth_identity.js';
import { loadOfficialCommitteeSource, seedOfficialCommittee } from '../src/official_committee.js';
import {
  inspectCommitteeImport,
  classifyRegistrationIdentity,
} from '../src/production_preflight.js';

const rows = loadOfficialCommitteeSource();

test('read-only preflight approves an empty demo and does not modify records', async () => {
  const db = new FakeFirestore();
  const auth = new FakeAuth();
  const result = await inspectCommitteeImport({
    projectId: 'demo-rokter-badhon', db, auth, rows,
  });
  assert.equal(result.mode, 'READ_ONLY');
  assert.equal(result.safeToConsiderImport, true);
  assert.equal(result.counts.source, 51);
  assert.equal(result.counts.existingUsers, 0);
  assert.equal(result.wouldCreateUsers, 51);
  assert.equal(db.documents.size, 0);
  assert.equal(auth.users.size, 0);
  assert.equal(JSON.stringify(result).includes(rows[0].phone), false);
});

test('read-only preflight sees fully seeded demo without writing', async () => {
  const db = new FakeFirestore();
  await seedOfficialCommittee({
    projectId: 'demo-rokter-badhon',
    db, serverTimestamp: () => SERVER_TIME, rows,
  });
  const before = [...db.documents.entries()];
  const result = await inspectCommitteeImport({
    projectId: 'demo-rokter-badhon', db, auth: new FakeAuth(), rows,
  });
  assert.equal(result.safeToConsiderImport, true);
  assert.equal(result.counts.existingUsers, 51);
  assert.equal(result.counts.existingDirectories, 51);
  assert.equal(result.counts.existingAssignments, 51);
  assert.equal(result.wouldCreateUsers, 0);
  assert.deepEqual([...db.documents.entries()], before);
});

test('read-only preflight detects preexisting phone ownership and active-term conflicts', async () => {
  const db = new FakeFirestore([
    ['users/unrelated', { phone: rows[0].phone }],
    ['user_directory/unrelated', { phone: rows[1].phone }],
    ['committee_terms/another', { active: true }],
  ]);
  const result = await inspectCommitteeImport({
    projectId: 'demo-rokter-badhon', db, auth: new FakeAuth(), rows,
  });
  assert.equal(result.safeToConsiderImport, false);
  assert.ok(result.blockers.some((b) => b.code === 'phone_already_in_use'));
  assert.ok(result.blockers.some((b) => b.code === 'another_active_term'));
  assert.equal(JSON.stringify(result).includes(rows[0].phone), false);
});

test('preflight recognizes trusted production-import audit state on rerun', async () => {
  const db = new FakeFirestore();
  await seedOfficialCommittee({
    projectId: 'rokterbadhon-b247b',
    db, serverTimestamp: () => SERVER_TIME, rows, allowProduction: true,
  });
  const result = await inspectCommitteeImport({
    projectId: 'rokterbadhon-b247b', db, auth: new FakeAuth(), rows,
  });
  assert.equal(result.safeToConsiderImport, true);
  assert.equal(result.counts.existingImportAudits, 51);
  assert.equal(result.wouldCreateAssignments, 0);
});

test('preflight blocks existing committee User missing import audit', async () => {
  const db = new FakeFirestore();
  await seedOfficialCommittee({
    projectId: 'rokterbadhon-b247b',
    db, serverTimestamp: () => SERVER_TIME, rows, allowProduction: true,
  });
  db.documents.delete('audit_logs/official-committee-2025-2027-001');
  const result = await inspectCommitteeImport({
    projectId: 'rokterbadhon-b247b', db, auth: new FakeAuth(), rows,
  });
  assert.equal(result.safeToConsiderImport, false);
  assert.ok(result.blockers.some((b) =>
    b.serial === 1 && b.code === 'existing_user_missing_import_audit'));
});

test('preflight reports existing Firebase phone-auth identities without creating accounts', async () => {
  const email = internalAuthEmailForPhone(rows[0].phone);
  const auth = new FakeAuth([['old-id', { uid: 'old-id', email, disabled: false }]]);
  const result = await inspectCommitteeImport({
    projectId: 'demo-rokter-badhon',
    db: new FakeFirestore(), auth, rows,
  });
  assert.equal(result.counts.existingPhoneAuthIdentities, 1);
  assert.equal(auth.users.size, 1);
});

test('legacy registration identity classification is safe and does not migrate', () => {
  const phone = '01700000000';
  assert.equal(classifyRegistrationIdentity({
    phone, authEmail: internalAuthEmailForPhone(phone),
  }), 'phone_identity');
  assert.equal(classifyRegistrationIdentity({
    phone, authEmail: 'old-address@example.test',
  }), 'legacy_email_identity');
  assert.equal(classifyRegistrationIdentity({
    phone, authEmail: 'old-address@example.test', authDisabled: true,
  }), 'disabled_auth');
  assert.equal(classifyRegistrationIdentity({
    phone, authEmail: null,
  }), 'missing_auth_email');
  assert.equal(classifyRegistrationIdentity({
    phone: 'invalid-phone', authEmail: 'old-address@example.test',
  }), 'invalid_registration_phone');
});

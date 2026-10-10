import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { provisionCommitteeAccounts } from '../src/committee_provisioning.js';
import { internalAuthEmailForPhone } from '../src/auth_identity.js';
import { validateOfficialCommitteeSource } from '../src/official_committee.js';
import { FakeAuth, FakeFirestore, SERVER_TIME } from './fakes.js';

const sourcePath = path.resolve('..', '..', 'data', 'committee_2025_2027.json');
const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));

function tempFile(name) {
  return path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'rokter-provision-')), name);
}

test('committee role values are independent of nonleader positions; approved leaders stay fixed', () => {
  const changed = structuredClone(source);
  // Only the two reviewed leaders have frozen position/name/role; another
  // position label must not implicitly confer access_role=leader.
  changed[1].position = 'ordinary member title';
  const rows = validateOfficialCommitteeSource(changed);
  assert.equal(rows.length, 51);
  assert.equal(rows[1].access_role, 'executive');
  assert.equal(rows[0].access_role, 'leader');
  assert.equal(rows[8].access_role, 'leader');
});

test('committee provisioning creates strict Auth, User, directory, link, assignment, and audit records', async () => {
  const credentialsFile = tempFile('credentials.json');
  const db = new FakeFirestore();
  const auth = new FakeAuth();
  const result = await provisionCommitteeAccounts({
    projectId: 'rokterbadhon-b247b',
    file: sourcePath,
    credentialsFile,
    db,
    auth,
    serverTimestamp: () => SERVER_TIME,
    operationId: 'committee-provision-test',
  });

  assert.equal(result.detected, 51);
  assert.equal(result.created.length, 51);
  assert.equal(result.alreadyExistingReused.length, 0);
  assert.equal(result.conflict.length, 0);
  assert.equal(auth.users.size, 51);
  assert.equal([...db.documents.keys()].filter((key) => key.startsWith('users/')).length, 51);
  assert.equal([...db.documents.keys()].filter((key) => key.startsWith('user_directory/')).length, 51);
  assert.equal([...db.documents.keys()].filter((key) => key.startsWith('auth_links/')).length, 51);
  assert.equal([...db.documents.keys()].filter((key) => key.startsWith('committee_assignments/')).length, 51);
  assert.equal([...db.documents.keys()].filter((key) => key.startsWith('audit_logs/')).length, 51);
  assert.equal(db.documents.get('users/committee-2025-2027-001').access_role, 'leader');
  assert.equal(db.documents.get('users/committee-2025-2027-001').email, null);
  assert.equal(db.documents.get('users/committee-2025-2027-001').login_enabled, true);
  assert.equal(db.documents.get('committee_assignments/2025-2027-001').position, source[0].position);
  assert.equal(db.documents.get('audit_logs/committee-provision-test-001').changes.password, undefined);

  const credentials = JSON.parse(fs.readFileSync(credentialsFile, 'utf8'));
  assert.equal(credentials.entries.length, 51);
  assert.ok(credentials.entries.every((entry) => entry.temporary_password.length >= 6));
  assert.ok(!JSON.stringify(db.documents).includes('temporary_password'));

  const retry = await provisionCommitteeAccounts({
    projectId: 'rokterbadhon-b247b', file: sourcePath, db, auth,
    serverTimestamp: () => SERVER_TIME, operationId: 'committee-provision-test',
  });
  assert.equal(retry.created.length, 0);
  assert.equal(retry.alreadyExistingReused.length, 51);
  assert.equal(retry.conflict.length, 0);
});

test('existing Auth password is never reset automatically and a conflicting phone fails closed', async () => {
  const db = new FakeFirestore();
  const auth = new FakeAuth([
    ['existing-auth', {
      uid: 'existing-auth',
      email: internalAuthEmailForPhone(source[0].phone),
      password: 'operator-owned-password',
      emailVerified: false,
      disabled: false,
    }],
  ]);
  db.documents.set('users/different-user', {
    name: 'Different', phone: source[1].phone, email: null, blood_group: null,
    profession: null, address: null, photo_url: null, access_role: 'member',
    active: true, login_enabled: true, preferred_language: null,
    created_at: SERVER_TIME, created_by: null, updated_at: SERVER_TIME, updated_by: null,
  });
  const result = await provisionCommitteeAccounts({
    projectId: 'rokterbadhon-b247b', file: sourcePath, db, auth,
    serverTimestamp: () => SERVER_TIME, operationId: 'committee-conflict-test',
  });
  assert.equal(auth.users.get('existing-auth').password, 'operator-owned-password');
  assert.ok(result.conflict.some((item) => item.serial === 2));
  assert.ok(result.created.length >= 49);
});

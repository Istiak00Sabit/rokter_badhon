import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assertProtectedProductionCommand,
  isProtectedProductionCommand,
} from '../src/protected_production_commands.js';
import { assertSafeTarget } from '../src/safety.js';

const credentials = '/private/operator/firebase-service-account.json';
const projectId = 'rokterbadhon-b247b';
const base = Object.freeze({
  'allow-production': 'true',
  'confirm-project-id': projectId,
  'operation-id': 'review-registration-20261010-001',
  reason: 'Verified applicant with organization office',
  'operator-uid': 'trusted-auth-uid',
  'applicant-uid': 'applicant-auth-uid',
  'confirm-applicant-uid': 'applicant-auth-uid',
  'confirm-operator-uid': 'trusted-auth-uid',
  'target-role': 'member',
});

function check(command, changes = {}, credentialPath = credentials) {
  return assertProtectedProductionCommand({
    command,
    options: {
      ...base,
      'confirm-command': command,
      ...changes,
    },
    explicitCredentialPath: credentialPath,
  });
}

function rejected(command, changes = {}, credentialPath = credentials) {
  assert.throws(
    () => check(command, changes, credentialPath),
    (error) => error.code === 'production_confirmation_required' ||
      error.code === 'invalid_argument',
  );
}

test('the production command allowlist does not grow to generic write actions', () => {
  for (const command of ['approve', 'reject', 'link-registration', 'bootstrap-developer-admin']) {
    assert.equal(isProtectedProductionCommand(command), true);
  }
  for (const command of [
    'assign-role', 'create-user', 'disable-user', 'recover-developer-admin',
    'create-auth-link', 'seed-test-admin', 'create-event', 'create-notice',
    'record-donation', 'deactivate-donor', 'unknown-operation',
  ]) {
    assert.equal(isProtectedProductionCommand(command), false);
    rejected(command);
  }
});

test('production approval must confirm project, action, both identities and member role', () => {
  assert.doesNotThrow(() => check('approve'));
  assert.doesNotThrow(() => assertSafeTarget({
    projectId,
    mode: 'provision',
    allowProduction: true,
    confirmedProjectId: projectId,
    firestoreEmulatorHost: '',
    authEmulatorHost: '',
  }));

  for (const changes of [
    { 'allow-production': undefined },
    { 'allow-production': 'false' },
    { 'confirm-command': 'reject' },
    { 'operator-uid': undefined },
    { 'operator-uid': 'attacker' },
    { 'applicant-uid': 'unexpected' },
    { 'confirm-applicant-uid': undefined },
    { 'confirm-operator-uid': undefined },
    { 'target-role': 'leader' },
    { 'target-role': 'developer_admin' },
    { 'target-role': undefined },
    { 'operation-id': '' },
    { 'operation-id': 'invalid/id' },
    { reason: 'short' },
    { reason: '' },
    { 'operator-uid': 'applicant-auth-uid', 'confirm-operator-uid': 'applicant-auth-uid' },
  ]) {
    rejected('approve', changes);
  }
  rejected('approve', {}, '');
});

test('rejection has the same identity, audit and credential gates', () => {
  assert.doesNotThrow(() => check('reject', { 'target-role': undefined }));
  rejected('reject', { 'confirm-command': 'approve' });
  rejected('reject', { 'confirm-applicant-uid': 'someone-else' });
  rejected('reject', { reason: 'x' });
  rejected('reject', {}, null);
});

test('linking an applicant to an existing User demands a third confirmed ID', () => {
  assert.doesNotThrow(() => check('link-registration', {
    'target-role': undefined,
    'target-user-id': 'existing-member-id',
    'confirm-target-user-id': 'existing-member-id',
  }));
  rejected('link-registration', { 'target-user-id': 'existing-member-id' });
  rejected('link-registration', {
    'target-user-id': 'existing-member-id',
    'confirm-target-user-id': 'different-id',
  });
});

test('first administrator bootstrap requires exact Auth UID and separate acknowledgement', () => {
  assert.doesNotThrow(() => check('bootstrap-developer-admin', {
    'operator-uid': undefined,
    'applicant-uid': undefined,
    'auth-uid': 'candidate-auth-uid',
    'confirm-auth-uid': 'candidate-auth-uid',
    'confirm-first-admin': 'true',
  }));
  rejected('bootstrap-developer-admin', { 'auth-uid': 'candidate-auth-uid' });
  rejected('bootstrap-developer-admin', {
    'auth-uid': 'candidate-auth-uid',
    'confirm-auth-uid': 'other-id',
    'confirm-first-admin': 'true',
  });
  rejected('bootstrap-developer-admin', {
    'auth-uid': 'candidate-auth-uid',
    'confirm-auth-uid': 'candidate-auth-uid',
    'confirm-first-admin': 'false',
  });
});

test('general Firestore/Auth commands cannot obtain production access through the target guard', () => {
  assert.throws(() => assertSafeTarget({
    projectId,
    mode: 'emulator',
    allowProduction: true,
    confirmedProjectId: projectId,
    firestoreEmulatorHost: '',
    authEmulatorHost: '',
  }), (error) => error.code === 'unsafe_target');

  assert.throws(() => assertSafeTarget({
    projectId,
    mode: 'provision',
    allowProduction: true,
    confirmedProjectId: projectId,
    firestoreEmulatorHost: 'localhost:8080',
    authEmulatorHost: '',
  }), (error) => error.code === 'unsafe_target');

  assert.throws(() => assertSafeTarget({
    projectId: 'wrong-project',
    mode: 'provision',
    allowProduction: true,
    confirmedProjectId: 'wrong-project',
    firestoreEmulatorHost: '',
    authEmulatorHost: '',
  }), (error) => error.code === 'unsafe_target');
});

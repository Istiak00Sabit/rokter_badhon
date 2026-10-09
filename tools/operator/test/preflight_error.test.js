import assert from 'node:assert/strict';
import test from 'node:test';

import { classifyPreflightError } from '../src/preflight_error.js';

test('Firestore permission denied numeric gRPC error is classified without leaking message', () => {
  const actual = classifyPreflightError({
    code: 7,
    message: 'Sensitive email and Authorization: Bearer SECRET',
  });
  assert.deepEqual(actual, {
    code: 'grpc_permission_denied', status: 7,
    category: 'credentials_or_permissions',
  });
  assert.equal(JSON.stringify(actual).includes('SECRET'), false);
});

test('expired auth, internal, unavailable and deadline gRPC statuses distinguish causes', () => {
  assert.equal(classifyPreflightError({ code: 16 }).code, 'grpc_unauthenticated');
  assert.equal(classifyPreflightError({ code: 13 }).code, 'grpc_internal');
  assert.equal(classifyPreflightError({ code: 14 }).category, 'network_or_service');
  assert.equal(classifyPreflightError({ code: 4 }).code, 'grpc_deadline_exceeded');
});

test('a nested impersonation error is classified and redacted', () => {
  const actual = classifyPreflightError({
    cause: { message: 'generateAccessToken failed for private-secret account' },
  });
  assert.equal(actual.code, 'credential_impersonation_failure');
  assert.equal(actual.category, 'credentials_or_permissions');
  assert.equal(JSON.stringify(actual).includes('private-secret'), false);
});

test('known Admin Auth codes and unknown SDK errors cannot disclose PII', () => {
  assert.equal(
    classifyPreflightError({ code: 'auth/internal-error', message: 'Private user phone' }).code,
    'auth/internal-error',
  );
  const actual = classifyPreflightError(new Error('Sensitive arbitrary custom message'));
  assert.equal(actual.code, 'unclassified_sdk_error');
  assert.equal(JSON.stringify(actual).includes('Sensitive'), false);
});

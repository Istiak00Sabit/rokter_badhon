import assert from 'node:assert/strict';
import test from 'node:test';

import { assertSafeTarget } from '../src/safety.js';

test('allows only an explicit demo project with both emulators', () => {
  assert.doesNotThrow(() => assertSafeTarget({
    projectId: 'demo-rokter-badhon',
    firestoreEmulatorHost: '127.0.0.1:8080',
    authEmulatorHost: '127.0.0.1:9099',
  }));
});

test('refuses production-like projects and missing emulator hosts', () => {
  for (const input of [
    { projectId: 'rokter-badhon-prod', firestoreEmulatorHost: 'x', authEmulatorHost: 'y' },
    { projectId: 'demo-rokter-badhon', firestoreEmulatorHost: '', authEmulatorHost: 'y' },
    { projectId: 'demo-rokter-badhon', firestoreEmulatorHost: 'x', authEmulatorHost: '' },
  ]) {
    assert.throws(() => assertSafeTarget(input), (error) => error.code === 'unsafe_target');
  }
});

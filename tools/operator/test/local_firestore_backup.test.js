import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile, mkdtemp, rm, writeFile, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createDecipheriv, scryptSync } from 'node:crypto';

import {
  discoverFirestoreRecords,
  makeFirestoreReader,
  writeEncryptedFirestoreBackup,
  verifyEncryptedFirestoreBackup,
} from '../src/local_firestore_backup.js';

const PROJECT = 'demo-rokter-backup';
const ROOT = 'projects/' + PROJECT + '/databases/(default)/documents';
const PASSWORD = 'very-long-password-for-safe-backup';
const USERS = ROOT + '/users';
const MAIN = USERS + '/first';
const MISSING = USERS + '/missing';
const SUB = MAIN + '/donations';
const SUB_MISSING = MISSING + '/receipts';

const document = {
  name: MAIN,
  createTime: '2026-10-01T00:00:00.000Z',
  updateTime: '2026-10-01T00:00:00.000Z',
  fields: {
    name: { stringValue: 'Private Person Name' },
    largeInt: { integerValue: '90071992547409931' },
    rating: { doubleValue: 3.5 },
    created: { timestampValue: '2026-10-01T00:00:00.123456Z' },
    photo: { bytesValue: 'AQIDBA==' },
    point: { geoPointValue: { latitude: 23.5, longitude: 90.0 } },
    ref: { referenceValue: ROOT + '/users/other' },
    map: { mapValue: { fields: { exists: { booleanValue: true } } } },
    array: { arrayValue: { values: [{ nullValue: null }, { stringValue: 'yes' }] } },
  },
};

function fakeReader() {
  const requests = [];
  async function request(args) {
    requests.push(args);
    if (args.operation === 'listCollectionIds') {
      if (args.parent === ROOT) {
        return args.pageToken
          ? { collectionIds: ['notices'] }
          : { collectionIds: ['users'], nextPageToken: 'collection-next' };
      }
      if (args.parent === MAIN) return { collectionIds: ['donations'] };
      if (args.parent === MISSING) return { collectionIds: ['receipts'] };
      return {};
    }
    if (args.parent === ROOT && args.collectionId === 'users') {
      return args.pageToken
        ? { documents: [{ name: MISSING }] }
        : { documents: [document], nextPageToken: 'second-user-page' };
    }
    if (args.parent === MAIN && args.collectionId === 'donations') {
      return { documents: [{
        name: SUB + '/first',
        updateTime: '2026-10-01T00:00:00Z',
        fields: { amount: { integerValue: '42' } },
      }] };
    }
    if (args.parent === MISSING && args.collectionId === 'receipts') {
      return { documents: [{
        name: SUB_MISSING + '/second',
        updateTime: '2026-10-02T00:00:00Z',
        fields: { flag: { booleanValue: false } },
      }] };
    }
    return { documents: [] };
  }
  return { request, requests };
}

test('recursively traverses every paginated collection and missing parent', async () => {
  const { request, requests } = fakeReader();
  const entries = [];
  for await (const entry of discoverFirestoreRecords({ projectId: PROJECT, request })) {
    entries.push(entry);
  }
  assert.equal(entries.filter((x) => x.kind === 'document').length, 4);
  assert.equal(entries.filter((x) => x.kind === 'collection').length, 4);
  assert.equal(entries.filter((x) => x.missing).length, 1);
  assert.ok(entries.some((x) => x.document?.fields?.largeInt?.integerValue === '90071992547409931'));
  assert.ok(requests.every((r) => ['listDocuments', 'listCollectionIds'].includes(r.operation)));
  assert.ok(requests.filter((r) => r.operation === 'listDocuments')
    .every((r) => r.showMissing === true));
});

test('encrypted archive has zero plaintext on disk, verifies and retains raw typed values', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'rb-backup-test-'));
  const file = join(dir, 'firestore-test.rbfsenc');
  try {
    const { request } = fakeReader();
    const result = await writeEncryptedFirestoreBackup({
      projectId: PROJECT, destination: file, passphrase: PASSWORD, request,
    });
    assert.equal(result.verified, true);
    assert.equal(result.documents, 4);
    assert.equal(result.missingParents, 1);
    assert.equal(result.collections, 4);
    assert.equal(result.snapshotConsistent, false);
    assert.deepEqual(
      (await verifyEncryptedFirestoreBackup({
        file, passphrase: PASSWORD, expectedProjectId: PROJECT,
      })).documents,
      4,
    );

    const bytes = await readFile(file);
    assert.ok(!bytes.includes(Buffer.from('Private Person Name')));
    assert.ok(!bytes.includes(Buffer.from('90071992547409931')));
    assert.ok(!bytes.includes(Buffer.from(PASSWORD)));
    assert.ok(bytes.subarray(0, 8).equals(Buffer.from('RBFSENC1')));

    // Decrypt in the test process only; do not write unencrypted output.
    const salt = bytes.subarray(8, 24);
    const iv = bytes.subarray(24, 36);
    const key = scryptSync(PASSWORD, salt, 32, {
      N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024,
    });
    const decipher = createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(bytes.subarray(bytes.length - 16));
    const clear = Buffer.concat([
      decipher.update(bytes.subarray(36, bytes.length - 16)),
      decipher.final(),
    ]).toString('utf8');
    const restoredDocument = clear.split('\n').filter(Boolean)
      .map((line) => JSON.parse(line))
      .find((record) => record.kind === 'document' && record.document.name === MAIN);
    assert.deepEqual(restoredDocument.document.fields, document.fields);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('wrong passphrase and modified ciphertext fail authenticated verification', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'rb-backup-test-'));
  const file = join(dir, 'test.rbfsenc');
  try {
    const { request } = fakeReader();
    await writeEncryptedFirestoreBackup({
      projectId: PROJECT, destination: file, passphrase: PASSWORD, request,
    });
    await assert.rejects(() => verifyEncryptedFirestoreBackup({
      file, passphrase: 'different-long-password', expectedProjectId: PROJECT,
    }));
    const damaged = await readFile(file);
    damaged[damaged.length - 25] ^= 0x20;
    await writeFile(file, damaged);
    await assert.rejects(() => verifyEncryptedFirestoreBackup({
      file, passphrase: PASSWORD, expectedProjectId: PROJECT,
    }));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('failed export removes partial file without any Firestore mutations', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'rb-backup-test-'));
  const file = join(dir, 'test.rbfsenc');
  const ops = [];
  try {
    await assert.rejects(() => writeEncryptedFirestoreBackup({
      projectId: PROJECT, destination: file, passphrase: PASSWORD,
      request: async ({ operation }) => {
        ops.push(operation);
        throw new Error('Synthetic read failure');
      },
    }));
    await assert.rejects(() => stat(file), { code: 'ENOENT' });
    await assert.rejects(() => stat(file + '.partial'), { code: 'ENOENT' });
    assert.ok(ops.every((operation) => operation === 'listCollectionIds'));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('REST reader uses only fixed Google Firestore read endpoints and hides errors', async () => {
  const seen = [];
  const request = makeFirestoreReader({
    getAccessToken: async () => 'never-print-this-secret-token',
    fetchImpl: async (url, options) => {
      seen.push({ url, options });
      return { ok: true, json: async () => ({ collectionIds: [] }) };
    },
  });
  await request({
    operation: 'listCollectionIds', method: 'POST',
    parent: 'projects/rokterbadhon-b247b/databases/(default)/documents', pageSize: 50,
  });
  await request({
    operation: 'listDocuments', method: 'GET',
    parent: 'projects/rokterbadhon-b247b/databases/(default)/documents',
    collectionId: 'data', pageSize: 50, showMissing: true,
  });
  assert.equal(seen.length, 2);
  assert.ok(seen.every((x) => x.url.startsWith('https://firestore.googleapis.com/v1/')));
  assert.ok(seen.every((x) => x.options.redirect === 'error'));
  assert.equal(seen[0].options.method, 'POST');
  assert.equal(seen[1].options.method, 'GET');
  assert.equal(seen[1].options.body, undefined);
  assert.ok(!JSON.stringify(seen.map((x) => x.url)).includes('never-print'));
  const failingRequest = makeFirestoreReader({
    getAccessToken: async () => 'never-print-this-secret-token',
    fetchImpl: async () => ({ ok: false, status: 403 }),
  });
  await assert.rejects(() => failingRequest({
    operation: 'listCollectionIds', method: 'POST',
    parent: 'projects/rokterbadhon-b247b/databases/(default)/documents', pageSize: 50,
  }), /HTTP 403/);
});

test('Firestore pagination token repetition fails instead of looping forever', async () => {
  const request = async () => ({ collectionIds: ['users'], nextPageToken: 'same' });
  await assert.rejects(async () => {
    for await (const ignored of discoverFirestoreRecords({ projectId: PROJECT, request })) {
      void ignored;
    }
  }, /repeated pagination token/);
});

test('an already existing incomplete backup is never overwritten or deleted', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'rb-backup-test-'));
  const file = join(dir, 'existing.rbfsenc');
  try {
    await writeFile(file + '.partial', 'KEEP THIS INCOMPLETE BACKUP');
    const { request } = fakeReader();
    await assert.rejects(() => writeEncryptedFirestoreBackup({
      projectId: PROJECT,
      destination: file,
      passphrase: PASSWORD,
      request,
    }));
    assert.equal((await readFile(file + '.partial')).toString(), 'KEEP THIS INCOMPLETE BACKUP');
    await assert.rejects(() => stat(file), { code: 'ENOENT' });
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

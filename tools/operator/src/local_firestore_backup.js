// Read-only Firestore REST export with authenticated AES-256-GCM encryption.
// All exported document values remain in the Firestore REST typed JSON format.
// No unencrypted backup content, Auth users, passwords or access tokens are logged.
import { randomBytes, scrypt as scryptCallback, createCipheriv, createDecipheriv, createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { createReadStream, createWriteStream } from 'node:fs';
import { mkdir, open, rename, rm, stat } from 'node:fs/promises';
import { dirname } from 'node:path';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { StringDecoder } from 'node:string_decoder';

const scrypt = promisify(scryptCallback);
const MAGIC = Buffer.from('RBFSENC1');
const SALT_LENGTH = 16;
const IV_LENGTH = 12;
const TAG_LENGTH = 16;
const HEADER_LENGTH = MAGIC.length + SALT_LENGTH + IV_LENGTH;
const KDF_PARAMS = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
const PAGE_SIZE = 50;
const PROJECT = 'rokterbadhon-b247b';
const DB_NAME = '(default)';

export function firestoreRoot(projectId = PROJECT) {
  if (projectId !== PROJECT && !projectId.startsWith('demo-')) {
    throw new Error('Backup restricted to the reviewed Firebase project.');
  }
  return 'projects/' + projectId + '/databases/' + DB_NAME + '/documents';
}

function validSecret(secret) {
  if (typeof secret !== 'string' || secret.length < 16 || secret.length > 1024) {
    throw new Error('Use a private backup passphrase of 16–1024 characters.');
  }
  return secret;
}

async function keyFor(passphrase, salt) {
  return scrypt(validSecret(passphrase), salt, 32, KDF_PARAMS);
}

function safePageToken(token, seen) {
  if (!token) return false;
  if (typeof token !== 'string' || token.length > 8192 || seen.has(token)) {
    throw new Error('Firestore returned an invalid or repeated pagination token.');
  }
  seen.add(token);
  return true;
}

function ensureResourceName(root, parent, collectionId, doc) {
  if (typeof doc?.name !== 'string' ||
      !doc.name.startsWith(parent + '/' + collectionId + '/')) {
    throw new Error('Unexpected Firestore document resource.');
  }
  const relative = doc.name.slice(root.length + 1);
  const parts = relative.split('/');
  if (parts.length < 2 || parts.length % 2 !== 0 ||
      parts.some((part) => !part)) {
    throw new Error('Invalid Firestore document path.');
  }
  if (doc.fields !== undefined &&
      (typeof doc.fields !== 'object' || doc.fields === null ||
       Array.isArray(doc.fields))) {
    throw new Error('Invalid Firestore typed fields.');
  }
  if (!doc.updateTime && (doc.fields !== undefined || doc.createTime !== undefined)) {
    throw new Error('Unexpected missing document metadata.');
  }
}

async function* collectionIds(parent, request) {
  const seen = new Set();
  let token;
  do {
    const answer = await request({
      method: 'POST', parent,
      operation: 'listCollectionIds',
      pageSize: PAGE_SIZE, pageToken: token,
    });
    if (!Array.isArray(answer?.collectionIds)) {
      // Firestore can return {} when there are no child collections.
      if (answer?.collectionIds !== undefined) {
        throw new Error('Invalid Firestore collection IDs response.');
      }
    }
    for (const id of answer.collectionIds ?? []) {
      if (typeof id !== 'string' || !id || id.includes('/')) {
        throw new Error('Invalid Firestore collection ID.');
      }
      yield id;
    }
    token = answer.nextPageToken;
  } while (safePageToken(token, seen));
}

async function* documentPages(parent, collectionId, request) {
  const seen = new Set();
  let token;
  do {
    const answer = await request({
      method: 'GET', parent, collectionId,
      operation: 'listDocuments',
      pageSize: PAGE_SIZE, pageToken: token,
      showMissing: true,
    });
    if (!Array.isArray(answer?.documents)) {
      if (answer?.documents !== undefined) {
        throw new Error('Invalid Firestore documents response.');
      }
    }
    for (const doc of answer.documents ?? []) yield doc;
    token = answer.nextPageToken;
  } while (safePageToken(token, seen));
}

/**
 * Traverse every root collection and nested subcollection, including missing
 * parent documents. Never project fields into JavaScript SDK types.
 */
export async function* discoverFirestoreRecords({ projectId, request, onProgress = () => {} }) {
  const root = firestoreRoot(projectId);
  let documentCount = 0;
  let collectionCount = 0;
  async function* walk(parent, depth) {
    if (depth > 99) throw new Error('Firestore nesting exceeds safe traversal depth.');
    for await (const collectionId of collectionIds(parent, request)) {
      collectionCount++;
      yield { kind: 'collection', parent, collectionId };
      for await (const doc of documentPages(parent, collectionId, request)) {
        ensureResourceName(root, parent, collectionId, doc);
        documentCount++;
        if (documentCount > 1000000) {
          throw new Error('Backup safety limit exceeded (1,000,000 documents).');
        }
        if (documentCount % 100 === 0) {
          onProgress({ documentCount, collectionCount });
        }
        yield { kind: 'document', document: doc, missing: !doc.updateTime };
        yield* walk(doc.name, depth + 1);
      }
    }
  }
  yield* walk(root, 0);
}

function encodeResource(resource) {
  return resource.split('/').map(encodeURIComponent).join('/');
}

/**
 * This fetcher permits only Firestore REST list operations.
 * POST to :listCollectionIds is a documented read endpoint, not a write.
 */
export function makeFirestoreReader({ getAccessToken, fetchImpl = fetch, timeoutMs = 45000 }) {
  return async function request({ method, parent, collectionId, operation, pageSize, pageToken, showMissing }) {
    const root = firestoreRoot(PROJECT);
    if (!(parent === root || parent.startsWith(root + '/')) ||
        parent.split('/').some((segment) => segment === '..' || segment === '.')) {
      throw new Error('Unsupported Firestore parent path.');
    }
    if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > PAGE_SIZE) {
      throw new Error('Invalid Firestore page size.');
    }
    if ((operation === 'listCollectionIds' && method !== 'POST') ||
        (operation === 'listDocuments' && method !== 'GET')) {
      throw new Error('Unexpected Firestore operation.');
    }
    const baseUrl = 'https://firestore.googleapis.com/v1/' + encodeResource(parent);
    let url, body;
    if (operation === 'listCollectionIds') {
      url = baseUrl + ':listCollectionIds';
      body = JSON.stringify({
        pageSize, ...(pageToken ? { pageToken } : {}),
      });
    } else {
      if (typeof collectionId !== 'string' || !collectionId ||
          collectionId.includes('/')) {
        throw new Error('Invalid Firestore collection.');
      }
      url = baseUrl + '/' + encodeURIComponent(collectionId);
      const query = new URLSearchParams({
        pageSize: String(pageSize), showMissing: String(showMissing === true),
      });
      if (pageToken) query.set('pageToken', pageToken);
      url += '?' + query.toString();
    }
    const token = await getAccessToken();
    if (typeof token !== 'string' || token.length < 10) {
      throw new Error('Unable to obtain Firebase read credentials.');
    }
    let response;
    try {
      response = await fetchImpl(url, {
        method,
        headers: {
          Authorization: 'Bearer ' + token,
          Accept: 'application/json',
          ...(body ? { 'Content-Type': 'application/json' } : {}),
        },
        ...(body ? { body } : {}),
        redirect: 'error',
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (_) {
      throw new Error('Firestore read could not reach Google Cloud. Network or token problem.');
    }
    if (!response.ok) {
      // Backend response body can contain private context. Never print it.
      throw new Error('Firestore REST read failed (HTTP ' + response.status + ').');
    }
    try {
      return await response.json();
    } catch (_) {
      throw new Error('Firestore returned invalid JSON.');
    }
  };
}

function checkArchiveRecord(record, root) {
  if (!record || typeof record !== 'object') throw new Error('Malformed archive record.');
  if (record.kind === 'collection') {
    if (typeof record.parent !== 'string' || !record.parent.startsWith(root) ||
        typeof record.collectionId !== 'string' || !record.collectionId ||
        record.collectionId.includes('/')) {
      throw new Error('Invalid archive collection path.');
    }
  } else if (record.kind === 'document') {
    const name = record.document?.name;
    if (typeof name !== 'string' || !name.startsWith(root + '/')) {
      throw new Error('Invalid archive document path.');
    }
    const segments = name.slice(root.length + 1).split('/');
    if (segments.length % 2 !== 0 || segments.some((v) => !v)) {
      throw new Error('Invalid archive document ID.');
    }
    if (record.missing !== !record.document.updateTime) {
      throw new Error('Archive missing-document marker mismatch.');
    }
  } else {
    throw new Error('Unknown archive record.');
  }
}

/**
 * .rbfsenc stores [RBFSENC1 | salt16 | iv12 | ciphertext | gcmTag16].
 * Plaintext is newline-delimited header, original Firestore typed documents,
 * and an authenticated SHA256 manifest. No plaintext file is written.
 */
export async function writeEncryptedFirestoreBackup({
  projectId, destination, passphrase, request, onProgress = () => {},
}) {
  const root = firestoreRoot(projectId);
  if (typeof destination !== 'string' || !destination.endsWith('.rbfsenc')) {
    throw new Error('Backup destination must have .rbfsenc extension.');
  }
  await mkdir(dirname(destination), { recursive: true, mode: 0o700 });
  const partial = destination + '.partial';
  const salt = randomBytes(SALT_LENGTH);
  const iv = randomBytes(IV_LENGTH);
  const key = await keyFor(passphrase, salt);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  key.fill(0);
  const header = Buffer.concat([MAGIC, salt, iv]);
  const hash = createHash('sha256');
  const startedAt = new Date().toISOString();
  const counts = { documents: 0, missingParents: 0, collections: 0 };
  let manifest;
  async function* contents() {
    const first = { kind: 'header', version: 1, projectId, database: DB_NAME, startedAt, snapshotConsistent: false };
    const firstLine = JSON.stringify(first) + '\n';
    hash.update(firstLine);
    yield firstLine;
    for await (const record of discoverFirestoreRecords({ projectId, request, onProgress })) {
      checkArchiveRecord(record, root);
      if (record.kind === 'document') {
        counts.documents++;
        if (record.missing) counts.missingParents++;
      } else {
        counts.collections++;
      }
      const line = JSON.stringify(record) + '\n';
      hash.update(line);
      yield line;
    }
    manifest = {
      kind: 'manifest', projectId, database: DB_NAME,
      finishedAt: new Date().toISOString(), ...counts,
      contentSha256: hash.digest('hex'),
      exportFormat: 'Firestore REST typed values',
      snapshotConsistent: false,
    };
    yield JSON.stringify(manifest) + '\n';
  }

  let created = false;
  let partialOpened = false;
  const out = createWriteStream(partial, { flags: 'wx', mode: 0o600 });
  out.on('open', () => { partialOpened = true; });
  const envelope = new Transform({
    transform(chunk, _encoding, done) {
      if (!created) {
        this.push(header);
        created = true;
      }
      this.push(chunk);
      done();
    },
    flush(done) {
      if (!created) this.push(header);
      this.push(cipher.getAuthTag());
      done();
    },
  });

  try {
    await pipeline(Readable.from(contents()), cipher, envelope, out);
    const validated = await verifyEncryptedFirestoreBackup({
      file: partial, passphrase, expectedProjectId: projectId,
    });
    if (validated.contentSha256 !== manifest.contentSha256) {
      throw new Error('Local post-write verification did not match.');
    }
    // Must not overwrite an earlier backup, even if clocks collide.
    const existing = await stat(destination).then(() => true, (e) => {
      if (e.code === 'ENOENT') return false;
      throw e;
    });
    if (existing) throw new Error('Backup destination already exists.');
    await rename(partial, destination);
    return { ...validated, file: destination };
  } catch (error) {
    // On Windows a stream can still hold an open handle after destroy().
    // Wait for close before trying to remove only the file we created.
    const closed = out.closed
      ? Promise.resolve()
      : new Promise((done) => out.once('close', done));
    out.destroy();
    await closed;
    // If 'wx' failed because a prior .partial file exists, never remove it.
    if (partialOpened) await rm(partial, { force: true }).catch(() => {});
    throw error;
  }
}

export async function verifyEncryptedFirestoreBackup({ file, passphrase, expectedProjectId = PROJECT }) {
  const root = firestoreRoot(expectedProjectId);
  const fileStat = await stat(file);
  if (!fileStat.isFile() || fileStat.size <= HEADER_LENGTH + TAG_LENGTH) {
    throw new Error('Invalid or truncated backup archive.');
  }
  const handle = await open(file, 'r');
  let header, tag;
  try {
    header = Buffer.alloc(HEADER_LENGTH);
    tag = Buffer.alloc(TAG_LENGTH);
    await handle.read(header, 0, HEADER_LENGTH, 0);
    await handle.read(tag, 0, TAG_LENGTH, fileStat.size - TAG_LENGTH);
  } finally {
    await handle.close();
  }
  if (!header.subarray(0, MAGIC.length).equals(MAGIC)) {
    throw new Error('Invalid backup signature.');
  }
  const salt = header.subarray(MAGIC.length, MAGIC.length + SALT_LENGTH);
  const iv = header.subarray(MAGIC.length + SALT_LENGTH);
  const key = await keyFor(passphrase, salt);
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  key.fill(0);
  decipher.setAuthTag(tag);
  const hash = createHash('sha256');
  const counters = { documents: 0, missingParents: 0, collections: 0 };
  let headerSeen = false;
  let manifest = null;

  function consumeLine(line) {
    if (!line) return;
    let entry;
    try {
      entry = JSON.parse(line);
    } catch (_) {
      throw new Error('Backup contains malformed JSON.');
    }
    if (manifest) throw new Error('Trailing records after backup manifest.');
    if (entry.kind === 'header') {
      if (headerSeen || entry.version !== 1 ||
          entry.projectId !== expectedProjectId || entry.database !== DB_NAME) {
        throw new Error('Backup header does not match requested project.');
      }
      headerSeen = true;
    } else if (entry.kind === 'manifest') {
      if (!headerSeen || entry.projectId !== expectedProjectId ||
          entry.database !== DB_NAME) {
        throw new Error('Backup manifest does not match project.');
      }
      manifest = entry;
      if (entry.contentSha256 !== hash.digest('hex') ||
          entry.documents !== counters.documents ||
          entry.missingParents !== counters.missingParents ||
          entry.collections !== counters.collections) {
        throw new Error('Backup contents or document totals failed integrity verification.');
      }
      return;
    } else {
      if (!headerSeen) throw new Error('Backup header is missing.');
      checkArchiveRecord(entry, root);
      if (entry.kind === 'document') {
        counters.documents++;
        if (entry.missing) counters.missingParents++;
      } else counters.collections++;
    }
    hash.update(line + '\n');
  }

  await pipeline(
    createReadStream(file, {
      start: HEADER_LENGTH, end: fileStat.size - TAG_LENGTH - 1,
    }),
    decipher,
    async (source) => {
      const decoder = new StringDecoder('utf8');
      let buffer = '';
      for await (const chunk of source) {
        buffer += decoder.write(chunk);
        let pos;
        while ((pos = buffer.indexOf('\n')) !== -1) {
          consumeLine(buffer.slice(0, pos));
          buffer = buffer.slice(pos + 1);
        }
        if (buffer.length > 8 * 1024 * 1024) {
          throw new Error('Backup archive record exceeds safety limits.');
        }
      }
      buffer += decoder.end();
      if (buffer) throw new Error('Backup archive has an incomplete final record.');
    },
  );

  if (!headerSeen || !manifest) throw new Error('Backup archive is incomplete.');
  return {
    projectId: expectedProjectId,
    documents: counters.documents,
    missingParents: counters.missingParents,
    collections: counters.collections,
    contentSha256: manifest.contentSha256,
    snapshotConsistent: false,
    verified: true,
  };
}

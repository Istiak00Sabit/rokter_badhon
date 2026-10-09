// Zero-mutation production audit: Firebase Rules release + Firestore composite indexes.
// Explicitly restrict network operations to two Google services and HTTP GET.
import { createHash } from 'node:crypto';

export const PROJECT_ID = 'rokterbadhon-b247b';
export const RULES_RELEASE = 'projects/' + PROJECT_ID + '/releases/cloud.firestore';
export const INDEX_PARENT = 'projects/' + PROJECT_ID + '/databases/(default)/collectionGroups/-';

function fail(message) { throw new Error(message); }
function checkedProject(projectId) {
  if (projectId !== PROJECT_ID) fail('Unsafe project ID.');
}
function hash(content) {
  return createHash('sha256').update(content, 'utf8').digest('hex');
}
function canonRules(content) {
  return content.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').replace(/\n+$/g, '') + '\n';
}

export function compareRules(local, release, ruleset) {
  const expectedPrefix = 'projects/' + PROJECT_ID + '/rulesets/';
  if (release?.name !== RULES_RELEASE ||
      typeof release?.rulesetName !== 'string' ||
      !release.rulesetName.startsWith(expectedPrefix)) {
    fail('Firebase Rules release identifier is unexpected.');
  }
  if (ruleset?.name !== release.rulesetName) fail('Unexpected Firebase Ruleset identifier.');
  const files = ruleset.source?.files;
  if (!Array.isArray(files) || files.length !== 1 ||
      typeof files[0]?.content !== 'string') {
    fail('Cannot safely compare multi-file or empty Firebase Ruleset.');
  }
  const expected = canonRules(local);
  const actual = canonRules(files[0].content);
  return {
    verified: true,
    exactContentMatch: actual === expected,
    localSha256: hash(expected),
    deployedSha256: hash(actual),
    releaseUpdatedAt: release.updateTime ?? null,
    // No live rule content or ruleset identifier printed.
    fileCount: files.length,
  };
}

function indexKey(value, isDeployed) {
  let group = value.collectionGroup;
  if (isDeployed) {
    const match = /^projects\/rokterbadhon-b247b\/databases\/\(default\)\/collectionGroups\/([^/]+)\/indexes\/[^/]+$/.exec(value.name ?? '');
    if (!match) fail('Unexpected deployed composite index resource.');
    group = decodeURIComponent(match[1]);
  }
  if (typeof group !== 'string' || !group.length || group.includes('/')) {
    fail('Invalid index collection group.');
  }
  if (!['COLLECTION', 'COLLECTION_GROUP'].includes(value.queryScope)) {
    fail('Invalid index query scope.');
  }
  if (!Array.isArray(value.fields) || value.fields.length < 2) {
    fail('Malformed composite index fields.');
  }
  let fields = value.fields.map((field) => {
    if (typeof field?.fieldPath !== 'string' || !field.fieldPath) {
      fail('Invalid indexed field.');
    }
    if (!['ASCENDING', 'DESCENDING'].includes(field.order) &&
        field.arrayConfig !== 'CONTAINS') {
      fail('Unsupported advanced index specification; manual review needed.');
    }
    if (field.arrayConfig === 'CONTAINS') {
      return { fieldPath: field.fieldPath, arrayConfig: 'CONTAINS' };
    }
    return { fieldPath: field.fieldPath, order: field.order };
  });
  if (isDeployed && fields[fields.length - 1].fieldPath === '__name__') {
    // Firestore appends an implicit __name__ field to composite indexes.
    fields = fields.slice(0, -1);
  }
  return JSON.stringify({ collectionGroup: group, queryScope: value.queryScope, fields });
}

export function compareIndexes(local, deployedIndexes) {
  if (!Array.isArray(local?.indexes) || !Array.isArray(deployedIndexes)) {
    fail('Invalid local or deployed composite index list.');
  }
  const expected = new Map(local.indexes.map((item) => [indexKey(item, false), item]));
  const live = new Map(deployedIndexes.map((item) => [indexKey(item, true), item]));
  const missing = [];
  const extra = [];
  const notReady = [];
  for (const [key, index] of expected) {
    if (!live.has(key)) missing.push(JSON.parse(key));
    else if (live.get(key).state !== 'READY') notReady.push(JSON.parse(key));
  }
  for (const key of live.keys()) {
    if (!expected.has(key)) extra.push(JSON.parse(key));
  }
  return {
    verified: true,
    expected: local.indexes.length,
    deployed: deployedIndexes.length,
    matchingReady: local.indexes.length - missing.length - notReady.length,
    missing,
    notReady,
    extra,
    exactCompositeMatch: missing.length === 0 && notReady.length === 0 && extra.length === 0,
    fieldOverridesVerified: false, // firestore.indexes.json fieldOverrides not fetched
  };
}

function validateGoogleUrl(url) {
  const parsed = new URL(url);
  const permitted = ['firebaserules.googleapis.com', 'firestore.googleapis.com'];
  if (parsed.protocol !== 'https:' || !permitted.includes(parsed.hostname) ||
      parsed.username || parsed.password || parsed.hash) {
    fail('Unexpected Google Cloud endpoint.');
  }
  const prefix = parsed.hostname === 'firebaserules.googleapis.com'
    ? '/v1/projects/' + PROJECT_ID + '/'
    : '/v1/projects/' + PROJECT_ID + '/databases/(default)/collectionGroups/-/indexes';
  // URL.pathname retains literal parentheses for an input created here.
  if (!parsed.pathname.startsWith(prefix)) fail('Unexpected project resource URL.');
  if (parsed.hostname === 'firebaserules.googleapis.com' &&
      !(/^\/v1\/projects\/rokterbadhon-b247b\/releases\/cloud\.firestore$/.test(parsed.pathname) ||
        /^\/v1\/projects\/rokterbadhon-b247b\/rulesets\/[a-zA-Z0-9_-]+$/.test(parsed.pathname))) {
    fail('Disallowed Rules API resource.');
  }
  if (parsed.hostname === 'firestore.googleapis.com' &&
      parsed.pathname !== prefix) fail('Disallowed index API resource.');
}

export function makeCloudRead({ getAccessToken, fetchImpl = fetch }) {
  return async (url) => {
    validateGoogleUrl(url);
    const token = await getAccessToken();
    if (typeof token !== 'string' || token.length < 10) {
      fail('Google Cloud access token unavailable.');
    }
    let response;
    try {
      response = await fetchImpl(url, {
        method: 'GET',
        redirect: 'error',
        headers: { Authorization: 'Bearer ' + token, Accept: 'application/json' },
        signal: AbortSignal.timeout(30000),
      });
    } catch (_) {
      fail('Google Cloud read network failed.');
    }
    if (!response.ok) fail('Google Cloud read HTTP ' + response.status);
    try {
      return await response.json();
    } catch (_) {
      fail('Invalid Google Cloud JSON response.');
    }
  };
}

export async function auditLiveRules({ projectId, localRules, read }) {
  checkedProject(projectId);
  const release = await read('https://firebaserules.googleapis.com/v1/' + RULES_RELEASE);
  if (release?.name !== RULES_RELEASE ||
      typeof release.rulesetName !== 'string' ||
      !/^projects\/rokterbadhon-b247b\/rulesets\/[a-zA-Z0-9_-]+$/.test(release.rulesetName)) {
    fail('Ruleset path does not match project.');
  }
  const ruleset = await read('https://firebaserules.googleapis.com/v1/' + release.rulesetName);
  return compareRules(localRules, release, ruleset);
}

export async function auditLiveIndexes({ projectId, localIndexes, read }) {
  checkedProject(projectId);
  const collection = [];
  let token;
  const seen = new Set();
  do {
    const url = new URL('https://firestore.googleapis.com/v1/' + INDEX_PARENT + '/indexes');
    url.searchParams.set('pageSize', '100');
    if (token) url.searchParams.set('pageToken', token);
    const result = await read(url.toString());
    if (result.indexes !== undefined && !Array.isArray(result.indexes)) {
      fail('Unexpected index listing response.');
    }
    collection.push(...(result.indexes ?? []));
    token = result.nextPageToken;
    if (token && (typeof token !== 'string' || token.length > 4096 || seen.has(token))) {
      fail('Repeated or invalid Firestore index page token.');
    }
    if (token) seen.add(token);
    if (collection.length > 10000) fail('Unusually large Firestore index list.');
  } while (token);
  return compareIndexes(localIndexes, collection);
}

// Zero-mutation production audit: deployed Rules and gcloud-listed composite indexes.
// REST is restricted to Firebase Rules GET; gcloud handles composite index listing.
import { createHash } from 'node:crypto';

export const PROJECT_ID = 'rokterbadhon-b247b';
export const RULES_RELEASE = 'projects/' + PROJECT_ID + '/releases/cloud.firestore';

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
  if (parsed.protocol !== 'https:' ||
      parsed.hostname !== 'firebaserules.googleapis.com' ||
      parsed.username || parsed.password || parsed.hash ||
      parsed.search) {
    fail('Unexpected Firebase Rules API endpoint.');
  }
  if (!(/^\/v1\/projects\/rokterbadhon-b247b\/releases\/cloud\.firestore$/.test(parsed.pathname) ||
      /^\/v1\/projects\/rokterbadhon-b247b\/rulesets\/[a-zA-Z0-9_-]+$/.test(parsed.pathname))) {
    fail('Disallowed Firebase Rules API resource.');
  }
}


/**
 * Error responses may include account IDs, URLs or private headers.
 * Only an explicit allowlist of Google status/reason tokens can be surfaced.
 */
export function safeGoogleApiError(status, body) {
  const approvedStatuses = new Set([
    'PERMISSION_DENIED', 'UNAUTHENTICATED',
    'FAILED_PRECONDITION', 'UNAVAILABLE', 'NOT_FOUND', 'INVALID_ARGUMENT',
  ]);
  const approvedReasons = new Set([
    'IAM_PERMISSION_DENIED', 'ACCESS_TOKEN_SCOPE_INSUFFICIENT',
    'SERVICE_DISABLED', 'CONSUMER_INVALID', 'SERVICE_CONFIG_NOT_FOUND',
    'BILLING_DISABLED', 'ORG_RESTRICTION_VIOLATION', 'VPC_SERVICE_CONTROLS',
    'ACCESS_DENIED', 'API_KEY_SERVICE_BLOCKED',
  ]);
  const code = Number.isInteger(status) && status >= 400 && status <= 599
    ? status : 'unknown';
  const details = body?.error?.details;
  const remoteStatus = body?.error?.status;
  const safeStatus = approvedStatuses.has(remoteStatus) ? remoteStatus : null;
  const reason = Array.isArray(details)
    ? details.find((item) => approvedReasons.has(item?.reason))?.reason : null;
  return 'Google Cloud read HTTP ' + code +
    (safeStatus ? ' status=' + safeStatus : '') +
    (reason ? ' reason=' + reason : '');
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
    if (!response.ok) {
      let responseBody = null;
      try {
        responseBody = await response.json();
      } catch (_) {
        // Only response status is needed when Google does not send valid JSON.
      }
      fail(safeGoogleApiError(response.status, responseBody));
    }
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


/**
 * gcloud firestore indexes composite list --format=json returns the complete
 * database-wide index array. This avoids a hand-built collectionGroups/- REST
 * request that returned HTTP 400 on the production project.
 */
export function parseGcloudCompositeIndexesJson(output) {
  if (typeof output !== 'string' || output.length > 10000000) {
    fail('Invalid gcloud composite index JSON size.');
  }
  let decoded;
  try {
    decoded = JSON.parse(output);
  } catch (_) {
    fail('gcloud did not return valid composite index JSON.');
  }
  if (!Array.isArray(decoded) || decoded.length > 10000) {
    fail('Invalid gcloud composite index JSON array.');
  }
  return decoded;
}

export async function auditLiveIndexes({ projectId, localIndexes, listCompositeIndexes }) {
  checkedProject(projectId);
  if (typeof listCompositeIndexes !== 'function') {
    fail('No read-only composite index listing function.');
  }
  const collection = await listCompositeIndexes();
  const comparison = compareIndexes(localIndexes, collection);
  return {
    ...comparison,
    source: 'gcloud firestore indexes composite list',
  };
}

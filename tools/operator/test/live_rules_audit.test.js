import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PROJECT_ID, RULES_RELEASE,
  compareRules, compareIndexes, parseGcloudCompositeIndexesJson,
  makeCloudRead, safeGoogleApiError, auditLiveRules, auditLiveIndexes,
} from '../src/live_rules_audit.js';

const release = {
  name: RULES_RELEASE,
  rulesetName: 'projects/rokterbadhon-b247b/rulesets/test123',
  updateTime: '2026-10-10T00:00:00Z',
};
const expectedRules = "rules_version = '2';\n";
const getRuleset = (content = expectedRules) => ({
  name: release.rulesetName,
  source: { files: [{ name: 'firestore.rules', content }] },
});
const sourceIndex = {
  collectionGroup: 'donors', queryScope: 'COLLECTION',
  fields: [
    { fieldPath: 'active', order: 'ASCENDING' },
    { fieldPath: 'name', order: 'ASCENDING' },
  ],
};
const remoteIndex = {
  name: 'projects/rokterbadhon-b247b/databases/(default)/collectionGroups/donors/indexes/index123',
  queryScope: 'COLLECTION', state: 'READY',
  fields: [...sourceIndex.fields, { fieldPath: '__name__', order: 'ASCENDING' }],
};

test('Firebase Rules read-only comparison identifies match, revision and missing file', () => {
  const same = compareRules(expectedRules.replace(/\n/g, '\r\n'), release, getRuleset());
  assert.equal(same.verified, true);
  assert.equal(same.exactContentMatch, true);
  assert.equal(same.localSha256, same.deployedSha256);
  assert.equal(same.releaseUpdatedAt, release.updateTime);

  const diff = compareRules(expectedRules, release, getRuleset("rules_version = '1';\n"));
  assert.equal(diff.exactContentMatch, false);
  assert.notEqual(diff.localSha256, diff.deployedSha256);
  assert.throws(() => compareRules(expectedRules, release, {
    ...getRuleset(), source: { files: [] },
  }), /multi-file or empty/);
});

test('Firestore index comparison removes the system generated document-name field', () => {
  const compared = compareIndexes({ indexes: [sourceIndex] }, [remoteIndex]);
  assert.equal(compared.verified, true);
  assert.equal(compared.exactCompositeMatch, true);
  assert.equal(compared.matchingReady, 1);
  assert.equal(compared.missing.length, 0);
  assert.equal(compared.extra.length, 0);
  assert.equal(compared.fieldOverridesVerified, false);

  const building = compareIndexes({ indexes: [sourceIndex] }, [{
    ...remoteIndex, state: 'CREATING',
  }]);
  assert.equal(building.exactCompositeMatch, false);
  assert.equal(building.notReady.length, 1);

  const notDeployed = compareIndexes({ indexes: [sourceIndex] }, []);
  assert.equal(notDeployed.missing.length, 1);
  assert.equal(notDeployed.matchingReady, 0);

  const extra = compareIndexes({ indexes: [] }, [remoteIndex]);
  assert.equal(extra.extra.length, 1);
});

test('GET-only network wrapper allows only expected Firebase Rules APIs', async () => {
  const requests = [];
  const read = makeCloudRead({
    getAccessToken: async () => 'synthetic-redacted-token',
    fetchImpl: async (url, opts) => {
      requests.push({ url, opts });
      return { ok: true, json: async () => ({}) };
    },
  });
  await read('https://firebaserules.googleapis.com/v1/' + RULES_RELEASE);
  await read('https://firebaserules.googleapis.com/v1/' + release.rulesetName);
  assert.equal(requests.length, 2);
  assert.ok(requests.every((x) => x.opts.method === 'GET'));
  assert.ok(requests.every((x) => x.opts.redirect === 'error'));
  assert.ok(requests.every((x) => !x.opts.body));
  assert.ok(!JSON.stringify(requests.map((x) => x.url)).includes('synthetic-redacted'));
  await assert.rejects(read('https://firebaserules.googleapis.com/v1/projects/another/release'));
  await assert.rejects(read('https://example.com/v1/' + RULES_RELEASE));
  await assert.rejects(read('https://firestore.googleapis.com/v1/projects/rokterbadhon-b247b/databases/(default)/collectionGroups/-/indexes'));
});

test('Rules retrieval and gcloud-provided composite indexes are read-only', async () => {
  const requested = [];
  const read = async (url) => {
    requested.push(url);
    if (url.endsWith('/releases/cloud.firestore')) return release;
    if (url.endsWith('/rulesets/test123')) return getRuleset();
    throw new Error('Unexpected read endpoint');
  };
  const rules = await auditLiveRules({
    projectId: PROJECT_ID, localRules: expectedRules, read,
  });
  let calls = 0;
  const indexes = await auditLiveIndexes({
    projectId: PROJECT_ID,
    localIndexes: { indexes: [sourceIndex] },
    listCompositeIndexes: async () => {
      calls++;
      return parseGcloudCompositeIndexesJson(JSON.stringify([remoteIndex]));
    },
  });
  assert.equal(rules.exactContentMatch, true);
  assert.equal(indexes.exactCompositeMatch, true);
  assert.equal(indexes.source, 'gcloud firestore indexes composite list');
  assert.equal(requested.length, 2);
  assert.equal(calls, 1);
});

test('gcloud JSON validation and unknown index resources cannot falsely verify', async () => {
  assert.deepEqual(parseGcloudCompositeIndexesJson('[]'), []);
  assert.throws(() => parseGcloudCompositeIndexesJson('not json'), /valid composite index JSON/);
  assert.throws(() => parseGcloudCompositeIndexesJson('{"indexes":[]}'), /Invalid gcloud/);
  assert.throws(() => parseGcloudCompositeIndexesJson(JSON.stringify({})), /Invalid gcloud/);
  await assert.rejects(auditLiveIndexes({
    projectId: PROJECT_ID, localIndexes: { indexes: [] },
    listCompositeIndexes: async () => { throw new Error('read-only CLI failed'); },
  }), /read-only CLI failed/);
  await assert.rejects(auditLiveIndexes({
    projectId: 'different-project',
    localIndexes: { indexes: [] },
    listCompositeIndexes: async () => [],
  }), /Unsafe project/);
  assert.throws(() => compareIndexes({ indexes: [sourceIndex] }, [{
    ...remoteIndex,
    name: 'projects/other/databases/(default)/collectionGroups/donors/indexes/bad',
  }]), /Unexpected deployed composite index/);
});


test('Google Rules 403 diagnostics allowlist reasons without leaking identity or token', async () => {
  const sensitiveResponse = {
    error: {
      code: 403,
      status: 'PERMISSION_DENIED',
      message: 'Bearer secret_token for private-account@example.com',
      details: [{
        '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
        reason: 'SERVICE_DISABLED',
        metadata: {
          consumer: 'projects/confidential-example',
          service: 'firebaserules.googleapis.com',
        },
      }],
    },
  };
  assert.equal(
    safeGoogleApiError(403, sensitiveResponse),
    'Google Cloud read HTTP 403 status=PERMISSION_DENIED reason=SERVICE_DISABLED',
  );
  const read = makeCloudRead({
    getAccessToken: async () => 'sensitive-test-token-do-not-show',
    fetchImpl: async () => ({
      ok: false,
      status: 403,
      json: async () => sensitiveResponse,
    }),
  });
  let seen = null;
  try {
    await read('https://firebaserules.googleapis.com/v1/' + RULES_RELEASE);
  } catch (error) {
    seen = error.message;
  }
  assert.ok(seen?.includes('SERVICE_DISABLED'));
  assert.ok(!seen.includes('private-account'));
  assert.ok(!seen.includes('sensitive-test-token'));
  assert.ok(!seen.includes('confidential-example'));

  assert.equal(
    safeGoogleApiError(403, {
      error: {
        status: 'PERMISSION_DENIED',
        details: [{ reason: 'UNKNOWN_TEXT_FROM_SERVER', data: 'private PII' }],
      },
    }),
    'Google Cloud read HTTP 403 status=PERMISSION_DENIED',
  );
  assert.equal(safeGoogleApiError(403, null), 'Google Cloud read HTTP 403');
});

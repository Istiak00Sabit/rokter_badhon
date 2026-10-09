import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PROJECT_ID, RULES_RELEASE, INDEX_PARENT,
  compareRules, compareIndexes,
  makeCloudRead, auditLiveRules, auditLiveIndexes,
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

test('GET-only network wrapper allows only expected Rules and Index APIs', async () => {
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
  await read('https://firestore.googleapis.com/v1/' + INDEX_PARENT + '/indexes?pageSize=100');
  assert.equal(requests.length, 3);
  assert.ok(requests.every((x) => x.opts.method === 'GET'));
  assert.ok(requests.every((x) => x.opts.redirect === 'error'));
  assert.ok(requests.every((x) => !x.opts.body));
  assert.ok(!JSON.stringify(requests.map((x) => x.url)).includes('synthetic-redacted'));
  await assert.rejects(read('https://firebaserules.googleapis.com/v1/projects/another/release'));
  await assert.rejects(read('https://example.com/v1/' + RULES_RELEASE));
  await assert.rejects(read('https://firestore.googleapis.com/v1/' + INDEX_PARENT + '/indexes/create'));
});

test('Rules retrieval and paginated composite index audit use only read operations', async () => {
  const requested = [];
  const read = async (url) => {
    requested.push(url);
    if (url.endsWith('/releases/cloud.firestore')) return release;
    if (url.endsWith('/rulesets/test123')) return getRuleset();
    if (url.includes('pageToken=second')) return { indexes: [] };
    if (url.includes('/indexes?')) return { indexes: [remoteIndex], nextPageToken: 'second' };
    throw new Error('Unexpected request');
  };
  const rules = await auditLiveRules({
    projectId: PROJECT_ID, localRules: expectedRules, read,
  });
  const indexes = await auditLiveIndexes({
    projectId: PROJECT_ID, localIndexes: { indexes: [sourceIndex] }, read,
  });
  assert.equal(rules.exactContentMatch, true);
  assert.equal(indexes.exactCompositeMatch, true);
  assert.equal(requested.length, 4);
  assert.ok(requested.every((url) => !url.includes('token=')));
});

test('pagination loops and unknown index resource cannot mark audit as verified', async () => {
  await assert.rejects(auditLiveIndexes({
    projectId: PROJECT_ID,
    localIndexes: { indexes: [] },
    read: async () => ({ indexes: [], nextPageToken: 'repeat' }),
  }), /Repeated or invalid/);
  assert.throws(() => compareIndexes({ indexes: [sourceIndex] }, [{
    ...remoteIndex,
    name: 'projects/other/databases/(default)/collectionGroups/donors/indexes/bad',
  }]), /Unexpected deployed composite index/);
});

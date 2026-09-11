import assert from 'node:assert/strict';
import test from 'node:test';

import {
  addCommitteeMedia,
  committeeMediaSchemaFields,
  deactivateCommitteeMedia,
  editCommitteeMediaCaption,
  setCommitteeGroupPhoto,
  setCommitteeMediaOrder,
} from '../src/committee_media.js';
import { adminUser, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const OPERATOR_UID = 'operator-uid';
const OPERATOR_ID = 'operator-user';
const TERM_ID = 'term-2026';

function term(changes = {}) {
  return {
    name: '2026-2028',
    start_year: 2026,
    end_year: 2028,
    start_date: null,
    end_date: null,
    active: true,
    group_photo_url: null,
    created_at: TIME,
    created_by: OPERATOR_ID,
    ...changes,
  };
}

function media(changes = {}) {
  return {
    term_id: TERM_ID,
    image_url: 'https://example.test/gallery.jpg',
    caption: 'Committee gathering',
    sort_order: 3,
    active: true,
    uploaded_at: TIME,
    uploaded_by: OPERATOR_ID,
    provider: null,
    provider_public_id: null,
    ...changes,
  };
}

function fixture({ role = 'developer_admin', operatorChanges = {}, includeTerm = true, entries = [] } = {}) {
  const documents = [
    ['auth_links/operator-uid', { user_id: OPERATOR_ID, active: true, created_at: TIME, created_by: 'seed' }],
    [`users/${OPERATOR_ID}`, adminUser({ access_role: role, ...operatorChanges })],
    ...entries,
  ];
  if (includeTerm) documents.push([`committee_terms/${TERM_ID}`, term()]);
  return {
    db: new FakeFirestore(documents),
    auth: new FakeAuth([[OPERATOR_UID, {
      uid: OPERATOR_UID,
      email: 'operator@example.test',
      emailVerified: true,
      disabled: false,
    }]]),
  };
}

function common(base, operationId) {
  return {
    ...base,
    serverTimestamp: () => SERVER_TIME,
    operatorUid: OPERATOR_UID,
    operationId,
    reason: 'Reviewed editorial media operation.',
  };
}

function addArgs(options = {}) {
  const base = fixture(options.fixture);
  return {
    ...common(base, 'media-add-1'),
    termId: TERM_ID,
    imageUrl: 'https://example.test/new-gallery.jpg',
    caption: null,
    sortOrder: 4,
    provider: null,
    providerPublicId: null,
    ...options,
    ...base,
  };
}

async function rejectsCode(promise, code) {
  await assert.rejects(promise, (error) => error.code === code);
}

test('valid media add creates exact schema and atomic audit without changing access_role', async () => {
  const args = addArgs();
  const roleBefore = args.db.documents.get(`users/${OPERATOR_ID}`).access_role;
  const result = await addCommitteeMedia(args);
  const created = args.db.documents.get(`committee_media/${result.mediaId}`);
  assert.deepEqual(new Set(Object.keys(created)), committeeMediaSchemaFields);
  assert.deepEqual(created, {
    term_id: TERM_ID,
    image_url: 'https://example.test/new-gallery.jpg',
    caption: null,
    sort_order: 4,
    active: true,
    uploaded_at: SERVER_TIME,
    uploaded_by: OPERATOR_ID,
    provider: null,
    provider_public_id: null,
  });
  const audit = args.db.documents.get('audit_logs/media-add-1');
  assert.equal(audit.action, 'committee_media.add');
  assert.equal(audit.target_path, `committee_media/${result.mediaId}`);
  assert.equal(args.db.documents.get(`users/${OPERATOR_ID}`).access_role, roleBefore);
});

test('unauthorized and inactive operators cannot add media', async () => {
  await rejectsCode(addCommitteeMedia(addArgs({ fixture: { role: 'executive' } })), 'unauthorized');
  await rejectsCode(addCommitteeMedia(addArgs({ fixture: { operatorChanges: { active: false } } })), 'operator_not_admitted');
});

test('missing term and invalid URL fail without partial writes', async () => {
  const missing = addArgs({ fixture: { includeTerm: false } });
  const before = new Set(missing.db.documents.keys());
  await rejectsCode(addCommitteeMedia(missing), 'missing');
  assert.deepEqual(new Set(missing.db.documents.keys()), before);
  assert.equal(missing.db.documents.has('audit_logs/media-add-1'), false);

  const invalid = addArgs({ imageUrl: 'http://example.test/not-secure.jpg' });
  await rejectsCode(addCommitteeMedia(invalid), 'invalid_url');
  assert.equal([...invalid.db.documents.keys()].some((path) => path.startsWith('committee_media/')), false);
});

test('deactivate changes only active and writes audit', async () => {
  const base = fixture({ entries: [['committee_media/media-1', media()]] });
  const before = { ...base.db.documents.get('committee_media/media-1') };
  await deactivateCommitteeMedia({
    ...common(base, 'media-hide-1'),
    mediaId: 'media-1',
  });
  assert.deepEqual(base.db.documents.get('committee_media/media-1'), { ...before, active: false });
  assert.equal(base.db.documents.get('audit_logs/media-hide-1').action, 'committee_media.hide');
});

test('already inactive media is denied and historical metadata remains', async () => {
  const base = fixture({ entries: [['committee_media/media-1', media({ active: false })]] });
  const before = { ...base.db.documents.get('committee_media/media-1') };
  await rejectsCode(deactivateCommitteeMedia({
    ...common(base, 'media-hide-1'),
    mediaId: 'media-1',
  }), 'already_inactive');
  assert.deepEqual(base.db.documents.get('committee_media/media-1'), before);
  assert.equal(base.db.documents.has('audit_logs/media-hide-1'), false);
});

test('caption and order edits change one field each and preserve media identity', async () => {
  const base = fixture({ role: 'leader', entries: [['committee_media/media-1', media()]] });
  const original = { ...base.db.documents.get('committee_media/media-1') };
  await editCommitteeMediaCaption({
    ...common(base, 'caption-edit-1'),
    mediaId: 'media-1',
    caption: 'Corrected caption',
  });
  assert.deepEqual(base.db.documents.get('committee_media/media-1'), {
    ...original,
    caption: 'Corrected caption',
  });
  assert.equal(base.db.documents.get('audit_logs/caption-edit-1').action, 'committee_media.edit_caption');

  await setCommitteeMediaOrder({
    ...common(base, 'order-edit-1'),
    mediaId: 'media-1',
    sortOrder: 9,
  });
  assert.deepEqual(base.db.documents.get('committee_media/media-1'), {
    ...original,
    caption: 'Corrected caption',
    sort_order: 9,
  });
  assert.equal(base.db.documents.get('audit_logs/order-edit-1').action, 'committee_media.set_order');
});

test('caption/order edits deny lower roles, inactive media, invalid order and reused operations', async () => {
  for (const role of ['executive', 'committee', 'member']) {
    const denied = fixture({ role, entries: [['committee_media/media-1', media()]] });
    await rejectsCode(editCommitteeMediaCaption({
      ...common(denied, `caption-${role}`), mediaId: 'media-1', caption: 'Denied',
    }), 'unauthorized');
  }
  const inactive = fixture({ entries: [['committee_media/media-1', media({ active: false })]] });
  await rejectsCode(setCommitteeMediaOrder({
    ...common(inactive, 'inactive-order'), mediaId: 'media-1', sortOrder: 2,
  }), 'media_inactive');
  await rejectsCode(setCommitteeMediaOrder({
    ...common(inactive, 'invalid-order'), mediaId: 'media-1', sortOrder: -1,
  }), 'invalid_argument');
  const reused = fixture({ entries: [
    ['committee_media/media-1', media()],
    ['audit_logs/caption-reused', { action: 'existing' }],
  ] });
  const before = { ...reused.db.documents.get('committee_media/media-1') };
  await rejectsCode(editCommitteeMediaCaption({
    ...common(reused, 'caption-reused'), mediaId: 'media-1', caption: null,
  }), 'operation_reused');
  assert.deepEqual(reused.db.documents.get('committee_media/media-1'), before);
});

test('leader can update and clear only the group photo with audit', async () => {
  const base = fixture({ role: 'leader' });
  const before = { ...base.db.documents.get(`committee_terms/${TERM_ID}`) };
  await setCommitteeGroupPhoto({
    ...common(base, 'group-photo-1'),
    termId: TERM_ID,
    imageUrl: 'https://example.test/group.jpg',
  });
  assert.deepEqual(base.db.documents.get(`committee_terms/${TERM_ID}`), {
    ...before,
    group_photo_url: 'https://example.test/group.jpg',
  });
  assert.equal(base.db.documents.get('audit_logs/group-photo-1').action, 'committee.group_photo_update');

  await setCommitteeGroupPhoto({
    ...common(base, 'group-photo-clear'),
    termId: TERM_ID,
    imageUrl: null,
  });
  assert.equal(base.db.documents.get(`committee_terms/${TERM_ID}`).group_photo_url, null);
});

test('operation ID reuse is denied with no media or term mutation', async () => {
  const reusedAdd = addArgs({ fixture: { entries: [['audit_logs/media-add-1', { action: 'existing' }]] } });
  const beforePaths = new Set(reusedAdd.db.documents.keys());
  await rejectsCode(addCommitteeMedia(reusedAdd), 'operation_reused');
  assert.deepEqual(new Set(reusedAdd.db.documents.keys()), beforePaths);

  const base = fixture({ entries: [['audit_logs/group-reused', { action: 'existing' }]] });
  const beforeTerm = { ...base.db.documents.get(`committee_terms/${TERM_ID}`) };
  await rejectsCode(setCommitteeGroupPhoto({
    ...common(base, 'group-reused'),
    termId: TERM_ID,
    imageUrl: 'https://example.test/group.jpg',
  }), 'operation_reused');
  assert.deepEqual(base.db.documents.get(`committee_terms/${TERM_ID}`), beforeTerm);
});

test('provider metadata stays generic and cannot orphan a public ID', async () => {
  const args = addArgs({ provider: 'manual_provider', providerPublicId: 'public-reference' });
  const result = await addCommitteeMedia(args);
  const created = args.db.documents.get(`committee_media/${result.mediaId}`);
  assert.equal(created.provider, 'manual_provider');
  assert.equal(created.provider_public_id, 'public-reference');
  await rejectsCode(addCommitteeMedia(addArgs({ providerPublicId: 'orphan' })), 'invalid_argument');
});

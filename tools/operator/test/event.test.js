import assert from 'node:assert/strict';
import test from 'node:test';

import {
  addEventMedia,
  createEvent,
  editEventMediaCaption,
  eventSchemaFields,
  hideEvent,
  hideEventMedia,
  setEventCover,
  setEventMediaOrder,
  updateEvent,
} from '../src/event.js';
import { adminUser, FakeAuth, FakeFirestore, SERVER_TIME, TIME } from './fakes.js';

const UID = 'operator-uid';
const USER = 'operator-user';
const EVENT = 'event-1';

const event = (changes = {}) => ({
  title: 'Blood camp', description: null, event_type: 'blood_donation_campaign',
  event_date: TIME, location: 'Ghatail', cover_image_url: null, active: true,
  created_at: TIME, created_by: USER, updated_at: null, updated_by: null,
  ...changes,
});
const media = (changes = {}) => ({
  event_id: EVENT, image_url: 'https://example.test/event.jpg', caption: null,
  sort_order: 0, active: true, uploaded_at: TIME, uploaded_by: USER,
  provider: null, provider_public_id: null, ...changes,
});

function fixture({ role = 'developer_admin', entries = [] } = {}) {
  return {
    db: new FakeFirestore([
      ['auth_links/operator-uid', { user_id: USER, active: true, created_at: TIME, created_by: 'seed' }],
      [`users/${USER}`, adminUser({ access_role: role })],
      ...entries,
    ]),
    auth: new FakeAuth([[UID, { uid: UID, email: 'operator@example.test', emailVerified: true, disabled: false }]]),
  };
}
const common = (base, operationId) => ({ ...base, serverTimestamp: () => SERVER_TIME, operatorUid: UID, operationId, reason: 'Reviewed event editorial operation.' });
async function code(promise, expected) { await assert.rejects(promise, (error) => error.code === expected); }

test('create event writes exact schema and atomic audit', async () => {
  const base = fixture();
  const result = await createEvent({
    ...common(base, 'event-create-1'), title: 'Blood camp', description: null,
    eventType: 'blood_donation_campaign', eventDate: TIME, location: 'Ghatail',
    coverImageUrl: null,
  });
  const value = base.db.documents.get(`events/${result.eventId}`);
  assert.deepEqual(new Set(Object.keys(value)), eventSchemaFields.event);
  assert.equal(value.created_by, USER);
  assert.equal(value.active, true);
  assert.equal(base.db.documents.get('audit_logs/event-create-1').action, 'event.create');
});

test('event creation rejects lower roles, invalid types, timestamps, and operation reuse', async () => {
  const lower = fixture({ role: 'executive' });
  await code(createEvent({ ...common(lower, 'op-1'), title: 'Event', description: null, eventType: 'meeting', eventDate: TIME, location: null, coverImageUrl: null }), 'unauthorized');
  const invalid = fixture();
  await code(createEvent({ ...common(invalid, 'op-2'), title: 'Event', description: null, eventType: 'unknown', eventDate: TIME, location: null, coverImageUrl: null }), 'invalid_argument');
  await code(createEvent({ ...common(invalid, 'op-3'), title: 'Event', description: null, eventType: 'meeting', eventDate: 'today', location: null, coverImageUrl: null }), 'malformed');
  const reused = fixture({ entries: [['audit_logs/op-4', { action: 'old' }]] });
  await code(createEvent({ ...common(reused, 'op-4'), title: 'Event', description: null, eventType: 'meeting', eventDate: TIME, location: null, coverImageUrl: null }), 'operation_reused');
  assert.equal([...reused.db.documents.keys()].some((path) => path.startsWith('events/')), false);
});

test('event edit, cover, and hide preserve provenance and role', async () => {
  const base = fixture({ role: 'leader', entries: [[`events/${EVENT}`, event()]] });
  const original = { ...base.db.documents.get(`events/${EVENT}`) };
  await updateEvent({ ...common(base, 'edit-1'), eventId: EVENT, title: 'Updated camp' });
  await setEventCover({ ...common(base, 'cover-1'), eventId: EVENT, coverImageUrl: 'https://example.test/cover.jpg' });
  await hideEvent({ ...common(base, 'hide-1'), eventId: EVENT });
  const value = base.db.documents.get(`events/${EVENT}`);
  assert.equal(value.created_at, original.created_at);
  assert.equal(value.created_by, original.created_by);
  assert.equal(value.title, 'Updated camp');
  assert.equal(value.cover_image_url, 'https://example.test/cover.jpg');
  assert.equal(value.active, false);
  assert.equal(value.updated_by, USER);
  assert.equal(base.db.documents.get(`users/${USER}`).access_role, 'leader');
});

test('inactive and malformed events cannot be edited', async () => {
  const inactive = fixture({ entries: [[`events/${EVENT}`, event({ active: false })]] });
  await code(updateEvent({ ...common(inactive, 'edit-2'), eventId: EVENT, title: 'No' }), 'event_inactive');
  const malformed = fixture({ entries: [[`events/${EVENT}`, { ...event(), legacy: true }]] });
  await code(hideEvent({ ...common(malformed, 'hide-2'), eventId: EVENT }), 'malformed');
});

test('media add writes exact immutable provenance and audit', async () => {
  const base = fixture({ entries: [[`events/${EVENT}`, event()]] });
  const result = await addEventMedia({ ...common(base, 'media-add-1'), eventId: EVENT, imageUrl: 'https://example.test/new.jpg', caption: 'Gallery', sortOrder: 2, provider: null, providerPublicId: null });
  const value = base.db.documents.get(`event_media/${result.mediaId}`);
  assert.deepEqual(new Set(Object.keys(value)), eventSchemaFields.media);
  assert.equal(value.uploaded_by, USER);
  assert.equal(base.db.documents.get('audit_logs/media-add-1').action, 'event_media.add');
});

test('media add rejects missing/inactive parent, bad URL and orphan provider metadata', async () => {
  const missing = fixture();
  await code(addEventMedia({ ...common(missing, 'm-1'), eventId: EVENT, imageUrl: 'https://example.test/a.jpg', caption: null, sortOrder: 0, provider: null, providerPublicId: null }), 'missing');
  const inactive = fixture({ entries: [[`events/${EVENT}`, event({ active: false })]] });
  await code(addEventMedia({ ...common(inactive, 'm-2'), eventId: EVENT, imageUrl: 'https://example.test/a.jpg', caption: null, sortOrder: 0, provider: null, providerPublicId: null }), 'event_inactive');
  const base = fixture({ entries: [[`events/${EVENT}`, event()]] });
  await code(addEventMedia({ ...common(base, 'm-3'), eventId: EVENT, imageUrl: 'http://example.test/a.jpg', caption: null, sortOrder: 0, provider: null, providerPublicId: null }), 'invalid_url');
  await code(addEventMedia({ ...common(base, 'm-4'), eventId: EVENT, imageUrl: 'https://example.test/a.jpg', caption: null, sortOrder: 0, provider: null, providerPublicId: 'orphan' }), 'invalid_argument');
});

test('caption, order, and hide change only their intended media field', async () => {
  const base = fixture({ entries: [[`events/${EVENT}`, event()], ['event_media/media-1', media()]] });
  const original = { ...base.db.documents.get('event_media/media-1') };
  await editEventMediaCaption({ ...common(base, 'caption-1'), mediaId: 'media-1', caption: 'Updated' });
  await setEventMediaOrder({ ...common(base, 'order-1'), mediaId: 'media-1', sortOrder: 7 });
  await hideEventMedia({ ...common(base, 'media-hide-1'), mediaId: 'media-1' });
  assert.deepEqual(base.db.documents.get('event_media/media-1'), { ...original, caption: 'Updated', sort_order: 7, active: false });
});

test('media edits fail on lower role, inactive media or inactive parent', async () => {
  const lower = fixture({ role: 'committee', entries: [[`events/${EVENT}`, event()], ['event_media/media-1', media()]] });
  await code(hideEventMedia({ ...common(lower, 'm-5'), mediaId: 'media-1' }), 'unauthorized');
  const inactiveMedia = fixture({ entries: [[`events/${EVENT}`, event()], ['event_media/media-1', media({ active: false })]] });
  await code(hideEventMedia({ ...common(inactiveMedia, 'm-6'), mediaId: 'media-1' }), 'media_inactive');
  const inactiveParent = fixture({ entries: [[`events/${EVENT}`, event({ active: false })], ['event_media/media-1', media()]] });
  await code(setEventMediaOrder({ ...common(inactiveParent, 'm-7'), mediaId: 'media-1', sortOrder: 1 }), 'event_inactive');
});

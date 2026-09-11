const { readFileSync } = require('node:fs');
const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, query, where,
  writeBatch, serverTimestamp, Timestamp, deleteField, orderBy } = require('firebase/firestore');

const projectId = 'demo-rokter-badhon';
let env;
const stamp = Timestamp.fromMillis(1700000000000);
const user = (extra = {}) => ({ name: 'Synthetic Member', phone: '00000000000', email: 'member@example.test',
  blood_group: 'A+', profession: null, address: null, photo_url: null, access_role: 'member',
  active: true, login_enabled: true, preferred_language: null, created_at: stamp, created_by: null,
  updated_at: stamp, updated_by: null, ...extra });
const projection = u => Object.fromEntries(['name','phone','blood_group','profession','photo_url','active'].map(k => [k,u[k]]));
const db = (uid = 'auth-own', claims = {}) => env.authenticatedContext(uid,
  { email: `${uid}@example.test`, email_verified: true, ...claims }).firestore();
const request = (extra = {}) => ({ auth_uid: 'applicant', name: 'Synthetic Applicant', phone: '00000000001',
  email: 'applicant@example.test', status: 'pending', requested_at: serverTimestamp(),
  approved_by: null, approved_at: null, rejected_by: null, rejected_at: null, linked_user_id: null, ...extra });
const metadata = () => ({ updated_at: serverTimestamp(), updated_by: 'person-own' });
async function seed(path, data) {
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), path), data));
}
async function batchProfile(changes, directoryChanges = changes, client = db(), id = 'person-own') {
  const batch = writeBatch(client);
  batch.update(doc(client, `users/${id}`), { ...changes, ...metadata() });
  batch.update(doc(client, `user_directory/${id}`), directoryChanges);
  return batch.commit();
}
before(async () => {
  // Refuse any endpoint except the loopback emulator; never use real Auth/data.
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):8080$/);
  env = await initializeTestEnvironment({ projectId, firestore: { host: '127.0.0.1', port: 8080,
    rules: readFileSync('firestore.rules', 'utf8') } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    const b = writeBatch(c.firestore());
    for (const id of ['own','other']) {
      const u = user();
      b.set(doc(c.firestore(), `users/person-${id}`), u);
      b.set(doc(c.firestore(), `user_directory/person-${id}`), projection(u));
      b.set(doc(c.firestore(), `auth_links/auth-${id}`), { user_id: `person-${id}`, active: true, created_at: stamp, created_by: 'person-own' });
    }
    b.set(doc(c.firestore(), 'user_directory/inactive'), projection(user({ active: false })));
    await b.commit();
  });
});

test('unauthenticated denied across core reads and writes', async () => {
  const c = env.unauthenticatedContext().firestore();
  for (const path of ['users/person-own','user_directory/person-own','auth_links/auth-own','registration_requests/applicant']) {
    await assertFails(getDoc(doc(c, path)));
    await assertFails(setDoc(doc(c, path), request()));
  }
});
test('unverified unlinked requester creates and gets own request, including terminal status', async () => {
  const c = db('applicant', { email_verified: false });
  await assertSucceeds(setDoc(doc(c, 'registration_requests/applicant'), request()));
  await assertSucceeds(getDoc(doc(c, 'registration_requests/applicant')));
  await seed('registration_requests/applicant', request({ status: 'rejected', requested_at: stamp }));
  await assertSucceeds(getDoc(doc(c, 'registration_requests/applicant')));
  await assertFails(getDoc(doc(c, 'users/person-own')));
  await assertFails(getDoc(doc(c, 'user_directory/person-own')));
});
test('registration wrong path, forged identity/email/state/time/decision and extra fields denied', async () => {
  const c = db('applicant');
  await assertFails(setDoc(doc(c, 'registration_requests/other'), request()));
  for (const extra of [{ auth_uid: 'other' }, { email: 'other@example.test' }, { status: 'approved' },
    { requested_at: stamp }, { approved_by: 'person-own' }, { approved_at: stamp }, { rejected_by: 'x' },
    { rejected_at: stamp }, { linked_user_id: 'person-own' }, { access_role: 'leader' }, { active: true },
    { login_enabled: true }, { position: 'president' }, { password: 'synthetic' }, { name: 42 }, { phone: null }]) {
    await assertFails(setDoc(doc(c, 'registration_requests/applicant'), request(extra)));
  }
  for (const field of Object.keys(request())) {
    const data = request(); delete data[field];
    await assertFails(setDoc(doc(c, 'registration_requests/applicant'), data));
  }
  await assertFails(setDoc(doc(db('applicant', { email: null }), 'registration_requests/applicant'), request()));
});
test('registration overwrite/update/delete/list/other read denied', async () => {
  const c = db('applicant'); const ref = doc(c, 'registration_requests/applicant');
  await assertSucceeds(setDoc(ref, request()));
  await assertFails(setDoc(ref, request()));
  await assertFails(updateDoc(ref, { name: 'Changed' }));
  await assertFails(deleteDoc(ref));
  await assertFails(getDocs(collection(c, 'registration_requests')));
  await assertFails(getDoc(doc(c, 'registration_requests/other')));
});
for (const role of ['developer_admin','leader','executive','committee','member']) {
  test(`${role}: pending registration review audience is exact`, async () => {
    await seed('users/person-own', user({ access_role: role }));
    await seed('registration_requests/pending-review', request({ auth_uid: 'pending-review', requested_at: stamp }));
    await seed('registration_requests/rejected-review', request({ auth_uid: 'rejected-review', status: 'rejected', requested_at: stamp, rejected_by: 'person-own', rejected_at: stamp }));
    const c = db(); const allowed = role === 'developer_admin' || role === 'leader';
    await (allowed ? assertSucceeds : assertFails)(getDoc(doc(c, 'registration_requests/pending-review')));
    await (allowed ? assertSucceeds : assertFails)(getDocs(query(collection(c, 'registration_requests'), where('status','==','pending'))));
    await assertFails(getDoc(doc(c, 'registration_requests/rejected-review')));
    await assertFails(getDocs(query(collection(c, 'registration_requests'), where('status','==','rejected'))));
    await assertFails(getDocs(collection(c, 'registration_requests')));
  });
}
for (const link of [{ active: true, user_id: 'person-own' }, { active: false, user_id: 'person-own' }, { active: true, user_id: 'missing' }, {}]) {
  test(`present link disqualifies registration: ${JSON.stringify(link)}`, async () => {
    await seed('auth_links/applicant', link);
    const c = db('applicant');
    await assertFails(setDoc(doc(c, 'registration_requests/applicant'), request()));
    await assertFails(getDoc(doc(c, 'registration_requests/applicant')));
  });
}
test('own auth link get allowed before admission; other get/list/all writes denied', async () => {
  const c = db('auth-own', { email_verified: false });
  await assertSucceeds(getDoc(doc(c, 'auth_links/auth-own')));
  await assertSucceeds(getDoc(doc(db('missing'), 'auth_links/missing')));
  await assertFails(getDoc(doc(c, 'auth_links/auth-other')));
  await assertFails(getDocs(collection(c, 'auth_links')));
  await assertFails(setDoc(doc(c, 'auth_links/auth-own'), { active: true, user_id: 'person-other' }));
  await assertFails(updateDoc(doc(c, 'auth_links/auth-own'), { active: false }));
  await assertFails(deleteDoc(doc(c, 'auth_links/auth-own')));
  await assertFails(setDoc(doc(db('missing'), 'auth_links/missing'), { active: true, user_id: 'person-own' }));
});
const badGates = [
  ['unverified', null, null, { email_verified: false }],
  ['missing verification', null, null, { email_verified: null }],
  ['inactive link', { user_id: 'person-own', active: false }],
  ['missing link active', { user_id: 'person-own' }],
  ['malformed link active', { user_id: 'person-own', active: 'true' }],
  ['dangling link', { user_id: 'missing', active: true }],
  ['missing link user id', { active: true }],
  ['malformed link user id', { user_id: 1, active: true }],
  ['inactive User', null, { active: false }], ['missing User active', null, { active: undefined }],
  ['malformed User active', null, { active: 'true' }],
  ['login disabled', null, { login_enabled: false }], ['missing login', null, { login_enabled: undefined }],
  ['malformed login', null, { login_enabled: 'true' }],
  ['invalid role', null, { access_role: 'admin', role: 'admin', position: 'president' }],
  ['missing role', null, { access_role: undefined, role: 'admin' }], ['null role', null, { access_role: null }]
];
for (const [label, link, changes, claims] of badGates) {
  test(`gate denies ${label} for reads and writes`, async () => {
    if (link) await seed('auth_links/auth-own', link);
    if (changes) await seed('users/person-own', Object.fromEntries(Object.entries(user(changes)).filter(([,v]) => v !== undefined)));
    const c = db('auth-own', claims);
    await assertFails(getDoc(doc(c, 'users/person-own')));
    await assertFails(getDoc(doc(c, 'user_directory/person-own')));
    await assertFails(updateDoc(doc(c, 'users/person-own'), { address: 'Changed', ...metadata() }));
    await assertFails(batchProfile({ name: 'Changed' }, { name: 'Changed' }, c));
  });
}
test('no UID-path, directory or token-role fallback without link', async () => {
  await seed('users/unlinked', user({ role: 'admin', position: 'president' }));
  await seed('user_directory/unlinked', projection(user()));
  const c = db('unlinked', { access_role: 'developer_admin', role: 'admin' });
  await assertFails(getDoc(doc(c, 'users/unlinked')));
  await assertFails(getDoc(doc(c, 'user_directory/unlinked')));
});
for (const role of ['developer_admin','leader','executive','committee','member']) {
  test(`${role}: own User and active directory allowed; private others/list denied`, async () => {
    await seed('users/person-own', user({ access_role: role }));
    const c = db();
    await assertSucceeds(getDoc(doc(c, 'users/person-own')));
    await assertFails(getDoc(doc(c, 'users/person-other')));
    await assertFails(getDocs(collection(c, 'users')));
    await assertSucceeds(getDoc(doc(c, 'user_directory/person-other')));
    await assertSucceeds(getDocs(query(collection(c, 'user_directory'), where('active','==',true))));
    await assertFails(getDoc(doc(c, 'user_directory/inactive')));
    await assertFails(getDocs(collection(c, 'user_directory')));
    await assertSucceeds(batchProfile({ name: 'Changed' }));
  });
}
for (const [field, value] of Object.entries({ name: 'Changed', phone: '00000000002', blood_group: 'B+', profession: 'Teacher', address: 'Synthetic Address', preferred_language: 'bn' })) {
  test(`allowed own profile ${field} with bound metadata and exact projection`, async () => {
    if (['address','preferred_language'].includes(field)) {
      await assertSucceeds(updateDoc(doc(db(), 'users/person-own'), { [field]: value, ...metadata() }));
    } else await assertSucceeds(batchProfile({ [field]: value }));
    const u = (await getDoc(doc(db(), 'users/person-own'))).data();
    const d = (await getDoc(doc(db(), 'user_directory/person-own'))).data();
    assert.equal(u[field], value); assert.equal(u.updated_by, 'person-own');
    assert.deepEqual(d, projection(u)); assert.ok(u.updated_at.toMillis() > stamp.toMillis());
  });
}
test('security, identity, photo, creation, extra fields and malformed profile denied', async () => {
  for (const extra of [{ access_role: 'leader' }, { active: false }, { login_enabled: false }, { email: 'x@example.test' },
    { photo_url: 'https://example.test/photo' }, { auth_uid: 'x' }, { role: 'admin' }, { position: 'president' },
    { created_at: serverTimestamp() }, { created_by: 'person-own' }, { name: 12 }, { address: 12 },
    { phone: deleteField() }, { preferred_language: false }]) {
    await assertFails(updateDoc(doc(db(), 'users/person-own'), { address: 'Changed', ...metadata(), ...extra }));
  }
  await assertFails(setDoc(doc(db(), 'users/new'), user()));
  await assertFails(deleteDoc(doc(db(), 'users/person-own')));
  await assertFails(batchProfile({ name: 'Changed' }, { name: 'Changed' }, db(), 'person-other'));
});
test('forged/missing metadata and projected User-only edits denied', async () => {
  const ref = doc(db(), 'users/person-own');
  for (const extra of [{}, { updated_at: stamp, updated_by: 'person-own' }, { updated_at: serverTimestamp(), updated_by: 'auth-own' }]) {
    await assertFails(updateDoc(ref, { address: 'Changed', ...extra }));
  }
  await assertFails(updateDoc(ref, { name: 'Changed', ...metadata() }));
});
test('standalone/desynchronized/extra-field/photo/active directory writes denied and batch rolls back', async () => {
  await assertFails(updateDoc(doc(db(), 'user_directory/person-own'), { name: 'Changed' }));
  for (const change of [{ name: 'Wrong' }, { name: 'Changed', email: 'private' }, { name: 'Changed', active: false },
    { name: 'Changed', photo_url: 'https://example.test/image' }]) {
    await assertFails(batchProfile({ name: 'Changed' }, change));
    assert.equal((await getDoc(doc(db(), 'users/person-own'))).data().name, 'Synthetic Member');
  }
  await assertFails(deleteDoc(doc(db(), 'user_directory/person-own')));
});
test('missing directory cannot be created; corrupt directory/User cannot be repaired', async () => {
  await env.withSecurityRulesDisabled(c => deleteDoc(doc(c.firestore(), 'user_directory/person-own')));
  const c = db(); const b = writeBatch(c);
  b.update(doc(c, 'users/person-own'), { name: 'Changed', ...metadata() });
  b.set(doc(c, 'user_directory/person-own'), projection(user({ name: 'Changed' })));
  await assertFails(b.commit());
  await assertFails(updateDoc(doc(c, 'users/person-own'), { address: 'Changed', ...metadata() }));
  for (const corrupt of [{ name: 'Stale' }, { extra: 'private' }, { active: false }]) {
    await seed('user_directory/person-own', { ...projection(user()), ...corrupt });
    await assertFails(batchProfile({ name: 'Changed' }));
    await assertFails(updateDoc(doc(c, 'users/person-own'), { address: 'Changed', ...metadata() }));
  }
  await seed('user_directory/person-own', projection(user()));
  await seed('users/person-own', user({ created_at: 'invalid' }));
  await assertFails(batchProfile({ name: 'Changed' }));
});
test('revocation prevents subsequent profile batch and protected reads', async () => {
  const c = db();
  await assertSucceeds(getDoc(doc(c, 'users/person-own')));
  await seed('auth_links/auth-own', { user_id: 'person-own', active: false });
  await assertFails(batchProfile({ name: 'Changed' }, { name: 'Changed' }, c));
  await assertFails(getDoc(doc(c, 'users/person-own')));
});
test('legacy and unknown collections/subcollections denied even to developer_admin', async () => {
  await seed('users/person-own', user({ access_role: 'developer_admin' }));
  const c = db();
  for (const path of ['requests/x','unknown/x','users/person-own/nested/x']) {
    await seed(path, { active: true });
    await assertFails(getDoc(doc(c, path)));
    await assertFails(setDoc(doc(c, path), { active: false }));
    await assertFails(deleteDoc(doc(c, path)));
  }
});

// Phase 1B: synthetic business fixtures, sharing the unchanged Phase 1A gate.
const roles = ['developer_admin','leader','executive','committee','member'];
const donor = (extra = {}) => ({ name: 'Synthetic Donor', phone: '00000000000', blood_group: 'A+',
  gender: null, photo_url: null, village: null, union: null, upazila: 'Synthetic', district: 'Synthetic',
  profession: null, linked_user_id: null, active: true, last_donated_at: null, total_donations: 0,
  created_at: serverTimestamp(), created_by: 'person-own', ...metadata(), ...extra });
const blood = (extra = {}) => ({ blood_group: 'A+', patient_name: null, hospital: 'Synthetic Hospital',
  location: 'Synthetic Location', contact_name: 'Synthetic Contact', contact_phone: '00000000000',
  required_at: null, status: 'active', created_by: 'person-own', created_at: serverTimestamp(),
  fulfilled_by: null, fulfilled_at: null, ...extra });
const readOnlyCollections = ['committee_terms','committee_assignments','committee_media','events','event_media','donations','notices','audit_logs'];
async function seedBusiness() {
  await env.withSecurityRulesDisabled(async context => {
    const c = context.firestore(); const b = writeBatch(c);
    const put = (path, data) => b.set(doc(c, path), data);
    for (const active of [true, false]) {
      const id = active ? 'active' : 'hidden';
      put(`committee_terms/${id}`, { name: 'Synthetic Term', start_year: 2025, end_year: 2027,
        start_date: null, end_date: null, active, group_photo_url: null, created_at: stamp, created_by: 'person-own' });
      put(`committee_assignments/${id}`, { user_id: 'person-own', term_id: id, position: 'president',
        active, assigned_at: stamp, assigned_by: 'person-own', ended_at: active ? null : stamp });
      put(`events/${id}`, { title: 'Synthetic Event', description: null, event_type: 'meeting',
        event_date: stamp, location: null, cover_image_url: null, active, created_at: stamp,
        created_by: 'person-own', updated_at: null, updated_by: null });
      put(`donors/${id}`, donor({ active, created_at: stamp, updated_at: stamp }));
      for (const parent of ['active','hidden','missing']) {
        const media = { image_url: 'https://example.test/image', caption: null, sort_order: 0,
          active, uploaded_at: stamp, uploaded_by: 'person-own', provider: null, provider_public_id: null };
        put(`committee_media/${parent}-${id}`, { ...media, term_id: parent });
        put(`event_media/${parent}-${id}`, { ...media, event_id: parent });
      }
    }
    put('donations/active', { donor_id: 'active', donor_name_snapshot: 'Synthetic Donor', blood_group_snapshot: 'A+',
      donation_date: stamp, location: null, hospital: null, recipient_name: null, recipient_contact: null,
      recorded_by: 'person-own', created_at: stamp, updated_at: null });
    for (const status of ['published','draft','archived','unknown']) put(`notices/${status}`, {
      title: 'Synthetic Notice', body: 'Synthetic Body', important: false, status,
      created_by: 'person-own', created_at: stamp, updated_by: null, updated_at: null });
    for (const status of ['active','fulfilled','cancelled','unknown']) put(`blood_requests/${status}`,
      blood({ status, created_at: stamp, fulfilled_by: status === 'fulfilled' ? 'person-own' : null,
        fulfilled_at: status === 'fulfilled' ? stamp : null }));
    put('audit_logs/active', { action: 'synthetic', actor_user_id: 'person-own', actor_auth_uid: 'auth-own',
      target_path: 'events/active', occurred_at: stamp, operation_id: 'synthetic', outcome: 'success', changes: {}, reason: null });
    await b.commit();
  });
}
const expectRead = (allowed, promise) => allowed ? assertSucceeds(promise) : assertFails(promise);
for (const role of roles) {
  test(`${role}: business read audiences, parents and constrained queries`, async () => {
    await seedBusiness(); await seed('users/person-own', user({ access_role: role }));
    const c = db(); const editorial = roles.indexOf(role) < 2; const history = roles.indexOf(role) < 3;
    for (const col of ['committee_terms','committee_assignments']) {
      for (const id of ['active','hidden']) await assertSucceeds(getDoc(doc(c, `${col}/${id}`)));
      await assertSucceeds(getDocs(collection(c, col)));
    }
    for (const parent of ['active','hidden','missing']) for (const state of ['active','hidden']) {
      await expectRead(parent !== 'missing' && (state === 'active' || editorial),
        getDoc(doc(c, `committee_media/${parent}-${state}`)));
      await expectRead(parent !== 'missing' && (parent === 'active' || editorial) && (state === 'active' || editorial),
        getDoc(doc(c, `event_media/${parent}-${state}`)));
    }
    for (const col of ['committee_media','event_media']) {
      const key = col === 'committee_media' ? 'term_id' : 'event_id';
      for (const parent of ['active','hidden','missing']) {
        await expectRead(parent !== 'missing' && (col === 'committee_media' || parent === 'active' || editorial),
          getDocs(query(collection(c, col), where(key,'==',parent), where('active','==',true), orderBy('sort_order'))));
        await expectRead(parent !== 'missing' && editorial,
          getDocs(query(collection(c, col), where(key,'==',parent), where('active','==',false))));
      }
      await assertFails(getDocs(collection(c, col)));
    }
    await assertSucceeds(getDoc(doc(c, 'events/active')));
    await expectRead(editorial, getDoc(doc(c, 'events/hidden')));
    await assertSucceeds(getDocs(query(collection(c, 'events'), where('active','==',true), orderBy('event_date','desc'))));
    await expectRead(editorial, getDocs(query(collection(c, 'events'), where('active','==',false))));
    await assertSucceeds(getDoc(doc(c, 'donors/active')));
    await assertFails(getDoc(doc(c, 'donors/hidden')));
    await assertFails(getDocs(collection(c, 'donors')));
    for (const [field, direction] of [['name','asc'],['total_donations','desc']])
      await assertSucceeds(getDocs(query(collection(c, 'donors'), where('active','==',true), orderBy(field,direction))));
    await expectRead(history, getDoc(doc(c, 'donations/active')));
    await expectRead(history, getDocs(collection(c, 'donations')));
    for (const status of ['published','draft','archived','unknown']) {
      const allowed = status === 'published' || (editorial && ['draft','archived'].includes(status));
      await expectRead(allowed, getDoc(doc(c, `notices/${status}`)));
      await expectRead(allowed, getDocs(query(collection(c, 'notices'), where('status','==',status))));
    }
    for (const status of ['active','fulfilled','cancelled','unknown']) {
      const allowed = status === 'active' || (history && ['fulfilled','cancelled'].includes(status));
      await expectRead(allowed, getDoc(doc(c, `blood_requests/${status}`)));
      await expectRead(allowed, getDocs(query(collection(c, 'blood_requests'), where('status','==',status))));
    }
    await expectRead(role === 'developer_admin', getDoc(doc(c, 'audit_logs/active')));
    await expectRead(role === 'developer_admin', getDocs(collection(c, 'audit_logs')));
  });
  test(`${role}: business write matrix and explicit denials`, async () => {
    await seedBusiness(); await seed('users/person-own', user({ access_role: role }));
    const c = db();
    for (const col of readOnlyCollections) {
      const id = col.endsWith('_media') ? 'active-active' : col === 'notices' ? 'published' : 'active';
      const ref = doc(c, `${col}/${id}`);
      await assertFails(setDoc(doc(c, `${col}/new`), { active: true }));
      await assertFails(setDoc(ref, { active: true }));
      await assertFails(updateDoc(ref, col === 'committee_terms' ? { group_photo_url: 'https://example.test/new' } : { active: false }));
      await assertFails(deleteDoc(ref));
    }
    await expectRead(role !== 'member', setDoc(doc(c, 'donors/new'), donor()));
    await expectRead(roles.indexOf(role) < 3, updateDoc(doc(c, 'donors/active'), { phone: '00000000001', ...metadata() }));
    await assertFails(updateDoc(doc(c, 'donors/hidden'), { phone: '00000000001', ...metadata() }));
    for (const extra of [{ active: false }, { total_donations: 1 }, { last_donated_at: stamp },
      { linked_user_id: 'person-own' }, { created_by: 'person-other' }, { created_at: serverTimestamp() },
      { access_role: 'leader' }, { updated_by: 'auth-own' }, { updated_at: stamp }])
      await assertFails(updateDoc(doc(c, 'donors/active'), { name: 'Changed', ...metadata(), ...extra }));
    await assertFails(updateDoc(doc(c, 'donors/hidden'), { active: true, ...metadata() }));
    await assertFails(deleteDoc(doc(c, 'donors/active')));
    await assertSucceeds(setDoc(doc(c, 'blood_requests/new'), blood()));
    for (const id of ['new','fulfilled','cancelled']) {
      const ref = doc(c, `blood_requests/${id}`);
      for (const change of [{ hospital: 'Changed' }, { status: 'fulfilled', fulfilled_by: 'person-own', fulfilled_at: serverTimestamp() },
        { status: 'cancelled' }, { status: 'active' }]) await assertFails(updateDoc(ref, change));
      await assertFails(setDoc(ref, blood())); await assertFails(deleteDoc(ref));
    }
  });
}
test('donor exact create schema and metadata reject fabrication, missing fields and wrong types', async () => {
  await seed('users/person-own', user({ access_role: 'developer_admin' }));
  const ref = doc(db(), 'donors/new');
  for (const extra of [{ total_donations: 1 }, { total_donations: -1 }, { total_donations: 0.5 },
    { last_donated_at: stamp }, { linked_user_id: 'person-own' }, { active: false },
    { created_by: 'auth-own' }, { updated_by: 'person-other' }, { created_at: stamp }, { updated_at: stamp },
    { access_role: 'leader' }, { auth_uid: 'auth-own' }, { photo_url: '' }, { photo_url: 'http://example.test/a' },
    { photo_url: 'https://example.test/' + 'x'.repeat(2048) }]) await assertFails(setDoc(ref, donor(extra)));
  for (const field of Object.keys(donor())) {
    const missing = donor(); delete missing[field]; await assertFails(setDoc(ref, missing));
    await assertFails(setDoc(ref, donor({ [field]: [] })));
  }
  await assertSucceeds(setDoc(ref, donor({ gender: 'other', photo_url: 'https://example.test/photo',
    village: 'Synthetic', union: 'Synthetic', profession: 'Synthetic' })));
  await assertFails(updateDoc(ref, metadata()));
  for (const field of ['name','phone','blood_group','gender','photo_url','village','union','upazila','district','profession']) {
    await assertFails(updateDoc(ref, { [field]: [], ...metadata() }));
    await assertFails(updateDoc(ref, { [field]: deleteField(), ...metadata() }));
    await assertSucceeds(updateDoc(ref, { [field]: field === 'photo_url' ? null : 'Changed', ...metadata() }));
  }
  await assertFails(setDoc(ref, donor())); // Replacing creation timestamps is not a profile edit.
  await seed('donors/legacy-invalid', donor({ phone: 42, created_at: stamp, updated_at: stamp }));
  await assertFails(updateDoc(doc(db(), 'donors/legacy-invalid'), { phone: '00000000000', ...metadata() }));
});
test('blood request exact create rejects forged actor/time/state/terminal fields and malformed schema', async () => {
  const ref = doc(db(), 'blood_requests/new');
  for (const extra of [{ created_by: 'auth-own' }, { created_by: 'person-other' }, { created_at: stamp },
    { status: 'open' }, { status: 'fulfilled' }, { status: 'cancelled' }, { fulfilled_by: 'person-own' },
    { fulfilled_at: stamp }, { required_at: '2026-01-01' }, { updated_at: serverTimestamp() }, { extra: true }])
    await assertFails(setDoc(ref, blood(extra)));
  for (const field of Object.keys(blood())) {
    const missing = blood(); delete missing[field]; await assertFails(setDoc(ref, missing));
    await assertFails(setDoc(ref, blood({ [field]: [] })));
  }
  await assertSucceeds(setDoc(ref, blood({ patient_name: 'Synthetic Patient', required_at: stamp })));
});
for (const [label, link, changes, claims] of [...badGates, ['unauthenticated'], ['absent link']]) {
  test(`business gate denies ${label} across all collections and permitted write paths`, async () => {
    await seedBusiness();
    if (link) await seed('auth_links/auth-own', link);
    if (changes) await seed('users/person-own', Object.fromEntries(Object.entries(user(changes)).filter(([,v]) => v !== undefined)));
    const c = label === 'unauthenticated' ? env.unauthenticatedContext().firestore() : db(label === 'absent link' ? 'unlinked' : 'auth-own', claims);
    for (const col of [...readOnlyCollections,'donors','blood_requests']) {
      const id = col.endsWith('_media') ? 'active-active' : col === 'notices' ? 'published' : 'active';
      await assertFails(getDoc(doc(c, `${col}/${id}`)));
      await assertFails(getDocs(query(collection(c, col), where('active','==',true))));
    }
    await assertFails(setDoc(doc(c, 'donors/new'), donor()));
    await assertFails(updateDoc(doc(c, 'donors/active'), { name: 'Changed', ...metadata() }));
    await assertFails(setDoc(doc(c, 'blood_requests/new'), blood()));
  });
}
test('parent hide revokes existing client media reads without child rewrites; malformed states fail closed', async () => {
  await seedBusiness(); const c = db();
  await assertSucceeds(getDoc(doc(c, 'event_media/active-active')));
  await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'events/active'), { active: false }));
  await assertFails(getDoc(doc(c, 'event_media/active-active')));
  await assertFails(getDocs(query(collection(c, 'event_media'), where('event_id','==','active'), where('active','==',true))));
  await seed('users/person-own', user({ access_role: 'developer_admin' }));
  for (const col of ['events','event_media','committee_media','donors','notices','blood_requests']) {
    for (const state of [{}, { active: 'true', status: 'unknown' }]) {
      await seed(`${col}/malformed`, { event_id: 'active', term_id: 'active', ...state });
      await assertFails(getDoc(doc(c, `${col}/malformed`)));
    }
  }
});

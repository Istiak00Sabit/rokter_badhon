import assert from 'node:assert/strict';
import test from 'node:test';

import { approveRegistration, rejectRegistration } from '../src/admission.js';
import { schemaFields } from '../src/policy.js';

const TIME = { toMillis: () => 1 };
const SERVER_TIME = { __serverTimestamp: true, toMillis: () => 2 };

class FakeReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
    this.id = path.split('/').at(-1);
  }
}

class FakeCollection {
  constructor(store, name) {
    this.store = store;
    this.name = name;
  }

  doc(id) {
    const documentId = id ?? `generated-user-${++this.store.generated}`;
    return new FakeReference(this.store, `${this.name}/${documentId}`);
  }

  where(field, operator, value) {
    return new FakeQuery(this.store, this.name, [{ field, operator, value }]);
  }
}

class FakeQuery {
  constructor(store, collection, filters) {
    this.store = store;
    this.collection = collection;
    this.filters = filters;
  }

  where(field, operator, value) {
    return new FakeQuery(this.store, this.collection, [
      ...this.filters,
      { field, operator, value },
    ]);
  }
}

class FakeTransaction {
  constructor(store) {
    this.store = store;
    this.writes = [];
  }

  async get(reference) {
    if (reference instanceof FakeQuery) {
      const docs = [...this.store.documents.entries()]
        .filter(([path, value]) => {
          if (!path.startsWith(`${reference.collection}/`)) return false;
          return reference.filters.every(({ field, operator, value: expected }) =>
            operator === '==' && value[field] === expected,
          );
        })
        .map(([path, value]) => ({
          id: path.split('/').at(-1),
          data: () => value,
        }));
      return { empty: docs.length === 0, docs };
    }
    const value = this.store.documents.get(reference.path);
    return { exists: value !== undefined, data: () => value };
  }

  create(reference, value) {
    if (this.store.documents.has(reference.path)) throw new Error(`already exists: ${reference.path}`);
    this.writes.push({ type: 'create', reference, value });
  }

  update(reference, value) {
    if (!this.store.documents.has(reference.path)) throw new Error(`missing: ${reference.path}`);
    this.writes.push({ type: 'update', reference, value });
  }

  commit() {
    for (const write of this.writes) {
      if (write.type === 'create') {
        this.store.documents.set(write.reference.path, write.value);
      } else {
        this.store.documents.set(write.reference.path, {
          ...this.store.documents.get(write.reference.path),
          ...write.value,
        });
      }
    }
  }
}

class FakeFirestore {
  constructor(entries) {
    this.documents = new Map(entries);
    this.generated = 0;
  }

  collection(name) {
    return new FakeCollection(this, name);
  }

  async runTransaction(callback) {
    const transaction = new FakeTransaction(this);
    const result = await callback(transaction);
    transaction.commit();
    return result;
  }
}

class FakeAuth {
  constructor(users) {
    this.users = new Map(users);
  }

  async getUser(uid) {
    if (!this.users.has(uid)) {
      const error = new Error('not found');
      error.code = 'auth/user-not-found';
      throw error;
    }
    return this.users.get(uid);
  }
}

function operatorUser(role = 'developer_admin', changes = {}) {
  return {
    name: 'Operator',
    phone: '01000000000',
    email: 'operator@example.test',
    blood_group: null,
    profession: null,
    address: null,
    photo_url: null,
    access_role: role,
    active: true,
    login_enabled: true,
    preferred_language: null,
    created_at: TIME,
    created_by: null,
    updated_at: TIME,
    updated_by: null,
    ...changes,
  };
}

function pendingRequest(changes = {}) {
  return {
    auth_uid: 'applicant-uid',
    name: 'Applicant',
    phone: '01111111111',
    email: 'applicant@example.test',
    status: 'pending',
    requested_at: TIME,
    approved_by: null,
    approved_at: null,
    rejected_by: null,
    rejected_at: null,
    linked_user_id: null,
    ...changes,
  };
}

function fixture({ operatorRole = 'developer_admin', operatorChanges, requestChanges, authChanges, entries = [] } = {}) {
  const db = new FakeFirestore([
    ['auth_links/operator-uid', { user_id: 'operator-user', active: true, created_at: TIME, created_by: 'seed' }],
    ['users/operator-user', operatorUser(operatorRole, operatorChanges)],
    ['registration_requests/applicant-uid', pendingRequest(requestChanges)],
    ...entries,
  ]);
  const auth = new FakeAuth([
    ['operator-uid', { uid: 'operator-uid', email: 'operator@example.test', emailVerified: true, disabled: false }],
    ['applicant-uid', { uid: 'applicant-uid', email: 'applicant@example.test', emailVerified: true, disabled: false, ...authChanges }],
  ]);
  return { db, auth };
}

function approveArgs(overrides = {}) {
  const { db, auth } = fixture(overrides.fixture);
  return {
    db,
    auth,
    serverTimestamp: () => SERVER_TIME,
    operatorUid: 'operator-uid',
    applicantUid: 'applicant-uid',
    targetRole: 'member',
    operationId: 'operation-1',
    reason: 'Identity reviewed under the approved procedure.',
    ...overrides,
    db,
    auth,
  };
}

async function rejectsCode(promise, code) {
  await assert.rejects(promise, (error) => error.code === code);
}

test('valid developer_admin approval creates exact atomic admission records', async () => {
  const args = approveArgs({ targetRole: 'member' });
  const result = await approveRegistration(args);
  const user = args.db.documents.get(`users/${result.userId}`);
  const directory = args.db.documents.get(`user_directory/${result.userId}`);
  const link = args.db.documents.get('auth_links/applicant-uid');
  const request = args.db.documents.get('registration_requests/applicant-uid');
  const audit = args.db.documents.get('audit_logs/operation-1');

  assert.deepEqual(new Set(Object.keys(user)), schemaFields.user);
  assert.deepEqual(directory, {
    name: user.name,
    phone: user.phone,
    blood_group: user.blood_group,
    profession: user.profession,
    photo_url: user.photo_url,
    active: user.active,
  });
  assert.deepEqual(new Set(Object.keys(link)), schemaFields.link);
  assert.equal(user.access_role, 'member');
  assert.equal(user.login_enabled, true);
  assert.equal(request.status, 'approved');
  assert.equal(request.linked_user_id, result.userId);
  assert.deepEqual(new Set(Object.keys(audit)), new Set([
    'action', 'actor_user_id', 'actor_auth_uid', 'target_path', 'occurred_at',
    'operation_id', 'outcome', 'changes', 'reason',
  ]));
  assert.equal(audit.action, 'registration.approve');
});

test('leader may approve a new member', async () => {
  const args = approveArgs({
    fixture: { operatorRole: 'leader' },
    targetRole: 'member',
    operationId: 'leader-member',
  });
  const result = await approveRegistration(args);
  assert.equal(args.db.documents.get(`users/${result.userId}`).access_role, 'member');
});

test('approval-time elevation and developer_admin creation are denied', async () => {
  for (const targetRole of ['committee', 'executive', 'leader', 'developer_admin']) {
    await rejectsCode(
      approveRegistration(approveArgs({ targetRole })),
      'unauthorized_role',
    );
  }
  await rejectsCode(
    approveRegistration(approveArgs({ fixture: { operatorRole: 'leader' }, targetRole: 'leader' })),
    'unauthorized_role',
  );
});

test('unverified applicant and mismatched request email are denied', async () => {
  await rejectsCode(
    approveRegistration(approveArgs({ fixture: { authChanges: { emailVerified: false } } })),
    'email_unverified',
  );
  await rejectsCode(
    approveRegistration(approveArgs({ fixture: { requestChanges: { email: 'other@example.test' } } })),
    'email_mismatch',
  );
});

test('inactive operator and missing or broken operator link fail closed', async () => {
  await rejectsCode(
    approveRegistration(approveArgs({ fixture: { operatorChanges: { active: false } } })),
    'operator_not_admitted',
  );

  const missing = approveArgs();
  missing.db.documents.delete('auth_links/operator-uid');
  await rejectsCode(approveRegistration(missing), 'missing');

  const broken = approveArgs();
  broken.db.documents.set('auth_links/operator-uid', {
    user_id: 'missing-user', active: true, created_at: TIME, created_by: 'seed',
  });
  await rejectsCode(approveRegistration(broken), 'missing');

  await rejectsCode(
    approveRegistration(approveArgs({ fixture: { operatorChanges: { photo_url: 'http://unsafe.test/photo.jpg' } } })),
    'malformed',
  );
});

test('duplicate auth link and non-pending request are denied', async () => {
  await rejectsCode(
    approveRegistration(approveArgs({ fixture: { entries: [['auth_links/applicant-uid', { user_id: 'other', active: false, created_at: TIME, created_by: 'seed' }]] } })),
    'duplicate_auth_link',
  );
  await rejectsCode(
    approveRegistration(approveArgs({ fixture: { requestChanges: { status: 'approved', approved_by: 'operator-user', approved_at: TIME, linked_user_id: 'old-user' } } })),
    'already_decided',
  );
});

test('active link already targeting the generated User ID is denied', async () => {
  const args = approveArgs({
    fixture: {
      entries: [[
        'auth_links/dangling-uid',
        { user_id: 'generated-user-1', active: true, created_at: TIME, created_by: 'seed' },
      ]],
    },
  });
  await rejectsCode(approveRegistration(args), 'duplicate_user_link');
  assert.equal(args.db.documents.get('registration_requests/applicant-uid').status, 'pending');
});

test('existing organization identity blocks duplicate User admission atomically', async () => {
  const args = approveArgs({
    fixture: {
      entries: [['users/existing-user', operatorUser('member', {
        email: 'applicant@example.test',
        phone: '09999999999',
      })]],
    },
  });
  const before = new Set(args.db.documents.keys());
  await rejectsCode(approveRegistration(args), 'identity_conflict');
  assert.deepEqual(new Set(args.db.documents.keys()), before);
  assert.equal(args.db.documents.get('registration_requests/applicant-uid').status, 'pending');
});

test('failed approval leaves no partial writes', async () => {
  const args = approveArgs({ fixture: { authChanges: { emailVerified: false } } });
  const before = new Set(args.db.documents.keys());
  await rejectsCode(approveRegistration(args), 'email_unverified');
  assert.deepEqual(new Set(args.db.documents.keys()), before);
  assert.equal(args.db.documents.get('registration_requests/applicant-uid').status, 'pending');
});

test('rejection updates only decision fields and writes audit atomically', async () => {
  const { db, auth } = fixture({ operatorRole: 'leader' });
  await rejectRegistration({
    db,
    auth,
    serverTimestamp: () => SERVER_TIME,
    operatorUid: 'operator-uid',
    applicantUid: 'applicant-uid',
    operationId: 'reject-1',
    reason: 'Application did not pass the reviewed identity procedure.',
  });
  const request = db.documents.get('registration_requests/applicant-uid');
  assert.equal(request.status, 'rejected');
  assert.equal(request.rejected_by, 'operator-user');
  assert.equal(request.approved_by, null);
  assert.equal(request.linked_user_id, null);
  assert.equal(db.documents.get('audit_logs/reject-1').action, 'registration.reject');
  assert.equal(db.documents.has('auth_links/applicant-uid'), false);
});

test('retry protection rejects decided request without duplicate records', async () => {
  const args = approveArgs();
  await approveRegistration(args);
  const paths = new Set(args.db.documents.keys());
  await rejectsCode(approveRegistration(args), 'already_decided');
  assert.deepEqual(new Set(args.db.documents.keys()), paths);
  assert.equal([...args.db.documents.keys()].filter((path) => path.startsWith('audit_logs/')).length, 1);
});

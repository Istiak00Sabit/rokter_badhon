export const TIME = { toMillis: () => 1 };
export const SERVER_TIME = { __serverTimestamp: true, toMillis: () => 2 };

class FakeReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
    this.id = path.split('/').at(-1);
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

export class FakeFirestore {
  constructor(entries = []) {
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

export class FakeAuth {
  constructor(users = []) {
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

export function adminUser(changes = {}) {
  return {
    name: 'Old Admin',
    phone: '01000000000',
    email: 'old-admin@example.test',
    blood_group: null,
    profession: null,
    address: null,
    photo_url: null,
    access_role: 'developer_admin',
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

export function directoryFor(user) {
  return {
    name: user.name,
    phone: user.phone,
    blood_group: user.blood_group,
    profession: user.profession,
    photo_url: user.photo_url,
    active: user.active,
  };
}

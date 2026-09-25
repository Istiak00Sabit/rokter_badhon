import {
  AdmissionError,
  parseAuthLink,
  parseDirectory,
  parseUser,
  projectDirectory,
} from './policy.js';
import { bootstrapDeveloperAdmin } from './developer_admin.js';
import { internalAuthEmailForPhone } from './auth_identity.js';

export const LOCAL_TEST_ADMIN = Object.freeze({
  email: 'a@a.com',
  password: '123456',
  name: 'Local Test Admin',
  phone: '01000000000',
});

const LOCAL_INTERNAL_EMAIL = internalAuthEmailForPhone(LOCAL_TEST_ADMIN.phone);

function isMissingAuthUser(error) {
  return error?.code === 'auth/user-not-found';
}

async function createLocalAuthUser(auth) {
  return auth.createUser({
    email: LOCAL_INTERNAL_EMAIL,
    password: LOCAL_TEST_ADMIN.password,
    emailVerified: false,
    disabled: false,
    displayName: LOCAL_TEST_ADMIN.name,
  });
}

function sameProjection(user, directory) {
  const expected = projectDirectory(user);
  return Object.keys(expected).every((key) => expected[key] === directory[key]);
}

export async function seedLocalTestAdmin({
  projectId,
  db,
  auth,
  serverTimestamp,
}) {
  if (projectId !== 'demo-rokter-badhon') {
    throw new AdmissionError(
      'unsafe_target',
      'The local test-admin seed runs only against demo-rokter-badhon.',
    );
  }

  let authRecord;
  try {
    authRecord = await auth.getUserByEmail(LOCAL_INTERNAL_EMAIL);
  } catch (error) {
    if (!isMissingAuthUser(error)) throw error;
    authRecord = await createLocalAuthUser(auth);
  }

  authRecord = await auth.updateUser(authRecord.uid, {
    password: LOCAL_TEST_ADMIN.password,
    emailVerified: false,
    disabled: false,
    displayName: LOCAL_TEST_ADMIN.name,
  });

  const read = (reference) => db.runTransaction((transaction) => transaction.get(reference));
  const linkSnapshot = await read(db.collection('auth_links').doc(authRecord.uid));
  if (linkSnapshot.exists) {
    const link = parseAuthLink(linkSnapshot.data(), authRecord.uid);
    const userSnapshot = await read(db.collection('users').doc(link.user_id));
    if (!userSnapshot.exists) {
      throw new AdmissionError('ambiguous_state', 'Seeded AuthLink has no User.');
    }
    const user = parseUser(userSnapshot.data(), userSnapshot.id);
    const directorySnapshot = await read(db.collection('user_directory').doc(user.id));
    if (!directorySnapshot.exists) {
      throw new AdmissionError('ambiguous_state', 'Seeded User has no directory projection.');
    }
    const directory = parseDirectory(directorySnapshot.data(), directorySnapshot.id);
    if (!link.active || user.phone !== LOCAL_TEST_ADMIN.phone ||
        user.access_role !== 'developer_admin' || !user.active || !user.login_enabled ||
        !directory.active || !sameProjection(user, directory)) {
      throw new AdmissionError('ambiguous_state', 'Existing local test admin is not exactly admissible.');
    }
    return {
      action: 'local_test_admin_already_seeded',
      userId: user.id,
      operationId: 'local-test-admin-seed',
    };
  }

  return bootstrapDeveloperAdmin({
    db,
    auth,
    serverTimestamp,
    authUid: authRecord.uid,
    identity: {
      name: LOCAL_TEST_ADMIN.name,
      phone: LOCAL_TEST_ADMIN.phone,
      email: LOCAL_TEST_ADMIN.email,
      blood_group: null,
      profession: 'TEST ONLY',
      address: null,
      preferred_language: 'bn',
    },
    operationId: 'local-test-admin-seed',
    reason: 'TEST-ONLY developer_admin bootstrap for the local Firebase emulators.',
  });
}

import {
  AdmissionError,
  parseAuthLink,
  parseDirectory,
  parseUser,
  projectDirectory,
} from './policy.js';
import { bootstrapDeveloperAdmin } from './developer_admin.js';

export const LOCAL_TEST_ADMIN = Object.freeze({
  email: 'admin@test.rokterbadhon.local',
  password: 'LocalTestAdmin!2026',
  name: 'Local Test Admin',
  phone: '01000000000',
});

function isMissingAuthUser(error) {
  return error?.code === 'auth/user-not-found';
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
    authRecord = await auth.getUserByEmail(LOCAL_TEST_ADMIN.email);
  } catch (error) {
    if (!isMissingAuthUser(error)) throw error;
    authRecord = await auth.createUser({
      email: LOCAL_TEST_ADMIN.email,
      password: LOCAL_TEST_ADMIN.password,
      emailVerified: true,
      disabled: false,
      displayName: LOCAL_TEST_ADMIN.name,
    });
  }

  authRecord = await auth.updateUser(authRecord.uid, {
    password: LOCAL_TEST_ADMIN.password,
    emailVerified: true,
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
    if (!link.active || user.email !== LOCAL_TEST_ADMIN.email ||
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

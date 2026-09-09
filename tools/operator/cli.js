#!/usr/bin/env node
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import { approveRegistration, rejectRegistration } from './src/admission.js';
import { bootstrapDeveloperAdmin, recoverDeveloperAdmin } from './src/developer_admin.js';
import { AdmissionError } from './src/policy.js';
import { assertSafeTarget } from './src/safety.js';

function parseArguments(values) {
  const [command, ...rest] = values;
  const options = {};
  for (let index = 0; index < rest.length; index += 2) {
    const key = rest[index];
    const value = rest[index + 1];
    if (!key?.startsWith('--') || value === undefined) {
      throw new AdmissionError('invalid_argument', 'Arguments must use --name value pairs.');
    }
    options[key.slice(2)] = value;
  }
  return { command, options };
}

async function main() {
  const { command, options } = parseArguments(process.argv.slice(2));
  const projectId = options['project-id'];
  console.log(`Target Firebase project: ${projectId ?? '(missing)'}`);
  assertSafeTarget({
    projectId,
    firestoreEmulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
    authEmulatorHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
  });

  const appOptions = { projectId };
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    appOptions.credential = applicationDefault();
  }
  const app = initializeApp(appOptions);
  const dependencies = {
    db: getFirestore(app),
    auth: getAuth(app),
    serverTimestamp: () => FieldValue.serverTimestamp(),
    operatorUid: options['operator-uid'],
    applicantUid: options['applicant-uid'],
    operationId: options['operation-id'],
    reason: options.reason,
  };

  let result;
  if (command === 'approve') {
    result = await approveRegistration({
      ...dependencies,
      targetRole: options['target-role'],
    });
  } else if (command === 'reject') {
    result = await rejectRegistration(dependencies);
  } else if (command === 'bootstrap-developer-admin' || command === 'recover-developer-admin') {
    const protectedDependencies = {
      db: dependencies.db,
      auth: dependencies.auth,
      serverTimestamp: dependencies.serverTimestamp,
      authUid: options['auth-uid'],
      operationId: options['operation-id'],
      reason: options.reason,
      identity: {
        name: options.name,
        phone: options.phone,
        email: options.email,
        blood_group: options['blood-group'],
        profession: options.profession,
        address: options.address,
        preferred_language: options['preferred-language'],
      },
    };
    result = command === 'bootstrap-developer-admin'
      ? await bootstrapDeveloperAdmin(protectedDependencies)
      : await recoverDeveloperAdmin({
        ...protectedDependencies,
        oldUserId: options['old-user-id'],
      });
  } else {
    throw new AdmissionError(
      'invalid_argument',
      'Command must be approve, reject, bootstrap-developer-admin, or recover-developer-admin.',
    );
  }
  console.log(`${result.action}; operation_id=${result.operationId}${result.userId ? `; user_id=${result.userId}` : ''}`);
}

main().catch((error) => {
  const code = error instanceof AdmissionError ? error.code : 'operation_failed';
  console.error(`${code}: ${error.message}`);
  process.exitCode = 1;
});

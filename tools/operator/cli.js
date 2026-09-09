#!/usr/bin/env node
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import { approveRegistration, rejectRegistration } from './src/admission.js';
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
  } else {
    throw new AdmissionError('invalid_argument', 'Command must be approve or reject.');
  }
  console.log(`${result.action}; operation_id=${result.operationId}${result.userId ? `; user_id=${result.userId}` : ''}`);
}

main().catch((error) => {
  const code = error instanceof AdmissionError ? error.code : 'operation_failed';
  console.error(`${code}: ${error.message}`);
  process.exitCode = 1;
});

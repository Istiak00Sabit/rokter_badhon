#!/usr/bin/env node
// Read-only production preflight. No PII, Auth UIDs or credentials are printed.
import { applicationDefault, deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { inspectCommitteeImport, classifyRegistrationIdentity } from './src/production_preflight.js';
import { assertSafeTarget } from './src/safety.js';

function parseArgs(values) {
  const args = {};
  for (let i = 0; i < values.length; i += 2) {
    if (!values[i]?.startsWith('--') || !values[i + 1]) {
      throw new Error('Use --name value pairs.');
    }
    args[values[i].slice(2)] = values[i + 1];
  }
  return args;
}

async function inspectPendingRequests(db, auth, limit) {
  if (!Number.isInteger(limit) || limit < 1 || limit > 200) {
    throw new Error('pending-limit must be between 1 and 200.');
  }
  const snapshot = await db.collection('registration_requests')
    .where('status', '==', 'pending').limit(limit).get();
  const counts = {
    scanned: snapshot.size,
    phoneIdentity: 0,
    legacyEmailIdentity: 0,
    disabledAuth: 0,
    missingAuth: 0,
    invalidRegistrationPhone: 0,
    other: 0,
    possibleMore: snapshot.size === limit,
  };
  for (const item of snapshot.docs) {
    try {
      const account = await auth.getUser(item.id);
      const type = classifyRegistrationIdentity({
        phone: item.data().phone,
        authEmail: account.email,
        authDisabled: account.disabled,
      });
      if (type === 'phone_identity') counts.phoneIdentity++;
      else if (type === 'legacy_email_identity') counts.legacyEmailIdentity++;
      else if (type === 'disabled_auth') counts.disabledAuth++;
      else if (type === 'invalid_registration_phone') counts.invalidRegistrationPhone++;
      else counts.other++;
    } catch (error) {
      if (error?.code === 'auth/user-not-found') counts.missingAuth++;
      else throw error;
    }
  }
  return counts;
}

async function inspectAuthWithoutRequest(db, auth, maxUsers) {
  if (maxUsers === 0) return { enabled: false, scanned: 0, incomplete: true };
  if (!Number.isInteger(maxUsers) || maxUsers < 1 || maxUsers > 1000) {
    throw new Error('auth-scan-limit must be from 0 to 1000.');
  }
  const batch = await auth.listUsers(maxUsers);
  const legacy = batch.users.filter((record) =>
    record.email && !record.email.toLowerCase().endsWith('@auth.rokterbadhon.internal'));
  let withoutLinkOrRequest = 0;
  for (const record of legacy) {
    const [link, request] = await Promise.all([
      db.collection('auth_links').doc(record.uid).get(),
      db.collection('registration_requests').doc(record.uid).get(),
    ]);
    if (!link.exists && !request.exists) withoutLinkOrRequest++;
  }
  return {
    enabled: true,
    scanned: batch.users.length,
    legacyEmailAuthCount: legacy.length,
    legacyUnlinkedWithoutRequest: withoutLinkOrRequest,
    incomplete: Boolean(batch.pageToken),
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const projectId = args['project-id'];
  const production = projectId === 'rokterbadhon-b247b';
  assertSafeTarget({
    projectId,
    firestoreEmulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
    authEmulatorHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
    mode: production ? 'provision' : 'emulator',
    allowProduction: production && args['confirm-project-id'] === projectId,
    confirmedProjectId: args['confirm-project-id'],
  });
  const app = initializeApp({
    projectId,
    ...(production ? { credential: applicationDefault() } : {}),
  });
  try {
    const db = getFirestore(app);
    const auth = getAuth(app);
    const [committee, registrations, historicalAuth] = await Promise.all([
      inspectCommitteeImport({ projectId, db, auth }),
      inspectPendingRequests(db, auth, Number(args['pending-limit'] ?? '100')),
      inspectAuthWithoutRequest(db, auth, Number(args['auth-scan-limit'] ?? '0')),
    ]);
    const report = {
      mode: 'READ_ONLY',
      production,
      committee,
      pendingRegistrations: registrations,
      historicalAuth,
      requiresOwnerReview: !committee.safeToConsiderImport ||
        committee.counts.existingPhoneAuthIdentities > 0 ||
        registrations.legacyEmailIdentity > 0 ||
        (historicalAuth.legacyUnlinkedWithoutRequest ?? 0) > 0,
      writesPerformed: 0,
      deployedRulesAndIndexesVerified: false,
    };
    console.log(JSON.stringify(report, null, 2));
    if (report.requiresOwnerReview) process.exitCode = 2;
  } finally {
    await deleteApp(app);
  }
}

main().catch((error) => {
  // Do not print arbitrary upstream error text, which may include private data.
  console.error('Preflight failed (' + (error.code || error.name || 'unknown') +
    '). Check project identity, read-only ADC permissions, emulator endpoints and indexes.');
  process.exitCode = 1;
});

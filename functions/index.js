import { randomUUID } from 'node:crypto';
import { initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { approveRegistration, rejectRegistration } from './src/admission.js';
import { assignAccessRole, setUserActive, setLoginEnabled, updateOwnPhoto } from './src/account.js';
import { AdmissionError, parseAuthLink, parseUser, authorizeOperatorForRoles } from './src/policy.js';

if (getApps().length === 0) initializeApp();
const db = getFirestore();
const auth = getAuth();
const region = 'asia-south1';

function id(value, label) {
  if (typeof value !== 'string' || !value.trim() || value.length > 160 ||
      value.includes('/') || value !== value.trim()) {
    throw new HttpsError('invalid-argument', 'Invalid ' + label);
  }
  return value;
}
function reason(value) {
  if (typeof value !== 'string' || value.trim().length < 10 ||
      value.trim().length > 500) {
    throw new HttpsError('invalid-argument', 'A review reason of 10–500 characters is required.');
  }
  return value.trim();
}
function dataObject(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Invalid request.');
  }
  return value;
}
function oneOf(value, values) {
  if (!values.includes(value)) throw new HttpsError('invalid-argument', 'Unsupported operation.');
  return value;
}
async function admitted(request, roles) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please sign in.');
  const [record, linkDocument] = await Promise.all([
    auth.getUser(uid),
    db.collection('auth_links').doc(uid).get(),
  ]);
  if (!linkDocument.exists) throw new HttpsError('permission-denied', 'Account not admitted.');
  const link = parseAuthLink(linkDocument.data(), uid);
  const userDocument = await db.collection('users').doc(link.user_id).get();
  if (!userDocument.exists) throw new HttpsError('permission-denied', 'Account not admitted.');
  const user = parseUser(userDocument.data(), link.user_id);
  authorizeOperatorForRoles({ authRecord: record, link, user, allowedRoles: roles });
  return { uid, user };
}
function dependencies(uid, why) {
  return {
    db, auth, serverTimestamp: () => FieldValue.serverTimestamp(),
    operatorUid: uid, operationId: randomUUID(), reason: why,
  };
}
function sanitizedError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AdmissionError) {
    if (['unauthorized', 'unauthorized_target', 'operator_not_admitted', 'protected_admin'].includes(error.code)) {
      return new HttpsError('permission-denied', 'Permission denied.');
    }
    if (['invalid_argument', 'unauthorized_role'].includes(error.code)) {
      return new HttpsError('invalid-argument', 'Invalid request.');
    }
    return new HttpsError('failed-precondition', error.code);
  }
  logger.error('Admin callable failed', { type: error?.code || 'internal' });
  return new HttpsError('internal', 'Unable to complete the operation.');
}
async function guarded(fn) {
  try { return await fn(); } catch (error) { throw sanitizedError(error); }
}

// Auth UID, link and current User role are checked server-side on every call;
// no client-supplied role, operator ID, audit actor or User path is trusted.
export const adminReviewRegistration = onCall({ region, timeoutSeconds: 60 }, (request) => guarded(async () => {
  const actor = await admitted(request, ['developer_admin']);
  const body = dataObject(request.data);
  const applicantUid = id(body.applicantUid, 'applicant UID');
  if (applicantUid === actor.uid) throw new HttpsError('permission-denied', 'Self-review is not allowed.');
  const action = oneOf(body.action, ['approve', 'reject']);
  const why = reason(body.reason);
  const opts = { ...dependencies(actor.uid, why), applicantUid };
  return action === 'approve'
      ? approveRegistration({ ...opts, targetRole: 'member' })
      : rejectRegistration(opts);
}));

export const adminListUsers = onCall({ region, timeoutSeconds: 30 }, (request) => guarded(async () => {
  await admitted(request, ['developer_admin']);
  const snapshot = await db.collection('users').limit(80).get();
  return {
    users: snapshot.docs.map((item) => {
      const u = parseUser(item.data(), item.id);
      return {
        id: item.id, name: u.name, phone: u.phone,
        role: u.access_role, active: u.active, loginEnabled: u.login_enabled,
      };
    }),
    hasMore: snapshot.size === 80,
  };
}));

export const adminManageUser = onCall({ region, timeoutSeconds: 60 }, (request) => guarded(async () => {
  const actor = await admitted(request, ['developer_admin']);
  const body = dataObject(request.data);
  const userId = id(body.userId, 'user ID');
  if (userId === actor.user.id) throw new HttpsError('permission-denied', 'Self-management is not allowed.');
  const action = oneOf(body.action, ['role', 'activate', 'deactivate', 'enable_login', 'disable_login']);
  const opts = { ...dependencies(actor.uid, reason(body.reason)), userId };
  if (action === 'role') {
    const targetRole = oneOf(body.role, ['member', 'committee', 'executive', 'leader']);
    return assignAccessRole({ ...opts, targetRole });
  }
  if (action === 'activate' || action === 'deactivate') {
    return setUserActive({ ...opts, active: action === 'activate' });
  }
  return setLoginEnabled({ ...opts, enabled: action === 'enable_login' });
}));

// Profile photo must already have a verified HTTPS hosting URL.
// This never writes committee membership or positions to Firestore.
export const updateMyProfilePhoto = onCall({ region, timeoutSeconds: 60 }, (request) => guarded(async () => {
  const actor = await admitted(request, ['developer_admin', 'leader', 'executive', 'committee', 'member']);
  const body = dataObject(request.data);
  const url = body.photoUrl;
  if (url !== null && (typeof url !== 'string' || url.length > 2048 ||
      !/^https:\/\/[^/]+/.test(url))) {
    throw new HttpsError('invalid-argument', 'A valid HTTPS photo URL is required.');
  }
  return updateOwnPhoto({
    ...dependencies(actor.uid, 'User-requested profile photo update'),
    photoUrl: url,
  });
}));

import {
  AdmissionError,
  authorizeOperator,
  authorizeTargetRole,
  parseAuthLink,
  parsePendingRequest,
  parseUser,
  projectDirectory,
  validateId,
} from './policy.js';

function requireText(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new AdmissionError('invalid_argument', `${label} is required.`);
  }
  return value.trim();
}

function requireDocument(snapshot, label) {
  if (!snapshot?.exists) {
    throw new AdmissionError('missing', `${label} does not exist.`);
  }
  return snapshot.data();
}

async function getAuthRecord(auth, uid, label) {
  try {
    return await auth.getUser(uid);
  } catch (error) {
    throw new AdmissionError('auth_identity_missing', `${label} Firebase Auth account does not exist.`);
  }
}

async function resolveOperator(transaction, db, operatorUid, authRecord) {
  const linkReference = db.collection('auth_links').doc(operatorUid);
  const linkSnapshot = await transaction.get(linkReference);
  const link = parseAuthLink(requireDocument(linkSnapshot, 'Operator auth link'), operatorUid);
  const userReference = db.collection('users').doc(link.user_id);
  const userSnapshot = await transaction.get(userReference);
  const user = parseUser(requireDocument(userSnapshot, 'Operator User'), link.user_id);
  authorizeOperator({ authRecord, link, user });
  return user;
}

function validateApplicantAuth(applicantAuth, request) {
  if (applicantAuth.disabled === true) {
    throw new AdmissionError('applicant_disabled', 'Applicant Firebase Auth account is disabled.');
  }
  if (applicantAuth.emailVerified !== true) {
    throw new AdmissionError('email_unverified', 'Applicant email is not verified.');
  }
  if (typeof applicantAuth.email !== 'string' || applicantAuth.email !== request.email) {
    throw new AdmissionError('email_mismatch', 'Applicant Auth email does not match the registration request.');
  }
}

function validateCommonInput({ operatorUid, applicantUid, operationId, reason }) {
  validateId(operatorUid, 'operator UID');
  validateId(applicantUid, 'applicant UID');
  validateId(operationId, 'operation ID');
  requireText(reason, 'reason');
  if (operatorUid === applicantUid) {
    throw new AdmissionError('self_review', 'An operator cannot decide their own registration request.');
  }
}

export async function approveRegistration({
  db,
  auth,
  serverTimestamp,
  operatorUid,
  applicantUid,
  targetRole,
  operationId,
  reason,
}) {
  validateCommonInput({ operatorUid, applicantUid, operationId, reason });
  requireText(targetRole, 'target role');
  const [operatorAuth, applicantAuth] = await Promise.all([
    getAuthRecord(auth, operatorUid, 'Operator'),
    getAuthRecord(auth, applicantUid, 'Applicant'),
  ]);

  const requestReference = db.collection('registration_requests').doc(applicantUid);
  const applicantLinkReference = db.collection('auth_links').doc(applicantUid);
  const userReference = db.collection('users').doc();
  const directoryReference = db.collection('user_directory').doc(userReference.id);
  const auditReference = db.collection('audit_logs').doc(operationId);
  const existingUserLinkQuery = db
    .collection('auth_links')
    .where('user_id', '==', userReference.id);

  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    authorizeTargetRole(operator.access_role, targetRole);

    const requestSnapshot = await transaction.get(requestReference);
    const request = parsePendingRequest(
      requireDocument(requestSnapshot, 'Registration request'),
      applicantUid,
    );
    validateApplicantAuth(applicantAuth, request);
    const existingEmailQuery = db.collection('users').where('email', '==', request.email);
    const existingPhoneUsersQuery = db.collection('users').where('phone', '==', request.phone);
    const existingPhoneDirectoryQuery = db
      .collection('user_directory')
      .where('phone', '==', request.phone);
    const [applicantLinkSnapshot, userSnapshot, directorySnapshot, auditSnapshot, existingUserLinks,
      existingEmailUsers, existingPhoneUsers, existingPhoneDirectory] =
      await Promise.all([
        transaction.get(applicantLinkReference),
        transaction.get(userReference),
        transaction.get(directoryReference),
        transaction.get(auditReference),
        transaction.get(existingUserLinkQuery),
        transaction.get(existingEmailQuery),
        transaction.get(existingPhoneUsersQuery),
        transaction.get(existingPhoneDirectoryQuery),
      ]);
    if (applicantLinkSnapshot.exists) {
      throw new AdmissionError('duplicate_auth_link', 'Applicant already has an auth link of some state.');
    }
    if (userSnapshot.exists || directorySnapshot.exists) {
      throw new AdmissionError('id_collision', 'Generated application User ID already exists.');
    }
    if (auditSnapshot.exists) {
      throw new AdmissionError('operation_reused', 'Operation ID has already been used.');
    }
    if (!existingUserLinks.empty) {
      throw new AdmissionError('duplicate_user_link', 'Generated User ID is already referenced by an auth link.');
    }
    if (!existingEmailUsers.empty || !existingPhoneUsers.empty || !existingPhoneDirectory.empty) {
      throw new AdmissionError(
        'identity_conflict',
        'Applicant identity matches existing organization data; use a separate reviewed identity-linking workflow.',
      );
    }

    const actorUserId = operator.id;
    const user = {
      name: request.name,
      phone: request.phone,
      email: request.email,
      blood_group: null,
      profession: null,
      address: null,
      photo_url: null,
      access_role: targetRole,
      active: true,
      login_enabled: true,
      preferred_language: null,
      created_at: serverTimestamp(),
      created_by: actorUserId,
      updated_at: serverTimestamp(),
      updated_by: actorUserId,
    };
    const link = {
      user_id: userReference.id,
      active: true,
      created_at: serverTimestamp(),
      created_by: actorUserId,
    };
    const requestDecision = {
      status: 'approved',
      approved_by: actorUserId,
      approved_at: serverTimestamp(),
      linked_user_id: userReference.id,
    };
    const audit = {
      action: 'registration.approve',
      actor_user_id: actorUserId,
      actor_auth_uid: operatorUid,
      target_path: requestReference.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: {
        status: { before: 'pending', after: 'approved' },
        linked_user_id: { after: userReference.id },
        access_role: { after: targetRole },
        login_enabled: { after: true },
      },
      reason: reason.trim(),
    };

    transaction.create(userReference, user);
    transaction.create(directoryReference, projectDirectory(user));
    transaction.create(applicantLinkReference, link);
    transaction.update(requestReference, requestDecision);
    transaction.create(auditReference, audit);

    return { action: 'approved', userId: userReference.id, operationId };
  });
}

export async function rejectRegistration({
  db,
  auth,
  serverTimestamp,
  operatorUid,
  applicantUid,
  operationId,
  reason,
}) {
  validateCommonInput({ operatorUid, applicantUid, operationId, reason });
  const operatorAuth = await getAuthRecord(auth, operatorUid, 'Operator');
  const requestReference = db.collection('registration_requests').doc(applicantUid);
  const applicantLinkReference = db.collection('auth_links').doc(applicantUid);
  const auditReference = db.collection('audit_logs').doc(operationId);

  return db.runTransaction(async (transaction) => {
    const operator = await resolveOperator(transaction, db, operatorUid, operatorAuth);
    const [requestSnapshot, applicantLinkSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(requestReference),
      transaction.get(applicantLinkReference),
      transaction.get(auditReference),
    ]);
    parsePendingRequest(
      requireDocument(requestSnapshot, 'Registration request'),
      applicantUid,
    );
    if (applicantLinkSnapshot.exists) {
      throw new AdmissionError('duplicate_auth_link', 'Applicant already has an auth link of some state.');
    }
    if (auditSnapshot.exists) {
      throw new AdmissionError('operation_reused', 'Operation ID has already been used.');
    }

    transaction.update(requestReference, {
      status: 'rejected',
      rejected_by: operator.id,
      rejected_at: serverTimestamp(),
    });
    transaction.create(auditReference, {
      action: 'registration.reject',
      actor_user_id: operator.id,
      actor_auth_uid: operatorUid,
      target_path: requestReference.path,
      occurred_at: serverTimestamp(),
      operation_id: operationId,
      outcome: 'committed',
      changes: { status: { before: 'pending', after: 'rejected' } },
      reason: reason.trim(),
    });
    return { action: 'rejected', operationId };
  });
}

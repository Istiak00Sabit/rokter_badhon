const RECOGNIZED_ROLES = new Set([
  'developer_admin',
  'leader',
  'executive',
  'committee',
  'member',
]);

const ORDINARY_ROLES = new Set(['member', 'committee', 'executive']);

const REQUEST_FIELDS = new Set([
  'auth_uid',
  'name',
  'phone',
  'email',
  'status',
  'requested_at',
  'approved_by',
  'approved_at',
  'rejected_by',
  'rejected_at',
  'linked_user_id',
]);

const LINK_FIELDS = new Set(['user_id', 'active', 'created_at', 'created_by']);

const USER_FIELDS = new Set([
  'name',
  'phone',
  'email',
  'blood_group',
  'profession',
  'address',
  'photo_url',
  'access_role',
  'active',
  'login_enabled',
  'preferred_language',
  'created_at',
  'created_by',
  'updated_at',
  'updated_by',
]);

export class AdmissionError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AdmissionError';
    this.code = code;
  }
}

function fail(code, message) {
  throw new AdmissionError(code, message);
}

function exactFields(value, fields, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('malformed', `${label} must be an object.`);
  }
  const keys = Object.keys(value);
  if (keys.length !== fields.size || keys.some((key) => !fields.has(key))) {
    fail('malformed', `${label} has missing or unapproved fields.`);
  }
}

function string(value, field, { nullable = false } = {}) {
  if (nullable && value === null) return;
  if (typeof value !== 'string') fail('malformed', `${field} must be a string${nullable ? ' or null' : ''}.`);
}

function bool(value, field) {
  if (typeof value !== 'boolean') fail('malformed', `${field} must be a boolean.`);
}

function timestamp(value, field, { nullable = false } = {}) {
  if (nullable && value === null) return;
  if (!value || typeof value.toMillis !== 'function') {
    fail('malformed', `${field} must be a Firestore Timestamp${nullable ? ' or null' : ''}.`);
  }
}

export function validateId(value, label) {
  if (typeof value !== 'string' || value.length === 0 || value.includes('/')) {
    fail('invalid_argument', `${label} must be a non-empty Firestore document ID.`);
  }
}

export function parseAuthLink(data, uid) {
  exactFields(data, LINK_FIELDS, 'AuthLink');
  string(data.user_id, 'user_id');
  validateId(data.user_id, 'AuthLink user_id');
  bool(data.active, 'active');
  timestamp(data.created_at, 'created_at');
  string(data.created_by, 'created_by');
  return { uid, ...data };
}

export function parseUser(data, id) {
  exactFields(data, USER_FIELDS, 'User');
  string(data.name, 'name');
  string(data.phone, 'phone');
  string(data.email, 'email', { nullable: true });
  string(data.blood_group, 'blood_group', { nullable: true });
  string(data.profession, 'profession', { nullable: true });
  string(data.address, 'address', { nullable: true });
  string(data.photo_url, 'photo_url', { nullable: true });
  string(data.access_role, 'access_role');
  bool(data.active, 'active');
  bool(data.login_enabled, 'login_enabled');
  string(data.preferred_language, 'preferred_language', { nullable: true });
  timestamp(data.created_at, 'created_at');
  string(data.created_by, 'created_by', { nullable: true });
  timestamp(data.updated_at, 'updated_at');
  string(data.updated_by, 'updated_by', { nullable: true });
  return { id, ...data };
}

export function parsePendingRequest(data, documentId) {
  exactFields(data, REQUEST_FIELDS, 'RegistrationRequest');
  string(data.auth_uid, 'auth_uid');
  string(data.name, 'name');
  string(data.phone, 'phone');
  string(data.email, 'email');
  string(data.status, 'status');
  timestamp(data.requested_at, 'requested_at');
  string(data.approved_by, 'approved_by', { nullable: true });
  timestamp(data.approved_at, 'approved_at', { nullable: true });
  string(data.rejected_by, 'rejected_by', { nullable: true });
  timestamp(data.rejected_at, 'rejected_at', { nullable: true });
  string(data.linked_user_id, 'linked_user_id', { nullable: true });
  if (data.auth_uid !== documentId) fail('identity_mismatch', 'Request auth_uid does not match its document ID.');
  if (!['pending', 'approved', 'rejected'].includes(data.status)) {
    fail('malformed', 'Registration request has an unknown status.');
  }
  if (data.status !== 'pending') fail('already_decided', `Registration request is already ${data.status}.`);
  if ([data.approved_by, data.approved_at, data.rejected_by, data.rejected_at, data.linked_user_id].some((value) => value !== null)) {
    fail('malformed', 'Pending request contains decision or linkage data.');
  }
  return { documentId, ...data };
}

export function authorizeOperator({ authRecord, link, user }) {
  if (!authRecord || authRecord.disabled === true || authRecord.emailVerified !== true) {
    fail('operator_not_admitted', 'Operator Firebase identity must exist, be enabled, and have verified email.');
  }
  if (!link || link.active !== true) fail('operator_not_admitted', 'Operator auth link is missing or inactive.');
  if (!user || user.active !== true || user.login_enabled !== true || !RECOGNIZED_ROLES.has(user.access_role)) {
    fail('operator_not_admitted', 'Operator User is missing, inactive, login-disabled, or has an unknown role.');
  }
  if (!['developer_admin', 'leader'].includes(user.access_role)) {
    fail('unauthorized', 'Operator lacks registration review capability.');
  }
}

export function authorizeTargetRole(operatorRole, targetRole) {
  if (!RECOGNIZED_ROLES.has(targetRole)) fail('unauthorized_role', 'Unknown target access role.');
  if (targetRole === 'developer_admin') {
    fail('unauthorized_role', 'Normal registration approval cannot create developer_admin.');
  }
  if (operatorRole === 'developer_admin') return;
  if (operatorRole === 'leader' && ORDINARY_ROLES.has(targetRole)) return;
  fail('unauthorized_role', `${operatorRole} cannot assign ${targetRole}.`);
}

export function projectDirectory(user) {
  return {
    name: user.name,
    phone: user.phone,
    blood_group: user.blood_group,
    profession: user.profession,
    photo_url: user.photo_url,
    active: user.active,
  };
}

export const schemaFields = {
  request: REQUEST_FIELDS,
  link: LINK_FIELDS,
  user: USER_FIELDS,
};

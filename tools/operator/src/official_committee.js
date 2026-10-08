import fs from 'node:fs';

import { AdmissionError, parseDirectory, parseUser, projectDirectory } from './policy.js';

export const OFFICIAL_COMMITTEE_TERM_ID = '2025-2027';
export const OFFICIAL_COMMITTEE_SEED_ACTOR = 'local-emulator-committee-seed';
const SOURCE_FIELDS = new Set([
  'serial', 'position', 'name', 'phone', 'profession', 'blood_group', 'access_role',
]);
const USER_ROLES = new Set(['leader', 'executive', 'committee']);
const EXPECTED_TOTALS = Object.freeze({ leader: 2, executive: 31, committee: 18 });

function fail(code, message) {
  throw new AdmissionError(code, message);
}

function exactFields(value, fields, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail('invalid_source', `${label} must be an object.`);
  const keys = Object.keys(value);
  if (keys.length !== fields.size || keys.some((key) => !fields.has(key))) {
    fail('invalid_source', `${label} has missing or unapproved fields.`);
  }
}

function requiredText(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0 || value !== value.trim()) {
    fail('invalid_source', `${label} must be exact non-empty source text.`);
  }
  return value;
}

export function validateOfficialCommitteeSource(rows) {
  if (!Array.isArray(rows) || rows.length !== 51) {
    fail('invalid_source', 'Official committee source must contain exactly 51 records.');
  }
  const phones = new Set();
  const totals = { leader: 0, executive: 0, committee: 0 };
  const normalized = rows.map((row, index) => {
    exactFields(row, SOURCE_FIELDS, `Committee row ${index + 1}`);
    if (row.serial !== index + 1) fail('invalid_source', `Committee serial ${index + 1} is missing or out of order.`);
    const position = requiredText(row.position, `Committee row ${row.serial} position`);
    const name = requiredText(row.name, `Committee row ${row.serial} name`);
    const phone = requiredText(row.phone, `Committee row ${row.serial} phone`);
    const profession = requiredText(row.profession, `Committee row ${row.serial} profession`);
    const bloodGroup = requiredText(row.blood_group, `Committee row ${row.serial} blood_group`);
    if (phones.has(phone)) fail('duplicate_identity', `Duplicate committee phone: ${phone}.`);
    phones.add(phone);
    if (!USER_ROLES.has(row.access_role)) {
      fail('invalid_role_mapping', `Committee row ${row.serial} has an invalid access_role.`);
    }
    totals[row.access_role] += 1;
    return Object.freeze({
      serial: row.serial,
      position,
      name,
      phone,
      profession,
      blood_group: bloodGroup,
      access_role: row.access_role,
    });
  });
  for (const [role, count] of Object.entries(EXPECTED_TOTALS)) {
    if (totals[role] !== count) fail('invalid_role_totals', `Expected ${count} ${role} records, found ${totals[role]}.`);
  }
  return Object.freeze(normalized);
}

export function loadOfficialCommitteeSource(
  sourcePath = new URL('../../../data/committee_2025_2027.json', import.meta.url),
) {
  let decoded;
  try {
    decoded = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
  } catch (error) {
    fail('invalid_source', `Cannot read official committee source: ${error.message}`);
  }
  return validateOfficialCommitteeSource(decoded);
}

function userIdFor(serial) {
  return `committee-2025-2027-${String(serial).padStart(3, '0')}`;
}

function assignmentIdFor(serial) {
  return `2025-2027-${String(serial).padStart(3, '0')}`;
}

function fixedUser(row) {
  return {
    name: row.name,
    phone: row.phone,
    email: null,
    blood_group: row.blood_group,
    profession: row.profession,
    address: null,
    photo_url: null,
    access_role: row.access_role,
    active: true,
    login_enabled: false,
    preferred_language: null,
    created_by: null,
    updated_by: null,
  };
}

function fixedValuesMatch(actual, expected) {
  return Object.entries(expected).every(([key, value]) => actual[key] === value);
}

export async function seedOfficialCommittee({
  projectId,
  db,
  serverTimestamp,
  rows = loadOfficialCommitteeSource(),
  allowProduction = false,
}) {
  const production = allowProduction && projectId === 'rokterbadhon-b247b';
  if (projectId !== 'demo-rokter-badhon' && !production) {
    fail('unsafe_target', 'Official committee import requires an approved target.');
  }
  const seedActor = production
    ? 'trusted-operator-official-committee-import'
    : OFFICIAL_COMMITTEE_SEED_ACTOR;
  const source = validateOfficialCommitteeSource(rows);
  const termReference = db.collection('committee_terms').doc(OFFICIAL_COMMITTEE_TERM_ID);
  const activeTermsQuery = db.collection('committee_terms').where('active', '==', true);

  return db.runTransaction(async (transaction) => {
    const termSnapshot = await transaction.get(termReference);
    const activeTerms = await transaction.get(activeTermsQuery);
    if (activeTerms.docs.some((doc) => doc.id !== OFFICIAL_COMMITTEE_TERM_ID)) {
      fail('ambiguous_current_term', 'A different active committee term exists; reviewed rollover is required.');
    }

    const states = [];
    for (const row of source) {
      const userId = userIdFor(row.serial);
      const assignmentId = assignmentIdFor(row.serial);
      const userReference = db.collection('users').doc(userId);
      const directoryReference = db.collection('user_directory').doc(userId);
      const assignmentReference = db.collection('committee_assignments').doc(assignmentId);
      const [userSnapshot, directorySnapshot, assignmentSnapshot, phoneMatches, assignmentMatches] = await Promise.all([
        transaction.get(userReference),
        transaction.get(directoryReference),
        transaction.get(assignmentReference),
        transaction.get(db.collection('users').where('phone', '==', row.phone)),
        transaction.get(db.collection('committee_assignments').where('user_id', '==', userId).where('term_id', '==', OFFICIAL_COMMITTEE_TERM_ID)),
      ]);
      const foreignPhoneMatch = phoneMatches.docs.find((doc) => doc.id !== userId);
      if (foreignPhoneMatch) fail('duplicate_identity', `Phone ${row.phone} already belongs to another User.`);
      const foreignAssignment = assignmentMatches.docs.find((doc) => doc.id !== assignmentId);
      if (foreignAssignment) fail('duplicate_assignment', `User ${userId} already has another assignment for 2025-2027.`);
      if (!userSnapshot.exists && directorySnapshot.exists) fail('existing_conflict', `Orphan directory ${userId} conflicts with the preload.`);
      if (!userSnapshot.exists && assignmentSnapshot.exists) fail('existing_conflict', `Orphan assignment ${assignmentId} conflicts with the preload.`);
      states.push({ row, userId, assignmentId, userReference, directoryReference, assignmentReference, userSnapshot, directorySnapshot, assignmentSnapshot });
    }

    const now = serverTimestamp();
    let createdUsers = 0;
    let createdAssignments = 0;
    if (!termSnapshot.exists) {
      transaction.create(termReference, {
        name: '2025-2027',
        start_year: 2025,
        end_year: 2027,
        start_date: null,
        end_date: null,
        active: true,
        group_photo_url: null,
        created_at: now,
        created_by: seedActor,
      });
    } else {
      const term = termSnapshot.data();
      if (!fixedValuesMatch(term, {
        name: '2025-2027', start_year: 2025, end_year: 2027, start_date: null,
        end_date: null, active: true, group_photo_url: null,
        created_by: seedActor,
      })) fail('existing_conflict', 'Existing 2025-2027 committee term does not match the reviewed preload.');
    }

    for (const state of states) {
      const expectedFixedUser = fixedUser(state.row);
      if (!state.userSnapshot.exists) {
        const user = { ...expectedFixedUser, created_at: now, updated_at: now };
        transaction.create(state.userReference, user);
        transaction.create(state.directoryReference, projectDirectory(user));
        createdUsers += 1;
      } else {
        const user = parseUser(state.userSnapshot.data(), state.userId);
        if (!fixedValuesMatch(user, expectedFixedUser)) fail('existing_conflict', `Existing User ${state.userId} conflicts with official source.`);
        if (!state.directorySnapshot.exists) fail('existing_conflict', `User ${state.userId} is missing user_directory.`);
        const directory = parseDirectory(state.directorySnapshot.data(), state.userId);
        if (!fixedValuesMatch(directory, projectDirectory(user))) fail('existing_conflict', `User ${state.userId} has a conflicting directory projection.`);
      }

      const expectedAssignment = {
        user_id: state.userId,
        term_id: OFFICIAL_COMMITTEE_TERM_ID,
        position: state.row.position,
        active: true,
        assigned_by: seedActor,
        ended_at: null,
      };
      if (!state.assignmentSnapshot.exists) {
        transaction.create(state.assignmentReference, { ...expectedAssignment, assigned_at: now });
        createdAssignments += 1;
      } else if (!fixedValuesMatch(state.assignmentSnapshot.data(), expectedAssignment)) {
        fail('existing_conflict', `Existing assignment ${state.assignmentId} conflicts with official source.`);
      }
    }

    return {
      action: createdUsers === 0 && createdAssignments === 0
        ? 'official_committee_already_seeded'
        : 'official_committee_seeded',
      operationId: 'official-committee-2025-2027-seed',
      termId: OFFICIAL_COMMITTEE_TERM_ID,
      userCount: source.length,
      assignmentCount: source.length,
      createdUsers,
      createdAssignments,
      roleTotals: { ...EXPECTED_TOTALS },
    };
  });
}

import { AdmissionError, validateId } from './policy.js';

function fail(code, message) {
  throw new AdmissionError(code, message);
}

/** Review-only canonical identity. No Firestore reads or writes. */
export function canonicalDonorPhone(value) {
  if (typeof value !== 'string') fail('invalid_phone', 'Donor phone must be a string.');
  const bengaliDigits = '০১২৩৪৫৬৭৮৯';
  const latin = value.trim().replace(/[০-৯]/g, digit => String(bengaliDigits.indexOf(digit)));
  const compact = latin.replace(/[\s-]/g, '');
  const phone = compact.startsWith('+880') ? '0' + compact.slice(4)
    : compact.startsWith('880') ? '0' + compact.slice(3) : compact;
  if (!/^01[3-9][0-9]{8}$/.test(phone)) {
    fail('invalid_phone', 'A complete Bangladesh mobile phone number is required.');
  }
  return phone;
}

/**
 * Preflight for a reviewed future phone-key migration.
 * Each record is {id, phone, active}. Unlike active-only client lookup,
 * inactive and archived donors must also be checked before reserving keys.
 * This is NOT a write; never treat the plan as a completed backfill.
 */
export function planDonorPhoneReservations(records) {
  if (!Array.isArray(records)) fail('invalid_argument', 'Records must be an array.');
  const owners = new Map();
  const invalidIds = [];
  const duplicateKeys = new Map();
  for (const donor of records) {
    if (!donor || typeof donor !== 'object') {
      fail('invalid_argument', 'Each donor must be an object.');
    }
    validateId(donor.id, 'donor ID');
    let phone;
    try {
      phone = canonicalDonorPhone(donor.phone);
    } catch (error) {
      if (error?.code !== 'invalid_phone') throw error;
      invalidIds.push(donor.id);
      continue;
    }
    if (!owners.has(phone)) {
      owners.set(phone, donor.id);
    } else {
      const ids = duplicateKeys.get(phone) ?? [owners.get(phone)];
      ids.push(donor.id);
      duplicateKeys.set(phone, ids);
    }
  }
  return {
    total: records.length,
    validUniquePhones: owners.size,
    invalidIds: invalidIds.sort(),
    duplicateGroups: [...duplicateKeys.entries()]
      .map(([phone, ids]) => ({ phone, donorIds: ids.sort() }))
      .sort((a, b) => a.phone.localeCompare(b.phone)),
    migrationReady: invalidIds.length === 0 && duplicateKeys.size === 0,
  };
}

/**
 * Emulator-only CLI audit. Paginate the full historical donor collection,
 * including inactive profiles. This never creates a phone-key document.
 */
export async function auditDonorPhoneIdentities({ db, pageSize = 200, maxRecords = 100000 }) {
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 500 ||
      !Number.isInteger(maxRecords) || maxRecords < pageSize) {
    fail('invalid_argument', 'Unsafe identity scan bounds.');
  }
  const rows = [];
  let cursor;
  while (true) {
    let query = db.collection('donors').orderBy('__name__').limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    for (const doc of snapshot.docs) {
      if (rows.length >= maxRecords) {
        fail('limit_exceeded', 'Identity audit is incomplete; increase a reviewed bound.');
      }
      const raw = doc.data();
      rows.push({ id: doc.id, phone: raw?.phone, active: raw?.active });
    }
    if (snapshot.docs.length < pageSize) break;
    cursor = snapshot.docs.at(-1);
  }
  return planDonorPhoneReservations(rows);
}


/**
 * Pure, read-only consistency check for a proposed phone registry cutover.
 * Return COUNTS ONLY: never expose phone keys or donor IDs in shared logs.
 * The registry document is not an authorization to write. It is checked only
 * to distinguish an intact dry-run from an already-authorized cutover.
 */
export function verifyDonorPhoneRegistry(donors, reservations, registry = null) {
  if (!Array.isArray(donors) || !Array.isArray(reservations)) {
    fail('invalid_argument', 'Donors and reservations must be arrays.');
  }
  const byPhone = new Map();
  const ids = new Set();
  let invalidDonors = 0, noncanonicalDonors = 0, duplicatePhones = 0;
  for (const donor of donors) {
    if (!donor || typeof donor !== 'object') {
      fail('invalid_argument', 'Each donor must be an object.');
    }
    validateId(donor.id, 'donor ID');
    if (ids.has(donor.id)) fail('malformed', 'Repeated donor document in scan.');
    ids.add(donor.id);
    let phone;
    try {
      phone = canonicalDonorPhone(donor.phone);
    } catch (error) {
      if (error.code !== 'invalid_phone') throw error;
      invalidDonors++;
      continue;
    }
    if (phone !== donor.phone) noncanonicalDonors++;
    if (byPhone.has(phone)) duplicatePhones++;
    else byPhone.set(phone, donor.id);
  }
  const seenKeys = new Set();
  let malformedKeys = 0, orphanKeys = 0, mismatchedKeys = 0;
  for (const key of reservations) {
    if (!key || typeof key !== 'object') {
      fail('invalid_argument', 'Each reservation must be an object.');
    }
    // A registry key must use the canonical domestic phone as document ID.
    // Do not print the key in thrown errors.
    let keyPhone;
    try {
      keyPhone = canonicalDonorPhone(key.id);
    } catch (error) {
      if (error.code !== 'invalid_phone') throw error;
      malformedKeys++;
      continue;
    }
    if (seenKeys.has(key.id)) fail('malformed', 'Repeated reservation document in scan.');
    seenKeys.add(key.id);
    if (keyPhone !== key.id || key.phone !== key.id) {
      malformedKeys++;
      continue;
    }
    if (!byPhone.has(key.id)) {
      orphanKeys++;
    } else if (byPhone.get(key.id) !== key.donorId) {
      mismatchedKeys++;
    }
  }
  let missingKeys = 0;
  for (const phone of byPhone.keys()) {
    if (!seenKeys.has(phone)) missingKeys++;
  }
  const validReservations = invalidDonors === 0 &&
    noncanonicalDonors === 0 && duplicatePhones === 0 &&
    malformedKeys === 0 && orphanKeys === 0 &&
    mismatchedKeys === 0 && missingKeys === 0 &&
    donors.length === reservations.length;
  const registryReady = registry?.ready === true && registry?.schema_version === 1;
  return {
    mode: 'READ_ONLY',
    writesPerformed: 0,
    donorsScanned: donors.length,
    reservationsScanned: reservations.length,
    invalidDonors,
    noncanonicalDonors,
    duplicatePhones,
    malformedKeys,
    orphanKeys,
    mismatchedKeys,
    missingKeys,
    reservationIntegrityReady: validReservations,
    registryReady,
    releaseReady: validReservations && registryReady,
  };
}

async function readAllDocuments(db, collectionName, pageSize, maxRecords) {
  const records = [];
  let cursor;
  while (true) {
    let query = db.collection(collectionName).orderBy('__name__').limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (!Array.isArray(snapshot.docs)) {
      fail('malformed', 'Collection scan did not provide a complete document page.');
    }
    for (const doc of snapshot.docs) {
      if (records.length >= maxRecords) {
        fail('limit_exceeded', 'Registry scan is incomplete; never accept truncated data.');
      }
      records.push({ ...doc.data(), id: doc.id });
    }
    if (snapshot.docs.length < pageSize) break;
    cursor = snapshot.docs.at(-1);
  }
  return records;
}

/** Emulator-only full-history preflight. No writes and no personal-data output. */
export async function auditDonorPhoneRegistry({
  db, pageSize = 200, maxRecords = 100000,
}) {
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 500 ||
      !Number.isInteger(maxRecords) || maxRecords < pageSize) {
    fail('invalid_argument', 'Unsafe registry audit bounds.');
  }
  const donors = await readAllDocuments(db, 'donors', pageSize, maxRecords);
  const keys = await readAllDocuments(db, 'donor_phone_keys', pageSize, maxRecords);
  const snapshot = await db.collection('system_config')
    .doc('donor_phone_registry').get();
  const registry = snapshot.exists ? snapshot.data() : null;
  return verifyDonorPhoneRegistry(
    donors.map(x => ({ id: x.id, phone: x.phone, active: x.active })),
    keys.map(x => ({ id: x.id, phone: x.phone, donorId: x.donor_id })),
    registry,
  );
}

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

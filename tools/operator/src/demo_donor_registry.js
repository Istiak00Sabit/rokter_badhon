import { AdmissionError } from './policy.js';
import { auditDonorPhoneRegistry } from './donor_phone_plan.js';

function fail(code, message) { throw new AdmissionError(code, message); }

/**
 * A new/empty LOCAL EMULATOR may be prepared for phone-based donor approval.
 * Never backfill, delete, modify or activate any nonempty donor database.
 */
export async function seedEmptyDemoDonorRegistry({
  db, projectId, firestoreEmulatorHost, authEmulatorHost,
}) {
  if (projectId !== 'demo-rokter-badhon' ||
      !firestoreEmulatorHost || !authEmulatorHost) {
    fail('unsafe_target', 'This fixture only runs on local demo Auth/Firestore emulators.');
  }
  const report = await auditDonorPhoneRegistry({ db, pageSize: 100 });
  if (report.donorsScanned !== 0 || report.reservationsScanned !== 0 ||
      !report.reservationIntegrityReady) {
    fail('requires_manual_review', 'Existing donor history must never be auto-activated by a test seed.');
  }
  const registryRef = db.collection('system_config').doc('donor_phone_registry');
  const result = await db.runTransaction(async transaction => {
    // Re-check the empty state in the SAME transaction as activation.
    const donors = await transaction.get(db.collection('donors').limit(1));
    const reservations = await transaction.get(db.collection('donor_phone_keys').limit(1));
    const registry = await transaction.get(registryRef);
    if (!donors.empty || !reservations.empty) {
      fail('requires_manual_review', 'Registry seed aborted because donor history is not empty.');
    }
    if (registry.exists) {
      const state = registry.data();
      if (state?.ready === true && state?.schema_version === 1) {
        return { action: 'demo_donor_registry_already_seeded', operationId: 'demo-donor-registry' };
      }
      if (state?.ready !== false || state?.schema_version !== 1) {
        fail('ambiguous_state', 'Existing demo donor registry differs from the reviewed schema.');
      }
      transaction.update(registryRef, { ready: true, schema_version: 1 });
    } else {
      transaction.create(registryRef, { ready: true, schema_version: 1 });
    }
    return { action: 'demo_donor_registry_seeded', operationId: 'demo-donor-registry' };
  });
  return result;
}

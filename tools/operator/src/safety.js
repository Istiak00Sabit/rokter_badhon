import { AdmissionError } from './policy.js';

export const KNOWN_APPLICATION_PROJECT_ID = 'rokterbadhon-b247b';

export function assertSafeTarget({
  projectId,
  firestoreEmulatorHost,
  authEmulatorHost,
  mode = 'emulator',
  allowProduction = false,
  confirmedProjectId,
}) {
  if (typeof projectId !== 'string' || projectId.length === 0) {
    throw new AdmissionError('unsafe_target', 'An explicit --project-id is required.');
  }
  if (mode === 'provision' && allowProduction) {
    if (projectId !== KNOWN_APPLICATION_PROJECT_ID || confirmedProjectId !== projectId) {
      throw new AdmissionError(
        'unsafe_target',
        `Production provisioning requires the exact known project ${KNOWN_APPLICATION_PROJECT_ID} and --confirm-project-id ${KNOWN_APPLICATION_PROJECT_ID}.`,
      );
    }
    if (firestoreEmulatorHost || authEmulatorHost) {
      throw new AdmissionError('unsafe_target', 'Production provisioning cannot run with emulator endpoints set.');
    }
    return;
  }
  if (!projectId.startsWith('demo-')) {
    throw new AdmissionError(
      'unsafe_target',
      'The trusted operator tool refuses every non-demo Firebase project, including production.',
    );
  }
  if (!firestoreEmulatorHost || !authEmulatorHost) {
    throw new AdmissionError(
      'unsafe_target',
      'Both FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST are required.',
    );
  }
}

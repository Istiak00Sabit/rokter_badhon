import { AdmissionError } from './policy.js';

export function assertSafeTarget({ projectId, firestoreEmulatorHost, authEmulatorHost }) {
  if (typeof projectId !== 'string' || projectId.length === 0) {
    throw new AdmissionError('unsafe_target', 'An explicit --project-id is required.');
  }
  if (!projectId.startsWith('demo-')) {
    throw new AdmissionError(
      'unsafe_target',
      'Phase 2C refuses every non-demo Firebase project, including production.',
    );
  }
  if (!firestoreEmulatorHost || !authEmulatorHost) {
    throw new AdmissionError(
      'unsafe_target',
      'Both FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST are required.',
    );
  }
}

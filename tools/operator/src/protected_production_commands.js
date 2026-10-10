import { AdmissionError, validateId } from './policy.js';

// Only these named, already-reviewed trusted workflows may request explicit
// production execution. Other operator commands remain emulator-only, except
// the separately guarded committee/legacy provisioning operations.
const REGISTRATION_COMMANDS = new Set([
  'approve',
  'reject',
  'link-registration',
]);
const FIRST_ADMIN_COMMANDS = new Set(['bootstrap-developer-admin']);

export function isProtectedProductionCommand(command) {
  return REGISTRATION_COMMANDS.has(command) ||
    FIRST_ADMIN_COMMANDS.has(command);
}

function fail(message) {
  throw new AdmissionError('production_confirmation_required', message);
}

function requiredString(value, label) {
  if (typeof value !== 'string' || value.trim().length === 0 ||
      value.trim() !== value) {
    fail(`Explicit, trimmed ${label} is required for production.`);
  }
  return value;
}

/**
 * Defense-in-depth for operator CLI production access. This guard runs
 * *before* Firebase Admin SDK initialization and any Auth/Firestore read.
 * It does not grant authorization: admission.js/developer_admin.js must still
 * verify operator, request, identity, conflicts, audited transaction, etc.
 */
export function assertProtectedProductionCommand({
  command,
  options,
  explicitCredentialPath,
}) {
  if (!isProtectedProductionCommand(command)) {
    fail('This command is not an allowed protected production workflow.');
  }
  if (options['allow-production'] !== 'true') {
    fail('Set --allow-production true only after an authorized owner review.');
  }
  if (options['confirm-command'] !== command) {
    fail(`--confirm-command must exactly match ${command}.`);
  }
  if (typeof explicitCredentialPath !== 'string' ||
      explicitCredentialPath.trim().length === 0) {
    fail('Set GOOGLE_APPLICATION_CREDENTIALS to the protected operator key path; never commit or share that file.');
  }

  const operationId = requiredString(options['operation-id'], 'operation ID');
  const reason = requiredString(options.reason, 'audit reason');
  if (reason.length < 10) {
    fail('An audit reason of at least 10 characters is required.');
  }
  validateId(operationId, 'operation ID');

  if (REGISTRATION_COMMANDS.has(command)) {
    const operatorUid = requiredString(options['operator-uid'], 'operator UID');
    const applicantUid = requiredString(options['applicant-uid'], 'applicant UID');
    validateId(operatorUid, 'operator UID');
    validateId(applicantUid, 'applicant UID');
    if (operatorUid === applicantUid) {
      fail('The operator cannot approve or reject their own registration.');
    }
    if (options['confirm-applicant-uid'] !== applicantUid ||
        options['confirm-operator-uid'] !== operatorUid) {
      fail('Confirm both exact UIDs using --confirm-applicant-uid and --confirm-operator-uid.');
    }
    if (command === 'approve' && options['target-role'] !== 'member') {
      fail('A new registration may be approved only with --target-role member.');
    }
    if (command === 'link-registration') {
      const userId = requiredString(options['target-user-id'], 'target User ID');
      validateId(userId, 'target User ID');
      if (options['confirm-target-user-id'] !== userId) {
        fail('Existing-user linking requires --confirm-target-user-id.');
      }
    }
  }

  if (FIRST_ADMIN_COMMANDS.has(command)) {
    const authUid = requiredString(options['auth-uid'], 'target Auth UID');
    validateId(authUid, 'target Auth UID');
    if (options['confirm-auth-uid'] !== authUid ||
        options['confirm-first-admin'] !== 'true') {
      fail('First-admin bootstrap requires both the exact Auth UID confirmation and --confirm-first-admin true.');
    }
  }
}

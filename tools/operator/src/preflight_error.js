/**
 * Classify Google Cloud / gRPC errors without printing the raw exception.
 * SDK error.message/details/stack can contain user identifiers or secrets.
 */
const GRPC_CODES = Object.freeze({
  1: 'cancelled',
  2: 'unknown',
  3: 'invalid_argument',
  4: 'deadline_exceeded',
  5: 'not_found',
  6: 'already_exists',
  7: 'permission_denied',
  8: 'resource_exhausted',
  9: 'failed_precondition',
  10: 'aborted',
  11: 'out_of_range',
  12: 'unimplemented',
  13: 'internal',
  14: 'unavailable',
  15: 'data_loss',
  16: 'unauthenticated',
});

function allCauses(error) {
  const out = [];
  const seen = new Set();
  let current = error;
  while (current && typeof current === 'object' && out.length < 4 &&
    !seen.has(current)) {
    seen.add(current);
    out.push(current);
    current = current.cause;
  }
  return out;
}

export function classifyPreflightError(error) {
  const chain = allCauses(error);
  const grpcError = chain.find((e) => Number.isInteger(e.code) &&
    e.code >= 0 && e.code <= 16);
  if (grpcError) {
    const status = GRPC_CODES[grpcError.code];
    return {
      code: 'grpc_' + status,
      status: grpcError.code,
      category: [7, 16].includes(grpcError.code)
        ? 'credentials_or_permissions'
        : [4, 14].includes(grpcError.code)
          ? 'network_or_service'
          : 'firestore_or_sdk',
    };
  }

  const stringCode = chain.find((e) =>
    typeof e.code === 'string' && /^[\w/-]{1,80}$/.test(e.code))?.code;
  if (stringCode) {
    let category = 'sdk';
    if (/auth|permission|credential|unauth|forbidden|iam/i.test(stringCode)) {
      category = 'credentials_or_permissions';
    } else if (/network|unavailable|timeout|econn|enotfound/i.test(stringCode)) {
      category = 'network_or_service';
    }
    return { code: stringCode, status: null, category };
  }

  // Inspect locally only; never include raw messages in report output.
  const description = chain.map((e) => String(e.message ?? '')).join(' ').toLowerCase();
  if (/iamcredentials|generateaccesstoken|impersonat|token creator/.test(description)) {
    return { code: 'credential_impersonation_failure', status: null, category: 'credentials_or_permissions' };
  }
  if (/permission.denied|insufficient.permission|403|unauthenticated|401|invalid.grant|invalid.credentials/.test(description)) {
    return { code: 'credential_or_iam_failure', status: null, category: 'credentials_or_permissions' };
  }
  if (/not enabled|api has not been used|service.disabled/.test(description)) {
    return { code: 'api_disabled_or_blocked', status: null, category: 'api_configuration' };
  }
  if (/deadline|timeout|econnreset|etimedout|enotfound|dns|unavailable/.test(description)) {
    return { code: 'network_or_service_failure', status: null, category: 'network_or_service' };
  }
  return { code: 'unclassified_sdk_error', status: null, category: 'unknown' };
}

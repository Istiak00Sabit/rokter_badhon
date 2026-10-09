#!/usr/bin/env node
// Read-only production deployment audit. DOES NOT publish rules or create indexes.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  PROJECT_ID, auditLiveRules, auditLiveIndexes, makeCloudRead,
  parseGcloudCompositeIndexesJson,
} from './src/live_rules_audit.js';

const execFileAsync = promisify(execFile);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');

function validateArgs(items) {
  if (items.length !== 4 || items[0] !== '--project-id' ||
      items[2] !== '--confirm-project-id' ||
      items[1] !== PROJECT_ID || items[3] !== PROJECT_ID) {
    throw new Error('Provide --project-id and --confirm-project-id matching rokterbadhon-b247b.');
  }
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Unset emulator environment variables before checking Production.');
  }
}

async function getAccessToken() {
  try {
    // gcloud login user credentials, NOT the restricted Admin SDK ADC impersonation.
    // No shell-interpolated user input or tokens. stdout never printed to console.
    const args = process.platform === 'win32'
      ? ['/d', '/s', '/c', 'gcloud auth print-access-token']
      : ['auth', 'print-access-token'];
    const executable = process.platform === 'win32' ? 'cmd.exe' : 'gcloud';
    const { stdout } = await execFileAsync(executable, args, {
      encoding: 'utf8', timeout: 30000, maxBuffer: 100000,
      windowsHide: true,
    });
    const value = stdout.trim();
    if (!value || value.includes('\n') || value.includes('\r')) throw new Error('Invalid token.');
    return value;
  } catch (_) {
    throw new Error('gcloud account access unavailable (run gcloud auth login).');
  }
}

async function listCompositeIndexesWithGcloud() {
  // Official Google Cloud CLI lists the complete (default) database.
  // No deploy/create/delete command, and no untrusted input in shell commands.
  const cliArgs = [
    'firestore', 'indexes', 'composite', 'list',
    '--project=' + PROJECT_ID,
    '--format=json', '--quiet',
  ];
  const executable = process.platform === 'win32' ? 'cmd.exe' : 'gcloud';
  const args = process.platform === 'win32'
    ? ['/d', '/s', '/c', 'gcloud ' + cliArgs.join(' ')]
    : cliArgs;
  let stdout;
  try {
    ({ stdout } = await execFileAsync(executable, args, {
      encoding: 'utf8',
      timeout: 90000,
      maxBuffer: 12000000,
      windowsHide: true,
    }));
  } catch (_) {
    // gcloud subprocess error text could include account details.
    throw new Error('gcloud composite index listing failed; check owner CLI login and rerun safely.');
  }
  return parseGcloudCompositeIndexesJson(stdout);
}

function codeFrom(error) {
  const message = String(error?.message ?? '');
  const allowed = [
    'Google Cloud read HTTP ', 'Google Cloud read network failed.',
    'Google Cloud access token unavailable.',
    'gcloud account access unavailable',
    'Cannot safely compare multi-file',
    'Unexpected Firebase Rules',
    'Ruleset path does not match project.',
    'Unexpected deployed composite index',
    'Unsupported advanced index specification',
    'Malformed composite index',
    'Invalid index', 'Unexpected index', 'Invalid Google Cloud',
    'Repeated or invalid', 'Unusually large', 'Disallowed Rules',
    'Invalid local or deployed', 'Invalid gcloud',
    'gcloud did not return valid', 'gcloud composite index listing failed',
    'No read-only composite',
  ];
  const match = allowed.find((prefix) => message.startsWith(prefix));
  if (match) return message.replace(/[\r\n]/g, ' ').slice(0, 150);
  return 'API, permission or unexpected format error. Review Console manually.';
}

async function main() {
  validateArgs(process.argv.slice(2));
  const [localRules, localIndexText] = await Promise.all([
    readFile(resolve(root, 'firestore.rules'), 'utf8'),
    readFile(resolve(root, 'firestore.indexes.json'), 'utf8'),
  ]);
  const localIndexes = JSON.parse(localIndexText);
  const read = makeCloudRead({ getAccessToken });
  const result = {
    mode: 'READ_ONLY',
    projectId: PROJECT_ID,
    source: 'deployed Firebase Rules release and live composite indexes',
    firestoreRules: null,
    compositeIndexes: null,
    writesPerformed: 0,
    deployPerformed: false,
    firebaseAuthUsersRead: false,
    rulesAndCompositeIndexesMatch: false,
    completeDeploymentVerification: false,
  };
  try {
    result.firestoreRules = await auditLiveRules({
      projectId: PROJECT_ID, localRules, read,
    });
  } catch (error) {
    result.firestoreRules = { verified: false, error: codeFrom(error) };
  }
  try {
    result.compositeIndexes = await auditLiveIndexes({
      projectId: PROJECT_ID, localIndexes,
      listCompositeIndexes: listCompositeIndexesWithGcloud,
    });
  } catch (error) {
    result.compositeIndexes = { verified: false, error: codeFrom(error) };
  }
  result.rulesAndCompositeIndexesMatch =
    result.firestoreRules.exactContentMatch === true &&
    result.compositeIndexes.exactCompositeMatch === true;
  console.log(JSON.stringify(result, null, 2));
  if (!result.rulesAndCompositeIndexesMatch) process.exitCode = 2;
}

main().catch(() => {
  console.error('Deployment audit could not start. Check project flags and local files.');
  process.exitCode = 1;
});

import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  authorizeOperatorForRoles,
  authorizeTargetRole,
} from '../src/policy.js';

const ROOT = fileURLToPath(new URL('../../../', import.meta.url));
const source = (...parts) => join(ROOT, ...parts);

function filesUnder(directory, suffix) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return filesUnder(path, suffix);
    return path.endsWith(suffix) ? [path] : [];
  });
}

test('trusted operator stays outside Flutter and guards before Admin SDK initialization', () => {
  const flutter = filesUnder(source('lib'), '.dart')
    .map((path) => readFileSync(path, 'utf8'))
    .join('\n');
  const cli = readFileSync(source('tools', 'operator', 'cli.js'), 'utf8');

  assert.doesNotMatch(flutter, /firebase-admin|tools[\\/]operator/);
  assert.doesNotMatch(flutter, /assignAccessRole|assign-role|targetRole/);
  assert.match(cli, /assertSafeTarget/);
  assert.ok(cli.indexOf('assertSafeTarget({') < cli.indexOf('initializeApp('));
  assert.match(cli, /getFirestore\(app\)/);
  assert.match(cli, /getAuth\(app\)/);
});

test('every trusted mutation module independently authorizes and transacts audit evidence', () => {
  const modules = [
    'account.js',
    'admission.js',
    'blood_request.js',
    'committee.js',
    'committee_media.js',
    'committee_term.js',
    'donation.js',
    'donor.js',
    'event.js',
    'notice.js',
  ];
  for (const module of modules) {
    const contents = readFileSync(
      source('tools', 'operator', 'src', module),
      'utf8',
    );
    assert.match(contents, /authorizeOperator/, module);
    assert.match(contents, /\.runTransaction\(/, module);
    assert.match(contents, /collection\('audit_logs'\)/, module);
    assert.match(contents, /operationId/, module);
  }
  const recovery = readFileSync(
    source('tools', 'operator', 'src', 'developer_admin.js'),
    'utf8',
  );
  assert.match(recovery, /\.runTransaction\(/);
  assert.match(recovery, /collection\('audit_logs'\)/);
  assert.match(recovery, /operationId/);
});

test('legacy President title and missing security state grant no operator authority', () => {
  const authRecord = { emailVerified: true, disabled: false };
  const link = { active: true };
  const base = { active: true, login_enabled: true };
  for (const user of [
    { ...base, access_role: 'president' },
    { ...base, access_role: undefined },
    { ...base, access_role: 'leader', login_enabled: false },
  ]) {
    assert.throws(
      () => authorizeOperatorForRoles({
        authRecord,
        link,
        user,
        allowedRoles: ['developer_admin', 'leader'],
      }),
      (error) => error.code === 'operator_not_admitted',
    );
  }
  assert.throws(
    () => authorizeTargetRole('developer_admin', 'president'),
    (error) => error.code === 'unauthorized_role',
  );
});

test('Free V1 source has no hosted execution, scheduler, Storage, or upload dependency', () => {
  const firebase = JSON.parse(readFileSync(source('firebase.json'), 'utf8'));
  const rootPackage = JSON.parse(readFileSync(source('package.json'), 'utf8'));
  const pubspec = readFileSync(source('pubspec.yaml'), 'utf8');
  const trackedConfig = [
    readFileSync(source('firebase.json'), 'utf8'),
    readFileSync(source('firebase.emulator.json'), 'utf8'),
    readFileSync(source('package.json'), 'utf8'),
    pubspec,
  ].join('\n');

  assert.deepEqual(Object.keys(firebase), ['flutter']);
  assert.deepEqual(Object.keys(rootPackage.scripts), ['test:rules']);
  assert.doesNotMatch(
    trackedConfig,
    /firebase_storage|image_picker|cloud_functions|firebase_functions|cloud_run|pubsub|scheduler/i,
  );
});

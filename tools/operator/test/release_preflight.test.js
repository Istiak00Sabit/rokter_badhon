import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import {
  readProjectSources,
  inspectReleaseSources,
  inspectDebugApk,
} from '../../release/verify_candidate.mjs';

function fixture() {
  return readProjectSources();
}
function rejected(input, reason) {
  assert.throws(() => inspectReleaseSources(input),
    error => error.message.includes(reason));
}
test('consistent current Android/Firebase sources are verified but NEVER production-approved', () => {
  const result = inspectReleaseSources(fixture());
  assert.equal(result.sourceConsistent, true);
  assert.equal(result.placeholderAppId, true);
  assert.equal(result.productionReady, false);
  assert.equal(result.releaseApproval, 'NO_GO');
  assert.ok(result.ownerGates.includes('owner_approved_final_application_id'));
  assert.match(result.version, /^\d+\.\d+\.\d+$/);
  assert.ok(result.buildNumber > 0);
});

test('Firebase config mismatch or ambiguous Android package registration fails closed', () => {
  const invalidPackage = fixture();
  invalidPackage.gradle = invalidPackage.gradle.replace(
    'applicationId = "com.example.rokter_badhon"',
    'applicationId = "com.other.package"');
  rejected(invalidPackage, 'not uniquely registered');
  const badFlutterProject = fixture();
  badFlutterProject.firebaseOptions = badFlutterProject.firebaseOptions.replace(
    "projectId: 'rokterbadhon-b247b'", "projectId: 'unrelated-project'");
  rejected(badFlutterProject, 'project does not match');
  const badAppId = fixture();
  badAppId.googleServices.client[0].client_info.mobilesdk_app_id = 'unrelated';
  rejected(badAppId, 'app ID does not match');
  const repeatedClient = fixture();
  repeatedClient.googleServices.client.push(
    structuredClone(repeatedClient.googleServices.client[0]));
  rejected(repeatedClient, 'not uniquely registered');
  const badNamespace = fixture();
  badNamespace.mainActivity = 'package com.unrelated\n';
  rejected(badNamespace, 'MainActivity package');
});

test('release signing and internet/cleartext security regressions block preflight', () => {
  const debugSignedRelease = fixture();
  debugSignedRelease.gradle = debugSignedRelease.gradle.replace(
    'signingConfigs.getByName("release")', 'signingConfigs.getByName("debug")');
  rejected(debugSignedRelease, 'missing guarded owner-controlled release signing');
  const noGuard = fixture();
  noGuard.gradle = noGuard.gradle.replace('require(releaseSigningConfigured)', 'check(true)');
  rejected(noGuard, 'missing guarded owner-controlled release signing');
  const noInternet = fixture();
  noInternet.mainManifest = noInternet.mainManifest.replace(
    'android.permission.INTERNET', 'android.permission.OTHER');
  rejected(noInternet, 'no Internet permission');
  const publicCleartext = fixture();
  publicCleartext.mainManifest = publicCleartext.mainManifest.replace(
    '<application', '<application android:usesCleartextTraffic="true"');
  rejected(publicCleartext, 'unencrypted cleartext');
  const keysTracked = fixture();
  keysTracked.ignore = keysTracked.ignore.replace('/android/key.properties', '');
  rejected(keysTracked, 'sensitive signing files');
});

test('unsigned or missing APK cannot be mistaken for verified release artifact', () => {
  assert.throws(() => inspectDebugApk({
    apkPath: '/nonexistent/app-debug.apk',
    applicationId: 'com.example.rokter_badhon',
    sdkRoot: '/nonexistent/android/sdk',
  }), /debug APK missing or empty/);
});

test('version must have positive build number', () => {
  const broken = fixture();
  broken.pubspec = broken.pubspec.replace('version: 1.0.0+1', 'version: 1.0.0+0');
  rejected(broken, 'invalid or missing Android app version');
});

test('CI shares ONLY emulator-configured debug APK, with provenance and Android launch smoke', () => {
  const root = fileURLToPath(new URL('../../../', import.meta.url));
  const file = (...paths) => readFileSync(join(root, ...paths), 'utf8');
  const workflow = file('.github', 'workflows', 'flutter-checks.yml');
  const runtime = file('lib', 'config', 'firebase_runtime_config.dart');
  const verifier = file('tools', 'release', 'verify_candidate.mjs');
  const smoke = file('tools', 'release', 'android_smoke.sh');

  assert.match(workflow, /flutter build apk --debug\s+--dart-define=USE_FIREBASE_EMULATOR=true\s+--dart-define=FIREBASE_EMULATOR_HOST=127\.0\.0\.1/);
  assert.match(workflow, /--mode emulator-debug/);
  assert.match(workflow, /--commit-sha \$\{\{ github\.sha \}\}/);
  assert.match(workflow, /--run-id \$\{\{ github\.run_id \}\}/);
  assert.match(workflow, /rokter-badhon-emulator-debug-apk/);
  assert.doesNotMatch(workflow, /name: rokter-badhon-debug-apk\b/);
  assert.match(workflow, /needs: flutter/);
  assert.match(workflow, /reactivecircus\/android-emulator-runner@v2/);
  assert.match(workflow, /bash tools\/release\/android_smoke\.sh/);
  assert.match(smoke, /adb install -r -t/);
  assert.match(smoke, /adb shell am start -n/);
  assert.match(smoke, /assert_healthy/);
  assert.match(smoke, /mResumedActivity/);
  assert.match(smoke, /AndroidRuntime:E/);
  assert.doesNotMatch(smoke, /adb shell am start -W/);
  assert.match(smoke, /adb shell am force-stop/);
  assert.match(smoke, /targetDeclaration.*firebase-emulator-only/);
  assert.match(runtime, /'USE_FIREBASE_EMULATOR'/);
  assert.match(runtime, /defaultValue: false/);
  assert.match(runtime, /useAuthEmulator\(/);
  assert.match(runtime, /useFirestoreEmulator\(/);
  assert.match(verifier, /mode === 'emulator-debug'/);
  assert.match(verifier, /'firebase-emulator-only'/);
  assert.match(verifier, /targetAttestation/);
});

test('real production app cannot be declared ready by emulator smoke or debug APK', () => {
  const root = fileURLToPath(new URL('../../../', import.meta.url));
  const load = (...paths) => readFileSync(join(root, ...paths), 'utf8');
  const smoke = load('tools', 'release', 'android_smoke.sh');
  const verifier = load('tools', 'release', 'verify_candidate.mjs');
  assert.match(smoke, /NO production acceptance/);
  assert.match(verifier, /releaseApproval: 'NO_GO'/);
  assert.match(verifier, /productionReady: false/);
});


test('cloud Android UI acceptance starts isolated real Auth/Firestore emulators, not production', () => {
  const root = fileURLToPath(new URL('../../../', import.meta.url));
  const load = (...paths) => readFileSync(join(root, ...paths), 'utf8');
  const workflow = load('.github', 'workflows', 'flutter-checks.yml');
  const start = load('tools', 'release', 'start_demo_emulators.sh');
  const ui = load('tools', 'release', 'android_ui_acceptance.py');
  const phone = load('docs', 'PHONE_TESTING.md');

  assert.match(workflow, /bash tools\/release\/start_demo_emulators\.sh/);
  assert.match(workflow, /python3 tools\/release\/android_ui_acceptance\.py/);
  assert.match(workflow, /FIRESTORE_EMULATOR_HOST: 127\.0\.0\.1:8080/);
  assert.match(workflow, /FIREBASE_AUTH_EMULATOR_HOST: 127\.0\.0\.1:9099/);
  assert.match(start, /project="demo-rokter-badhon"/);
  assert.match(start, /--only auth,firestore/);
  assert.match(start, /seed-test-admin --project-id/);
  assert.match(start, /seed-empty-demo-donor-registry --project-id/);
  assert.match(start, /audit-donor-registry --project-id/);
  assert.match(start, /GOOGLE_APPLICATION_CREDENTIALS/);
  assert.match(start, /GITHUB_ACTIONS/);
  assert.match(ui, /"01000000000"/);
  assert.match(ui, /"123456"/);
  assert.match(ui, /"English"/);
  assert.match(ui, /"Sign in"/);
  assert.match(ui, /"Current committee"/);
  assert.match(ui, /FIRESTORE_EMULATOR_HOST/);
  assert.match(ui, /FIREBASE_AUTH_EMULATOR_HOST/);
  assert.match(phone, /rokter-badhon-emulator-debug-apk/);
});

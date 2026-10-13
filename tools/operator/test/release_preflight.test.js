import assert from 'node:assert/strict';
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

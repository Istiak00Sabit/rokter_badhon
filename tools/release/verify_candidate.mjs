import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

function ensure(ok, message) {
  if (!ok) throw new Error('Release candidate preflight: ' + message);
}
function property(src, name) {
  const found = src.match(new RegExp('\\b' + name + "\\s*:\\s*'([^']+)'"));
  ensure(Boolean(found), 'missing Android Firebase option: ' + name);
  return found[1];
}
function gradleField(gradle, field) {
  const match = gradle.match(new RegExp('\\b' + field + '\\s*=\\s*"([^"]+)"'));
  ensure(Boolean(match), 'missing static Gradle ' + field);
  return match[1];
}

/** Source-level consistency, NOT owner authorization or release signing. */
export function inspectReleaseSources({
  gradle, googleServices, firebaseOptions, mainManifest, debugManifest,
  mainActivity, ignore, pubspec,
}) {
  const applicationId = gradleField(gradle, 'applicationId');
  const namespace = gradleField(gradle, 'namespace');
  const version = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+([1-9]\d*)\s*$/m);
  ensure(Boolean(version), 'invalid or missing Android app version/build number');
  ensure(mainActivity.includes('package ' + namespace),
    'MainActivity package differs from Android Gradle namespace');
  ensure(/android\.permission\.INTERNET/.test(mainManifest),
    'release manifest has no Internet permission');
  ensure(!/usesCleartextTraffic\s*=\s*"true"/.test(mainManifest),
    'production manifest permits unencrypted cleartext traffic');
  ensure(/usesCleartextTraffic\s*=\s*"true"/.test(debugManifest),
    'local emulator cleartext setting missing in debug manifest');

  ensure(/releaseTaskRequested/.test(gradle) &&
    /require\(releaseSigningConfigured\)/.test(gradle) &&
    /signingConfigs\.getByName\("release"\)/.test(gradle),
    'missing guarded owner-controlled release signing configuration');
  ensure(!/signingConfigs\.getByName\("debug"\)/.test(gradle) &&
    !/signingConfig\s*=\s*signingConfigs\.debug/.test(gradle),
    'release config must not use debug signing');
  for (const value of ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']) {
    ensure(gradle.includes('"' + value + '"'), 'missing signing property ' + value);
  }
  for (const required of ['/android/key.properties', '/android/*.jks',
    '/android/app/*.jks', '/android/*.keystore']) {
    ensure(ignore.includes(required), 'sensitive signing files not ignored by Git');
  }

  ensure(googleServices && Array.isArray(googleServices.client) &&
    googleServices.project_info, 'malformed google-services.json');
  const matches = googleServices.client.filter(client =>
    client.client_info?.android_client_info?.package_name === applicationId);
  ensure(matches.length === 1,
    'Android application ID is not uniquely registered in Google Services');
  const androidOptions = firebaseOptions.match(
    /static const FirebaseOptions android\s*=\s*FirebaseOptions\(([\s\S]*?)\);/);
  ensure(Boolean(androidOptions), 'missing Flutter Android Firebase settings');
  const opts = androidOptions[1];
  ensure(property(opts, 'projectId') === googleServices.project_info.project_id,
    'Flutter Android project does not match Google Services');
  ensure(property(opts, 'appId') === matches[0].client_info.mobilesdk_app_id,
    'Flutter Android Firebase app ID does not match Google Services');
  ensure(property(opts, 'messagingSenderId') ===
    String(googleServices.project_info.project_number),
    'Firebase messaging sender/project number mismatch');
  ensure(property(opts, 'appId').includes(':android:'),
    'Android Flutter Firebase entry is not a registered Android app');

  const placeholderAppId = applicationId.startsWith('com.example.');
  return {
    kind: 'source-only',
    sourceConsistent: true,
    applicationId,
    version: version[1],
    buildNumber: Number(version[2]),
    placeholderAppId,
    productionReady: false,
    releaseApproval: 'NO_GO',
    ownerGates: [
      ...(placeholderAppId ? ['owner_approved_final_application_id'] : []),
      'owner_approved_firebase_configuration',
      'private_release_signing_key_and_verified_signed_artifact',
      'firebase_rules_indexes_and_donor_registry_cutover',
      'physical_android_acceptance_and_recovery_review',
    ],
  };
}

export function readProjectSources(base = root) {
  const load = (...parts) => readFileSync(join(base, ...parts), 'utf8');
  return {
    gradle: load('android', 'app', 'build.gradle.kts'),
    googleServices: JSON.parse(load('android', 'app', 'google-services.json')),
    firebaseOptions: load('lib', 'firebase_options.dart'),
    mainManifest: load('android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    debugManifest: load('android', 'app', 'src', 'debug', 'AndroidManifest.xml'),
    mainActivity: load('android', 'app', 'src', 'main', 'kotlin',
      'com', 'example', 'rokter_badhon', 'MainActivity.kt'),
    ignore: load('.gitignore'),
    pubspec: load('pubspec.yaml'),
  };
}

function androidBuildTools(sdkRoot) {
  ensure(Boolean(sdkRoot), 'Android SDK path not configured for artifact inspection');
  const dir = join(sdkRoot, 'build-tools');
  ensure(existsSync(dir), 'Android SDK build-tools directory missing');
  const versions = readdirSync(dir).sort((a, b) =>
    b.localeCompare(a, undefined, { numeric: true }));
  for (const version of versions) {
    const aapt = join(dir, version, process.platform === 'win32' ? 'aapt.exe' : 'aapt');
    const signer = join(dir, version,
      process.platform === 'win32' ? 'apksigner.bat' : 'apksigner');
    if (existsSync(aapt) && existsSync(signer)) return { aapt, signer };
  }
  throw new Error('Release candidate preflight: Android aapt/apksigner unavailable');
}

/** Real built debug APK metadata + signature, not an assertion about release signing. */
export function inspectDebugApk({ apkPath, applicationId, sdkRoot }) {
  ensure(existsSync(apkPath) && statSync(apkPath).size > 0,
    'debug APK missing or empty');
  const { aapt, signer } = androidBuildTools(sdkRoot);
  const badging = execFileSync(aapt, ['dump', 'badging', apkPath],
    { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 });
  const pkg = badging.match(/^package:\s+name='([^']+)'/m);
  ensure(pkg && pkg[1] === applicationId,
    'built APK package ID differs from checked source');
  const permissions = execFileSync(aapt, ['dump', 'permissions', apkPath],
    { encoding: 'utf8' });
  ensure(permissions.includes("android.permission.INTERNET"),
    'built APK lacks Internet permission');
  execFileSync(signer, ['verify', '--verbose', apkPath],
    { encoding: 'utf8' });
  const sha256 = createHash('sha256').update(readFileSync(apkPath)).digest('hex');
  return {
    kind: 'debug-apk-only',
    verifiedPackage: true,
    internetPermission: true,
    apkSignatureVerified: true,
    sha256,
    sizeBytes: statSync(apkPath).size,
    productionReady: false,
    releaseApproval: 'NO_GO',
  };
}

function main() {
  const args = process.argv.slice(2);
  ensure(args.every((a, i) => ['--source-only', '--apk', '--out'].includes(a) ||
    (i > 0 && ['--apk', '--out'].includes(args[i - 1]))),
  'unsupported command argument');
  const source = inspectReleaseSources(readProjectSources());
  const apkIndex = args.indexOf('--apk');
  const report = { source };
  if (apkIndex !== -1) {
    ensure(Boolean(args[apkIndex + 1]), '--apk requires a file path');
    report.debugApk = inspectDebugApk({
      apkPath: resolve(args[apkIndex + 1]),
      applicationId: source.applicationId,
      sdkRoot: process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT,
    });
  }
  const outIndex = args.indexOf('--out');
  if (outIndex !== -1) {
    ensure(Boolean(args[outIndex + 1]), '--out requires a file path');
    writeFileSync(resolve(args[outIndex + 1]), JSON.stringify(report, null, 2) + '\n');
  }
  // Print only non-sensitive source/build metadata and NO-GO gates.
  console.log(JSON.stringify(report, null, 2));
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

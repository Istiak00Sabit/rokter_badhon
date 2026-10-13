#!/usr/bin/env bash
set -euo pipefail

# Minimal Android-runtime smoke test of the Firebase-emulator-only APK.
# Never use this script with a production-configured APK.
apk="${1:-build/app/outputs/flutter-apk/app-debug.apk}"
package="com.example.rokter_badhon"
activity="com.example.rokter_badhon/.MainActivity"

if [[ ! -s "$apk" ]]; then
  echo "Android smoke: missing or empty emulator test APK."
  exit 1
fi
if [[ ! -f release-preflight.json ]]; then
  echo "Android smoke: missing source/build verification manifest."
  exit 1
fi
node --input-type=module -e '
  import fs from "node:fs";
  import assert from "node:assert/strict";
  const p = JSON.parse(fs.readFileSync("release-preflight.json", "utf8"));
  assert.equal(p.source.releaseApproval, "NO_GO");
  assert.equal(p.debugApk.releaseApproval, "NO_GO");
  assert.equal(p.debugApk.targetDeclaration, "firebase-emulator-only");
  assert.equal(p.debugApk.verifiedPackage, true);
  assert.equal(p.debugApk.apkSignatureVerified, true);
  assert.equal(p.debugApk.internetPermission, true);
  assert.match(p.debugApk.sha256, /^[0-9a-f]{64}$/);
'

echo "Android smoke: installing emulator-only debug APK..."
adb install -r -t "$apk" >/dev/null
# If no Firebase emulators are running, these routes still fail closed
# rather than contacting the real Firebase backend.
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb logcat -c

echo "Android smoke: opening Flutter activity..."
launch="$(adb shell am start -W -n "$activity")"
if ! grep -q 'Status: ok' <<< "$launch"; then
  echo "Android smoke: the launcher did not report success."
  exit 1
fi

for i in $(seq 1 20); do
  pid="$(adb shell pidof "$package" 2>/dev/null | tr -d '\r' || true)"
  if [[ -n "$pid" ]]; then break; fi
  sleep 2
done
if [[ -z "${pid:-}" ]]; then
  echo "Android smoke: app process did not start."
  exit 1
fi

sleep 8
if [[ -z "$(adb shell pidof "$package" 2>/dev/null || true)" ]]; then
  echo "Android smoke: app process did not survive startup."
  exit 1
fi
# Filter the AndroidRuntime error buffer to this application's process.
if adb logcat -d -s AndroidRuntime:E | grep -F "Process: $package," >/dev/null; then
  echo "Android smoke: app-specific fatal exception detected."
  exit 1
fi

echo "Android smoke: relaunching after a force stop..."
adb shell am force-stop "$package"
restart="$(adb shell am start -W -n "$activity")"
if ! grep -q 'Status: ok' <<< "$restart"; then
  echo "Android smoke: app failed to restart."
  exit 1
fi
sleep 6
if [[ -z "$(adb shell pidof "$package" 2>/dev/null || true)" ]]; then
  echo "Android smoke: app process did not survive restart."
  exit 1
fi
if adb logcat -d -s AndroidRuntime:E | grep -F "Process: $package," >/dev/null; then
  echo "Android smoke: fatal exception after restart."
  exit 1
fi
echo "Android emulator launch/restart smoke: PASS (NO production acceptance)"

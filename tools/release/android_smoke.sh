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
  if (process.env.GITHUB_SHA) assert.equal(p.debugApk.gitCommit, process.env.GITHUB_SHA);
  if (process.env.GITHUB_RUN_ID) assert.equal(p.debugApk.githubRunId, process.env.GITHUB_RUN_ID);
'

# The report and APK must describe the exact same binary, not just a
# syntactically valid SHA-256 field.
actual_sha="$(sha256sum "$apk" | cut -d' ' -f1)"
reported_sha="$(node -p 'JSON.parse(require("fs").readFileSync("release-preflight.json", "utf8")).debugApk.sha256')"
if [[ "$actual_sha" != "$reported_sha" ]]; then
  echo "Android smoke: APK checksum disagrees with same-run verification report."
  exit 1
fi

echo "Android smoke: installing emulator-only debug APK..."
adb install -r -t "$apk" >/dev/null
# If no Firebase emulators are running, these routes still fail closed
# rather than contacting the real Firebase backend.
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb logcat -c

# A cold Flutter/Firebase startup sometimes exceeds the ActivityManager
# wait timeout. "am start -W" can report a timeout even while the app is
# starting normally; instead require the process to launch, survive, remain
# foreground, and avoid an app-specific fatal Android exception.
assert_healthy() {
  local phase="$1"
  local pid=""
  local foreground=""
  for i in $(seq 1 25); do
    pid="$(adb shell pidof "$package" 2>/dev/null | tr -d '\r' || true)"
    if [[ -n "$pid" ]]; then break; fi
    sleep 2
  done
  if [[ -z "$pid" ]]; then
    echo "Android smoke: $phase did not create an app process."
    return 1
  fi
  sleep 6
  if [[ -z "$(adb shell pidof "$package" 2>/dev/null || true)" ]]; then
    echo "Android smoke: $phase process exited."
    return 1
  fi
  foreground="$(adb shell dumpsys activity activities 2>/dev/null || true)"
  if ! grep -Eq "mResumedActivity.*$package|topResumedActivity.*$package" <<< "$foreground"; then
    echo "Android smoke: $phase did not retain foreground activity."
    return 1
  fi
  if adb logcat -d -s AndroidRuntime:E | grep -F "Process: $package," >/dev/null; then
    echo "Android smoke: app-specific fatal exception during $phase."
    return 1
  fi
}

launch_app() {
  local phase="$1"
  local output=""
  if ! output="$(adb shell am start -n "$activity" 2>&1)"; then
    echo "Android smoke: ActivityManager could not launch during $phase."
    return 1
  fi
  if grep -Eq 'Error:|Exception|does not exist' <<< "$output"; then
    echo "Android smoke: ActivityManager rejected the $phase launch."
    return 1
  fi
  assert_healthy "$phase"
}

echo "Android smoke: opening Flutter activity..."
launch_app "initial startup"
echo "Android smoke: relaunching after a force stop..."
adb shell am force-stop "$package"
launch_app "restart"
echo "Android emulator launch/restart smoke: PASS (NO production acceptance)"

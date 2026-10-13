#!/usr/bin/env bash
set -euo pipefail

# Ephemeral GitHub Actions runner only. Never run against live Firebase.
project="demo-rokter-badhon"
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
if [[ "${CI:-}" != "true" || "${GITHUB_ACTIONS:-}" != "true" ]]; then
  echo "Cloud smoke fixture is restricted to GitHub Actions CI."
  exit 1
fi
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" || -n "${GCLOUD_PROJECT:-}" ]]; then
  echo "Credentials or alternate project environment detected; refusing test seed."
  exit 1
fi

./node_modules/.bin/firebase emulators:start \
  --config firebase.emulator.json --project "$project" \
  --only auth,firestore > "$RUNNER_TEMP/firebase-emulators.log" 2>&1 &
emulator_pid=$!
echo "$emulator_pid" > "$RUNNER_TEMP/rokter-emulator.pid"

for i in $(seq 1 90); do
  if ! kill -0 "$emulator_pid" 2>/dev/null; then
    echo "Local Firebase emulator exited before opening required ports."
    tail -n 30 "$RUNNER_TEMP/firebase-emulators.log"
    exit 1
  fi
  if (echo >/dev/tcp/127.0.0.1/8080) 2>/dev/null &&
      echo >/dev/tcp/127.0.0.1/9099) 2>/dev/null; then
    break
  fi
  sleep 2
done
if ! (echo >/dev/tcp/127.0.0.1/8080) 2>/dev/null ||
   ! (echo >/dev/tcp/127.0.0.1/9099) 2>/dev/null; then
  echo "Local Firebase emulator ports were not ready."
  exit 1
fi

# Do not export or inspect personal production data. Local synthetic fixtures.
node tools/operator/cli.js seed-test-admin --project-id "$project" >/dev/null
node tools/operator/cli.js seed-empty-demo-donor-registry --project-id "$project" >/dev/null
node tools/operator/cli.js audit-donor-registry --project-id "$project" > "$RUNNER_TEMP/demo-registry-audit.json"
node --input-type=module -e '
import assert from "node:assert/strict";
import fs from "node:fs";
const audit=JSON.parse(fs.readFileSync(process.env.RUNNER_TEMP+"/demo-registry-audit.json", "utf8"));
assert.equal(audit.releaseReady,true);
assert.equal(audit.donorsScanned,0);
assert.equal(audit.reservationsScanned,0);
assert.equal(audit.writesPerformed,0);
'
echo "Emulator Auth+Firestore readiness and empty donor registry: PASS (synthetic only)"

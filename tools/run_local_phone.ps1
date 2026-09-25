[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceId
)

$ErrorActionPreference = 'Stop'
$projectId = 'demo-rokter-badhon'
$repoRoot = Split-Path -Parent $PSScriptRoot
$apkPath = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'

Set-Location $repoRoot

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'firebase.emulator.json'))) {
    throw "Run this script from the Rokter Badhon checkout."
}

$deviceState = (& adb -s $DeviceId get-state 2>$null | Out-String).Trim()
if ($deviceState -ne 'device') {
    throw "ADB device '$DeviceId' is not online. Run 'adb devices' and enable USB debugging."
}

$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'

Write-Host 'Seeding the local test administrator...'
& node tools/operator/cli.js seed-test-admin --project-id $projectId
if ($LASTEXITCODE -ne 0) { throw 'The local emulator seed failed.' }

Write-Host 'Building the emulator-configured debug APK...'
& flutter build apk --debug `
    --dart-define=USE_FIREBASE_EMULATOR=true `
    --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
if ($LASTEXITCODE -ne 0) { throw 'The Flutter debug build failed.' }

Write-Host 'Installing the APK...'
& adb -s $DeviceId install -r -t $apkPath
if ($LASTEXITCODE -ne 0) { throw 'The APK installation failed.' }

Write-Host 'Applying USB emulator routes after installation...'
& adb -s $DeviceId reverse tcp:9099 tcp:9099
if ($LASTEXITCODE -ne 0) { throw 'ADB Auth reverse setup failed.' }
& adb -s $DeviceId reverse tcp:8080 tcp:8080
if ($LASTEXITCODE -ne 0) { throw 'ADB Firestore reverse setup failed.' }

Write-Host 'Launching the app...'
& adb -s $DeviceId shell am force-stop com.example.rokter_badhon
& adb -s $DeviceId shell monkey -p com.example.rokter_badhon -c android.intent.category.LAUNCHER 1 | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'The app launch failed.' }

Write-Host ''
Write-Host 'Local phone testing is ready. Keep the Auth/Firestore emulator terminal running.'
Write-Host 'Login: use the emulator-only account documented in docs/LOCAL_EMULATOR_TESTING.md.'

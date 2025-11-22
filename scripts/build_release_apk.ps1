<#
PowerShell helper script to create a keystore (if missing) and build a Flutter release APK.

Usage (run from repo root):
  .\scripts\build_release_apk.ps1

This script will:
  - Check for keytool and flutter
  - Create android/app/jomarket-release.keystore if missing
  - (Optionally) update android/key.properties with the provided passwords
  - Run `flutter build apk --release`
  - Copy the final APK(s) to `release/apk/`

NOTE: This script writes the `android/key.properties` file with store/key passwords in plaintext locally. Keep it private and DO NOT commit sensitive credentials to version control.
#>

Set-StrictMode -Version Latest

function Abort([string]$msg) {
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

Push-Location $PSScriptRoot/.. | Out-Null

if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
    Abort '`keytool` not found. Install JDK or ensure `keytool` is on PATH.'
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Abort '`flutter` not found. Install Flutter SDK and add to PATH.'
}

$keystoreRel = 'android/app/jomarket-release.keystore'
$keystorePath = Join-Path (Get-Location) $keystoreRel

if (-not (Test-Path $keystorePath)) {
    Write-Host "Release keystore not found at: $keystoreRel" -ForegroundColor Yellow
    $create = Read-Host "Create a new keystore at $keystoreRel? (y/N)"
    if ($create -ne 'y' -and $create -ne 'Y') { Abort 'Keystore required for signing. Aborting.' }

    $alias = Read-Host 'Enter key alias (example: jomarket)'
    if ([string]::IsNullOrWhiteSpace($alias)) { $alias = 'jomarket' }

    $storePass = Read-Host 'Enter store password (visible)' -AsSecureString
    $storePassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePass))

    $keyPass = Read-Host 'Enter key password (visible)' -AsSecureString
    $keyPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPass))

    Write-Host 'Creating keystore...' -ForegroundColor Cyan
    # keytool will prompt for any missing info; we pass storepass/keypass to avoid interactive repetition
    & keytool -genkeypair -v -keystore $keystorePath -alias $alias -keyalg RSA -keysize 2048 -validity 10000 -storepass $storePassPlain -keypass $keyPassPlain
    if ($LASTEXITCODE -ne 0) { Abort 'keytool failed to create keystore.' }

    # Create / update android/key.properties
    $keyPropertiesPath = 'android/key.properties'
    $content = @()
    $content += "storePassword=$storePassPlain"
    $content += "keyPassword=$keyPassPlain"
    $content += "keyAlias=$alias"
    $content += "storeFile=app/jomarket-release.keystore"

    Write-Host "Writing $keyPropertiesPath (local file)" -ForegroundColor Cyan
    $content -join "`n" | Out-File -FilePath $keyPropertiesPath -Encoding utf8 -Force
    Write-Host "Keystore created and key.properties updated." -ForegroundColor Green
} else {
    Write-Host "Found existing keystore at $keystoreRel" -ForegroundColor Green
}

Write-Host 'Running flutter build apk --release' -ForegroundColor Cyan
pushd .
try {
    & flutter clean
    & flutter pub get
    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) { Abort 'flutter build apk failed.' }
} finally { popd }

$outputDir = 'build/app/outputs/flutter-apk'
if (-not (Test-Path $outputDir)) { Abort "Build output not found at $outputDir" }

$releaseOutputs = Get-ChildItem -Path $outputDir -Filter "*.apk" -Recurse | Select-Object -ExpandProperty FullName
if (-not $releaseOutputs) { Abort 'No APKs found after build.' }

$releaseFolder = 'release/apk'
if (-not (Test-Path $releaseFolder)) { New-Item -ItemType Directory -Path $releaseFolder | Out-Null }

foreach ($apk in $releaseOutputs) {
    Copy-Item -Path $apk -Destination $releaseFolder -Force
    Write-Host "Copied: $apk -> $releaseFolder" -ForegroundColor Green
}

Write-Host "Release APK(s) available in: $releaseFolder" -ForegroundColor Green

Pop-Location | Out-Null

Write-Host 'Done.' -ForegroundColor Cyan

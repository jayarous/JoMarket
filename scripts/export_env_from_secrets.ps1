param(
  [string]$Out = "env/.env"
)

# Cross-platform PowerShell script to export known secrets into an env file.
# Usage: .\scripts\export_env_from_secrets.ps1 -Out env/.env

Set-StrictMode -Version Latest

$vars = @(
  'SUPABASE_URL',
  'SUPABASE_KEY',
  'STRIPE_PUBLISHABLE_KEY',
  'STRIPE_SECRET_KEY',
  'SENTRY_DSN',
  'FIREBASE_CONFIG_JSON',
  'FLUTTER_ENV'
)

$outDir = Split-Path -Path $Out -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$lines = @()
foreach ($v in $vars) {
  $val = (Get-Item -Path Env:$v -ErrorAction SilentlyContinue).Value
  if ($null -ne $val -and $val -ne '') {
    # Escape double quotes inside value
    $safe = $val -replace '"', '""'
    $lines += "$v=`"$safe`""
  }
}

if ($lines.Count -eq 0) {
  Write-Error "No known env vars found in environment; $Out would be empty.";
  exit 1
}

$lines -join "`n" | Out-File -FilePath $Out -Encoding UTF8 -Force
Write-Host "Wrote $Out from environment variables (not committed)."

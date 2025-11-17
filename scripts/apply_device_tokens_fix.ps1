<#
.SYNOPSIS
Apply the device_tokens constraint fix migration to the database.

.DESCRIPTION
This script applies the migration that adds a unique constraint to the device_tokens table
to fix the "no unique or exclusion constraint matching the ON CONFLICT specification" error.

.PARAMETER ConnectionString
PostgreSQL connection string (e.g., from Supabase)
Example: postgres://postgres:[password]@db.[project].supabase.co:5432/postgres

.EXAMPLE
$env:PG_CONN = 'postgres://postgres:password@db.example.supabase.co:5432/postgres'
.\apply_device_tokens_fix.ps1

.EXAMPLE
.\apply_device_tokens_fix.ps1 -ConnectionString 'postgres://postgres:password@db.example.supabase.co:5432/postgres'
#>

[CmdletBinding()]
param(
    [string]$ConnectionString,
    [string]$PsqlPath = 'psql'
)

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Success($msg) { Write-Host "[SUCCESS] $msg" -ForegroundColor Green }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Split-Path -Parent $scriptDir
$migrationFile = Join-Path $projectRoot "migrations\split\39_fix_device_tokens_constraint.sql"

# Check if migration file exists
if (-not (Test-Path $migrationFile)) {
    Write-Err "Migration file not found: $migrationFile"
    exit 1
}

# Get connection string
if (-not $ConnectionString) {
    $envConn = $env:PG_CONN
    if ($envConn) {
        $ConnectionString = $envConn
        Write-Info "Using connection string from PG_CONN environment variable."
    } else {
        Write-Err "No connection string provided. Set PG_CONN environment variable or use -ConnectionString parameter."
        exit 1
    }
}

# Check if psql is available
try {
    $null = & $PsqlPath --version 2>&1
} catch {
    Write-Err "psql command not found. Please install PostgreSQL client tools."
    exit 1
}

Write-Info "Applying migration: 39_fix_device_tokens_constraint.sql"
Write-Info "This will add a unique constraint on (user_id, token) to the device_tokens table."

# Apply the migration
$args = @($ConnectionString, '--set=ON_ERROR_STOP=on', '-f', $migrationFile)
& $PsqlPath @args

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    Write-Err "Migration failed with exit code $exitCode"
    exit $exitCode
}

Write-Success "Migration applied successfully!"
Write-Info "The device_tokens table now has a unique constraint on (user_id, token)."
Write-Info "The app should now be able to save device tokens without errors."

exit 0

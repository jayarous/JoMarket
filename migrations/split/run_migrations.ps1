<#
Run split migration files in order and their corresponding policy files.

Usage examples:
# Using a connection string (recommended for Supabase service_role URL):
.
$env:PG_CONN = 'postgres://service_role:PASSWORD@db.example.supabase.co:5432/postgres'
.
# Then run the script (it will read PG_CONN env var):
.
PowerShell -File .\run_migrations.ps1

# Or pass connection parameters interactively:
PowerShell -File .\run_migrations.ps1 -Host db.example.supabase.co -Port 5432 -User postgres -Database postgres -Password "mypassword"

Notes:
- Requires `psql` (Postgres client) available in PATH.
- The script stops on first failing SQL and returns a non-zero exit code.
- It runs each top-level numbered SQL file in the current directory (e.g. `01_*.sql`, `02_*.sql`, ...),
  and then runs every policy file from `policies/` that shares the same numeric prefix (e.g. `11_*`).
- For safety, the script sets PGPASSWORD in the environment when a password is provided.
- psql is invoked with ON_ERROR_STOP enabled so psql aborts on SQL errors.
#>
[CmdletBinding()]
param(
    [string]$ConnectionString,
    [string]$DbHost,
    [int]$Port = 5432,
    [string]$User,
    [string]$Database,
    [string]$Password,
    [string]$PsqlPath = 'psql'
)

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Err($msg){ Write-Host "[ERROR] $msg" -ForegroundColor Red }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

# Build base psql args
if (-not $ConnectionString) {
    if (-not $DbHost -or -not $User -or -not $Database) {
        Write-Host "Connection details not provided. You can either set the PG_CONN environment variable (postgres://...) or pass -Host -User -Database (-Password optional)." -ForegroundColor Yellow
        $envConn = $env:PG_CONN
        if ($envConn) {
            $ConnectionString = $envConn
            Write-Info "Using connection string from PG_CONN environment variable."
        } else {
            throw "Missing connection information. Provide -ConnectionString or host/user/database (or set PG_CONN)."
        }
    }
}

if ($Password) { $env:PGPASSWORD = $Password }

Write-Info "psql path: $PsqlPath"
if ($ConnectionString) {
    $baseArgs = @($ConnectionString, '--set=ON_ERROR_STOP=on')
} else {
    $baseArgs = @('-h', $DbHost, '-p', [string]$Port, '-U', $User, '-d', $Database, '--set=ON_ERROR_STOP=on')
}

# Gather top-level SQL files (exclude the policies directory and runner script)
$tableFiles = Get-ChildItem -Path $scriptDir -Filter '*.sql' | Where-Object {
    $_.PSIsContainer -eq $false -and $_.FullName -notlike "*$([IO.Path]::Combine('policies','*'))*" -and $_.Name -match '^[0-9]{2}_.+\.sql$'
} | Sort-Object Name

if ($tableFiles.Count -eq 0) {
    Write-Err "No table SQL files found in $scriptDir"
    exit 1
}

Write-Info "Found $($tableFiles.Count) SQL file(s) to run."

$failedPolicies = @()

foreach ($f in $tableFiles) {
    Write-Host "\n----- Running $($f.Name) -----" -ForegroundColor Green
    $filePath = $f.FullName

    $args = @($baseArgs) + @('-f', $filePath)

    & $PsqlPath @args
    $rc = $LASTEXITCODE
    if ($rc -ne 0) {
        Write-Err "psql failed while running $($f.Name) with exit code $rc. Aborting."
        exit $rc
    }
    Write-Info "$($f.Name) completed successfully."

    # Determine numeric prefix and run all matching policy files (e.g. 11_orders_*.sql)
    $prefixMatch = [regex]::Match($f.BaseName, '^(?<prefix>[0-9]+)_')
    if (-not $prefixMatch.Success) {
        Write-Info "Skipping policy lookup for $($f.Name) because no numeric prefix was detected."
        continue
    }
    $prefix = $prefixMatch.Groups['prefix'].Value
    $policiesDir = Join-Path $scriptDir 'policies'
    if (Test-Path $policiesDir) {
        $policyFiles = Get-ChildItem -Path $policiesDir -Filter '*.sql' | Where-Object {
            $_.BaseName -match "^$prefix`_"
        } | Sort-Object Name

        if ($policyFiles.Count -gt 0) {
            foreach ($policy in $policyFiles) {
                Write-Host "-> Running policy file $($policy.Name) (prefix $prefix)..." -ForegroundColor Cyan
                $pArgs = @($baseArgs) + @('-f', $policy.FullName)
                & $PsqlPath @pArgs
                $prc = $LASTEXITCODE
                if ($prc -ne 0) {
                    Write-Err "psql failed while running policy $($policy.Name) with exit code $prc. Recording and continuing."
                    $failedPolicies += $policy.FullName
                } else {
                    Write-Info "Policy $($policy.Name) applied successfully."
                }
            }
        } else {
            Write-Info "No policy files found for prefix $prefix; continuing."
        }
    } else {
        Write-Info "Policies directory not found; skipping policy application."
    }
}

# Optional: run triggers/rls file if present
$triggersFile = Join-Path $scriptDir '24_triggers_and_rls.sql'
if (Test-Path $triggersFile) {
    Write-Host "\n----- Running triggers and RLS ($([IO.Path]::GetFileName($triggersFile))) -----" -ForegroundColor Green
    $tArgs = @($baseArgs) + @('-f', $triggersFile)
    & $PsqlPath @tArgs
    $trc = $LASTEXITCODE
    if ($trc -ne 0) {
        Write-Err "psql failed while running $triggersFile with exit code $trc. Aborting."
        exit $trc
    }
    Write-Info "Triggers and RLS applied successfully."
} else {
    Write-Info "No triggers/rls file found (expected: 24_triggers_and_rls.sql)."
}

# Retry any failed policy files once more now that all tables/triggers have been created.
if ($failedPolicies.Count -gt 0) {
    Write-Host "\nAttempting to re-run $($failedPolicies.Count) previously failed policy file(s) ..." -ForegroundColor Yellow
    $stillFailed = @()
    foreach ($pf in $failedPolicies) {
        Write-Host "-> Retrying policy: $pf" -ForegroundColor Cyan
        $pArgs = @($baseArgs) + @('-f', $pf)
        & $PsqlPath @pArgs
        $prc = $LASTEXITCODE
        if ($prc -ne 0) {
            Write-Err "Policy $pf still failed with exit code $prc."
            $stillFailed += $pf
        } else {
            Write-Info "Policy $pf applied successfully on retry."
        }
    }

    if ($stillFailed.Count -gt 0) {
        Write-Err "The following policy files failed even after retry:"
        $stillFailed | ForEach-Object { Write-Err " - $_" }
        Write-Err "Aborting with non-zero exit to surface failing policies."
        exit 3
    }
}

Write-Host "\nAll done." -ForegroundColor Green
exit 0

# apply_rls_hotfix.ps1
# Applies the RLS recursion hotfix to your Supabase database
# This fixes the "infinite recursion detected in policy for relation 'orders'" error

param(
    [Parameter(Mandatory=$false)]
    [string]$ConnectionString,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseEnvFile
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "JoMarket RLS Hotfix Application Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to read .env file
function Get-EnvVariable {
    param([string]$VarName)
    
    $envPath = Join-Path $PSScriptRoot ".env"
    if (Test-Path $envPath) {
        $content = Get-Content $envPath
        foreach ($line in $content) {
            if ($line -match "^$VarName=(.*)$") {
                return $matches[1].Trim('"').Trim("'")
            }
        }
    }
    return $null
}

# Determine connection method
if ($UseEnvFile) {
    Write-Host "Reading connection details from .env file..." -ForegroundColor Yellow
    
    $supabaseUrl = Get-EnvVariable "SUPABASE_URL"
    $supabaseKey = Get-EnvVariable "SUPABASE_SERVICE_ROLE_KEY"
    
    if (-not $supabaseUrl -or -not $supabaseKey) {
        Write-Host "ERROR: Could not find SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env" -ForegroundColor Red
        Write-Host "Please ensure your .env file contains these variables." -ForegroundColor Red
        exit 1
    }
    
    # Extract database host from Supabase URL
    if ($supabaseUrl -match "https://([^.]+)\.supabase\.co") {
        $projectRef = $matches[1]
        $dbHost = "db.$projectRef.supabase.co"
        $dbName = "postgres"
        $dbUser = "postgres"
        
        Write-Host "Detected Supabase project: $projectRef" -ForegroundColor Green
        Write-Host ""
        Write-Host "To connect, you need the database password." -ForegroundColor Yellow
        Write-Host "Find it in: Supabase Dashboard > Project Settings > Database > Connection String" -ForegroundColor Yellow
        Write-Host ""
        $dbPassword = Read-Host "Enter database password" -AsSecureString
        $dbPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
        )
        
        $ConnectionString = "postgresql://${dbUser}:${dbPasswordPlain}@${dbHost}:5432/${dbName}"
    }
    else {
        Write-Host "ERROR: Invalid SUPABASE_URL format" -ForegroundColor Red
        exit 1
    }
}
elseif (-not $ConnectionString) {
    Write-Host "ERROR: No connection string provided." -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\apply_rls_hotfix.ps1 -ConnectionString 'postgresql://user:pass@host:5432/db'" -ForegroundColor Yellow
    Write-Host "  .\apply_rls_hotfix.ps1 -UseEnvFile" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Check if psql is available
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
    Write-Host "ERROR: psql command not found." -ForegroundColor Red
    Write-Host "Please install PostgreSQL client tools:" -ForegroundColor Yellow
    Write-Host "  https://www.postgresql.org/download/windows/" -ForegroundColor Yellow
    exit 1
}

$sqlFile = Join-Path $PSScriptRoot "migrations\hotfix_rls_recursion.sql"

if (-not (Test-Path $sqlFile)) {
    Write-Host "ERROR: SQL file not found: $sqlFile" -ForegroundColor Red
    exit 1
}

Write-Host "Applying RLS hotfix..." -ForegroundColor Cyan
Write-Host "SQL File: $sqlFile" -ForegroundColor Gray
Write-Host ""

# Execute the SQL file
try {
    $env:PGPASSWORD = $ConnectionString.Split(':')[2].Split('@')[0]
    & psql $ConnectionString -f $sqlFile -v ON_ERROR_STOP=1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "✓ Hotfix applied successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Restart your Flutter app" -ForegroundColor White
        Write-Host "2. Try logging in with Google again" -ForegroundColor White
        Write-Host "3. The vendor dashboard should now load without errors" -ForegroundColor White
        Write-Host ""
    }
    else {
        Write-Host ""
        Write-Host "ERROR: Failed to apply hotfix (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Remove-Item env:PGPASSWORD -ErrorAction SilentlyContinue
}

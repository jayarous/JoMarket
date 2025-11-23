<#
Run the SQL migration file against a Postgres database using psql.

Usage examples:
  # Use a full connection string (recommended for Supabase 'DB URL')
  $conn = 'postgresql://postgres:password@db.host:5432/postgres'
  .\scripts\run_migrations.ps1 -ConnectionString $conn

  # Or let the script prompt you for a connection string:
  .\scripts\run_migrations.ps1

Notes:
- If you use Supabase, copy the DB connection string from the Project -> Settings -> Database -> Connection info.
- You may need admin privileges to run `CREATE EXTENSION` statements. If those fail, run only the extensions as an admin (or via the Supabase SQL editor), then run the rest of the migration as a normal DB user.
- This script runs the full `migrations/sql_migration.sql` file in the repo root.
#>
param(
  [string]$ConnectionString
)

if (-not $ConnectionString) {
  $ConnectionString = Read-Host -Prompt 'Enter Postgres connection string (postgresql://user:pass@host:port/db)'
}

$MigrationFile = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath '..\migrations\sql_migration.sql'
$MigrationFile = (Resolve-Path $MigrationFile).Path

if (-not (Test-Path $MigrationFile)) {
  Write-Error "Migration file not found at $MigrationFile"
  exit 2
}

Write-Host "Running migration file: $MigrationFile"
Write-Host "Using connection: $ConnectionString"

# Check psql availability
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  Write-Warning "psql not found in PATH. Install PostgreSQL client tools or run the SQL via Supabase SQL editor."
  Write-Host "You can paste the contents of $MigrationFile into Supabase SQL editor (Project -> SQL) and execute there."
  exit 3
}

# Run the migration
try {
  & psql $ConnectionString -f $MigrationFile
  if ($LASTEXITCODE -ne 0) {
    Write-Error "psql returned exit code $LASTEXITCODE"
    exit $LASTEXITCODE
  }
  Write-Host "Migration executed successfully."
} catch {
  Write-Error "Error running migration: $_"
  exit 1
}

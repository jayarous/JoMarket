# apply_rls_hotfix_supabase.ps1
# Apply RLS hotfix using Supabase CLI
# Simpler alternative if you have Supabase CLI installed

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "JoMarket RLS Hotfix (Supabase CLI)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if supabase CLI is available
$supabasePath = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabasePath) {
    Write-Host "ERROR: supabase CLI not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it with:" -ForegroundColor Yellow
    Write-Host "  scoop install supabase" -ForegroundColor White
    Write-Host "or download from:" -ForegroundColor Yellow
    Write-Host "  https://github.com/supabase/cli/releases" -ForegroundColor White
    Write-Host ""
    Write-Host "Alternative: Use apply_rls_hotfix.ps1 with psql instead." -ForegroundColor Yellow
    exit 1
}

$sqlFile = Join-Path $PSScriptRoot "..\migrations\hotfix_rls_recursion.sql"

if (-not (Test-Path $sqlFile)) {
    Write-Host "ERROR: SQL file not found: $sqlFile" -ForegroundColor Red
    exit 1
}

Write-Host "Applying RLS hotfix via Supabase CLI..." -ForegroundColor Cyan
Write-Host ""

try {
    # Link to your project if not already linked
    Write-Host "Step 1: Linking to Supabase project..." -ForegroundColor Yellow
    & supabase link
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to link project. Please run 'supabase login' first." -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "Step 2: Executing hotfix SQL..." -ForegroundColor Yellow
    & supabase db execute -f $sqlFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "✓ Hotfix applied successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Hot restart your Flutter app (or rebuild)" -ForegroundColor White
        Write-Host "2. Try logging in with Google again" -ForegroundColor White
        Write-Host "3. Your vendor dashboard should now load!" -ForegroundColor White
        Write-Host ""
    }
    else {
        Write-Host ""
        Write-Host "ERROR: Failed to apply hotfix" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
